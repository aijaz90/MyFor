import { config } from './config.js';

/**
 * Thin client over the Forte REST API v3.
 *
 * Auth (verified against Forte's "Common Authentication Process" doc and by
 * live probe): HTTP Basic with API Access ID as username and API Secure Key as
 * password, PLUS a custom X-Forte-Auth-Organization-Id header naming the org
 * the request authenticates at.
 */

function authHeaders() {
  const basic = Buffer.from(`${config.accessId}:${config.secureKey}`).toString('base64');
  return {
    Authorization: `Basic ${basic}`,
    'X-Forte-Auth-Organization-Id': config.organizationId,
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

async function post(url, payload) {
  let res;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify(payload),
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
    // Forte returns nginx HTML on some misrouted paths; keep it visible.
    throw new ForteError(`Forte returned non-JSON (HTTP ${res.status})`, { status: res.status, body: text.slice(0, 500) });
  }

  if (!res.ok) {
    const desc = body?.response?.response_desc || `HTTP ${res.status}`;
    throw new ForteError(desc, { status: res.status, body });
  }
  return body;
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

/** Sale funded by a forte.js one-time token. This is the production path. */
export async function saleWithToken({ amount, oneTimeToken, orderNumber }) {
  // Field name note: `one_time_token` is documented as the value forte.js
  // returns and is consumable by the REST API for up to 60 minutes. Whether it
  // nests under `card` (as here) or rides as a sibling `paymethod_token` is not
  // stated in Forte's public docs. Confirm against your sandbox before relying
  // on it -- a wrong shape shows up as a validation error, not a silent charge.
  const payload = {
    action: 'sale',
    authorization_amount: Number(amount),
    ...(orderNumber ? { order_number: String(orderNumber) } : {}),
    card: { one_time_token: oneTimeToken },
  };
  return normalize(await post(transactionsPath(), payload));
}

/**
 * Forte identifies the network with a short `card_type` code rather than
 * inferring it from the PAN. The browser doesn't send one, and an `undefined`
 * value would be silently dropped by JSON.stringify, so derive it here.
 */
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

/** Sale from raw card fields. Sandbox wiring only -- see PAYMENT_MODE in .env.example. */
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

/**
 * Sale from a DynaFlex II Go / eDynamo encrypted swipe-or-dip read.
 *
 * UNVERIFIED. Forte's docs say credit cards may be authorized "by passing
 * swipe data in a POST request to the transactions URI", but the exact field
 * names are only in their client-rendered SPA docs, which I could not extract.
 *
 * What is certain: the reader encrypts under DUKPT and the ciphertext "can only
 * be decrypted by the Magensa decryption service" (MagTek's service). So one of
 * two things is true for your account, and only Forte can tell you which:
 *
 *   (a) Forte relays the blob to Magensa for you -- then you post it here; or
 *   (b) you hold your own Magensa credentials and decrypt/re-encrypt first.
 *
 * Either way this almost certainly requires an EMV certification on your Forte
 * location before it will authorize. Do not ship against this shape untested.
 */
export async function saleWithEncryptedSwipe({ amount, swipe, orderNumber }) {
  const payload = {
    action: 'sale',
    authorization_amount: Number(amount),
    ...(orderNumber ? { order_number: String(orderNumber) } : {}),
    card: {
      // Placeholder key names. Replace with Forte's actual card-present schema.
      swipe_data: swipe.encryptedTrack,
      ksn: swipe.ksn,
      encryption_method: swipe.encryptionMethod ?? 'dukpt',
    },
  };
  return normalize(await post(transactionsPath(), payload));
}

export const forteMeta = () => ({
  env: config.env,
  baseUrl: config.baseUrl,
  organizationId: config.organizationId,
  locationId: config.locationId,
});
