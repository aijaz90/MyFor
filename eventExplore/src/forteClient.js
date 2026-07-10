import { config } from './config.js';

/**
 * Thin client over the Forte REST API v3.
 *
 * Auth (verified): HTTP Basic with API Access ID as username and API Secure Key
 * as password, PLUS a custom X-Forte-Auth-Organization-Id header naming the org
 * the request authenticates at.
 */

function authHeaders() {
  const basic = Buffer.from(`${config.accessId}:${config.secureKey}`).toString('base64');
  return {
    Authorization: `Basic ${basic}`,
    'X-Forte-Auth-Organization-Id': config.authOrganizationId,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
}

const transactionsPath = () =>
  `${config.baseUrl}/organizations/${config.organizationId}/locations/${config.locationId}/transactions`;

export class ForteError extends Error {
  constructor(message, { status, body } = {}) {
    super(message);
    this.name = 'ForteError';
    this.status = status;
    this.body = body;
  }
}

async function request(method, url, payload) {
  let res;
  try {
    res = await fetch(url, {
      method,
      headers: authHeaders(),
      ...(payload ? { body: JSON.stringify(payload) } : {}),
      signal: AbortSignal.timeout(30_000),
    });
  } catch (cause) {
    throw new ForteError(`Could not reach Forte at ${url}: ${cause.message}`, { status: 0 });
  }

  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    throw new ForteError(`Forte returned non-JSON (HTTP ${res.status})`, { status: res.status, body: text.slice(0, 500) });
  }

  if (!res.ok) {
    const desc = body?.response?.response_desc || `HTTP ${res.status}`;
    throw new ForteError(desc, { status: res.status, body });
  }
  return body;
}

const post = (url, payload) => request('POST', url, payload);

/**
 * Forte's sandbox sometimes returns a transient "Internal service error" when a
 * transaction is read immediately after it's created (eventual consistency).
 * Retry a few times with backoff before giving up — used by the receipt fetch.
 */
async function requestWithRetry(method, url, { attempts = 4, delayMs = 1200 } = {}) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await request(method, url);
    } catch (e) {
      lastErr = e;
      const desc = e?.body?.response?.response_desc || e.message || '';
      const transient = e.status === 500 || e.status === 0 || /internal service error/i.test(desc);
      if (!transient || i === attempts - 1) throw e;
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw lastErr;
}

/**
 * Forte signals business-level decline inside a 200 response. `A01` is the
 * documented approval code for a sale; anything else is a decline even though
 * the HTTP call succeeded. Never treat res.ok alone as "paid".
 */
export function isApproved(forteResponse) {
  return forteResponse?.response?.response_code === 'A01';
}

function normalize(raw) {
  const r = raw?.response ?? {};
  return {
    approved: isApproved(raw),
    transactionId: raw?.transaction_id ?? null,
    authorizationCode: r.authorization_code ?? null,
    responseCode: r.response_code ?? null,
    responseDesc: r.response_desc ?? null,
    raw,
  };
}

/** Read-only auth check. Returns the location record; used by /health and startup. */
export async function verifyCredentials() {
  const url = `${config.baseUrl}/organizations/${config.organizationId}/locations/${config.locationId}`;
  const body = await request('GET', url);
  return { dbaName: body?.dba_name ?? null, status: body?.status ?? null };
}

/**
 * Receipt for a completed transaction. GETs the transaction from Forte and
 * normalizes it into the shape the app's receipt screen needs. Also fetches the
 * merchant (DBA) name so the receipt has a proper header.
 */
export async function getReceipt(transactionId) {
  const txnURL = `${config.baseUrl}/organizations/${config.organizationId}/locations/${config.locationId}/transactions/${transactionId}`;
  const [txn, merchant] = await Promise.all([
    requestWithRetry('GET', txnURL),
    verifyCredentials().catch(() => ({ dbaName: null })),
  ]);

  const r = txn?.response ?? {};
  const card = txn?.card ?? {};
  return {
    transaction_id: txn?.transaction_id ?? transactionId,
    approved: r.response_code === 'A01',
    status: txn?.status ?? null,
    amount: txn?.authorization_amount ?? null,
    currency: config.currency,
    authorization_code: txn?.authorization_code ?? r.authorization_code ?? null,
    response_code: r.response_code ?? null,
    message: r.response_desc ?? null,
    date: txn?.received_date ?? null,
    card: {
      type: card.card_type ?? null,
      last4: card.last_4_account_number ?? null,
      masked: card.masked_account_number ?? null,
      name_on_card: card.name_on_card ?? null,
    },
    avs_result: r.avs_result ?? null,
    cvv_result: r.cvv_result ?? null,
    merchant_name: merchant.dbaName ?? null,
  };
}

/**
 * This location requires billing_address.first_name / last_name on a sale
 * (Forte response F01 "MANDATORY FIELD MISSING"). Prefer explicit fields, else
 * split the name on the card.
 */
function billingAddress(card) {
  let first = card.billingFirstName;
  let last = card.billingLastName;
  if (!first || !last) {
    const parts = String(card.nameOnCard ?? '').trim().split(/\s+/);
    first = first || parts[0] || 'Card';
    last = last || parts.slice(1).join(' ') || 'Holder';
  }
  return { first_name: first, last_name: last };
}

/** Forte identifies the network with a short code rather than inferring it from the PAN. */
export function deriveCardType(pan = '') {
  const n = String(pan).replace(/\D/g, '');
  if (/^4/.test(n)) return 'visa';
  if (/^(5[1-5]|2(2[2-9]|[3-6]|7[01]|720))/.test(n)) return 'mast';
  if (/^3[47]/.test(n)) return 'amex';
  if (/^(6011|65|64[4-9]|622)/.test(n)) return 'disc';
  if (/^(30[0-5]|36|38)/.test(n)) return 'dine';
  if (/^35(2[89]|[3-8])/.test(n)) return 'jcb';
  return undefined;
}

/**
 * Card-present sale from a DynaFlex II Go encrypted read. THE PRIMARY PATH.
 *
 * UNVERIFIED FIELD NAMES. Forte's docs say credit cards may be authorized "by
 * passing swipe data in a POST request to the transactions URI", but the exact
 * card-present schema is only in their client-rendered SPA docs. Two facts are
 * certain and shape this:
 *
 *   - The reader encrypts under DUKPT; the ciphertext "can only be decrypted by
 *     the Magensa decryption service" (MagTek). Either Forte relays it to
 *     Magensa for your account, or you hold Magensa credentials yourself.
 *   - Card-present almost certainly needs an EMV certification on your location.
 *
 * The `card` keys below are placeholders. Confirm them with your Forte rep
 * (questions are listed in README.md) before relying on this in anything real.
 */
export async function saleWithEncryptedCard({ amount, swipe, orderNumber }) {
  // Forte v3 has no transaction-level `currency` field -- the sandbox rejects it
  // ("Could not find member 'currency'"). Currency is fixed by the location
  // (USD here). config.currency is kept for display/metadata only.
  const payload = {
    action: 'sale',
    authorization_amount: Number(amount),
    ...(orderNumber ? { order_number: String(orderNumber) } : {}),
    card: {
      // Replace with Forte's actual card-present schema.
      swipe_data: swipe.encryptedTrack,
      ksn: swipe.ksn,
      encryption_method: swipe.encryptionMethod ?? 'dukpt',
      ...(swipe.entryMode ? { entry_mode: swipe.entryMode } : {}),
    },
  };
  return normalize(await post(transactionsPath(), payload));
}

/**
 * Sale from raw card fields. SANDBOX TESTING ONLY -- lets you prove the Forte
 * charge path end-to-end (and the app's result handling) before the encrypted
 * reader integration is finished. Refused in production.
 */
export async function saleWithRawCard({ amount, card, orderNumber }) {
  if (config.env === 'production') {
    throw new ForteError('Refusing to send raw PAN from this server in production');
  }
  const cardType = card.cardType ?? deriveCardType(card.accountNumber);
  if (!cardType) throw new ForteError('Unrecognized card number', { status: 400 });

  const payload = {
    action: 'sale',
    authorization_amount: Number(amount),
    ...(orderNumber ? { order_number: String(orderNumber) } : {}),
    billing_address: billingAddress(card),
    card: {
      card_type: cardType,
      name_on_card: card.nameOnCard,
      account_number: card.accountNumber,
      expire_month: Number(card.expireMonth),
      expire_year: Number(card.expireYear),
      card_verification_value: card.cvv,
    },
  };
  return normalize(await post(transactionsPath(), payload));
}

export const forteMeta = () => ({
  env: config.env,
  baseUrl: config.baseUrl,
  organizationId: config.organizationId,
  locationId: config.locationId,
  currency: config.currency,
});
