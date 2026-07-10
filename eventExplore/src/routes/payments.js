import { Router } from 'express';
import { config } from '../config.js';
import {
  ForteError,
  saleWithEncryptedCard,
  saleWithRawCard,
  verifyCredentials,
  getReceipt,
  forteMeta,
} from '../forteClient.js';

export const payments = Router();

/** Amounts arrive as strings from the app; reject anything that isn't sane money. */
function parseAmount(input) {
  const amount = Number(input);
  if (!Number.isFinite(amount) || amount <= 0) throw new ForteError('amount must be a positive number', { status: 400 });
  // Reject sub-cent amounts, but tolerate float error: 19.99 * 100 is 1998.9999…
  // in JS, so compare against the nearest cent within a small epsilon.
  const cents = Math.round(amount * 100);
  if (Math.abs(amount * 100 - cents) > 1e-6) throw new ForteError('amount may not have sub-cent precision', { status: 400 });
  return cents / 100; // normalized, exact to the cent
}

function send(res, result) {
  // Approved and declined are both HTTP 200 from Forte. Mirror that distinction
  // explicitly so the app can never mistake "call worked" for "money moved".
  return res.status(result.approved ? 200 : 402).json({
    approved: result.approved,
    transaction_id: result.transactionId,
    authorization_code: result.authorizationCode,
    response_code: result.responseCode,
    message: result.responseDesc,
  });
}

function fail(res, err) {
  if (err instanceof ForteError) {
    const status = err.status && err.status >= 400 ? err.status : 502;
    return res.status(status).json({ approved: false, error: err.message, detail: err.body ?? null });
  }
  console.error('[payments] unexpected', err);
  return res.status(500).json({ approved: false, error: 'internal error' });
}

payments.get('/config', (_req, res) => {
  res.json(forteMeta());
});

/** Read-only credential/connectivity check the app can call on launch. */
payments.get('/verify', async (_req, res) => {
  try {
    res.json({ ok: true, ...(await verifyCredentials()) });
  } catch (err) {
    fail(res, err);
  }
});

/**
 * Receipt for a completed transaction. GET so the app can fetch it by id after a
 * successful sale (and re-fetch later). Read-only.
 *   GET /api/payments/receipt/trn_xxxxxxxx
 */
payments.get('/receipt/:transactionId', async (req, res) => {
  try {
    const id = req.params.transactionId;
    if (!/^trn_[A-Za-z0-9-]+$/.test(id)) throw new ForteError('invalid transaction id', { status: 400 });
    res.json(await getReceipt(id));
  } catch (err) {
    fail(res, err);
  }
});

/**
 * Card-present sale. THE PRIMARY endpoint. The iOS app collects an encrypted
 * read from the DynaFlex II Go over Bluetooth and posts it here.
 * Field shape is UNVERIFIED -- see saleWithEncryptedCard().
 */
payments.post('/card-present-sale', async (req, res) => {
  try {
    const { amount, swipe, order_number: orderNumber } = req.body ?? {};
    // encryptedTrack is the ARQC/EMV block (chip/contactless) or encrypted MSR.
    // KSN is required for MSR but is carried inside the TLV for EMV, so it is
    // optional here -- the exact mapping is confirmed with Forte per README.
    if (!swipe?.encryptedTrack) {
      throw new ForteError('swipe.encryptedTrack is required', { status: 400 });
    }
    send(res, await saleWithEncryptedCard({ amount: parseAmount(amount), swipe, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});

/**
 * Manual/keyed sale. SANDBOX ONLY. Lets you prove the whole charge + result
 * flow before the encrypted reader path is certified. Guarded twice.
 */
payments.post('/test-sale', async (req, res) => {
  try {
    if (config.env === 'production') throw new ForteError('test-sale is disabled in production', { status: 403 });
    const { amount, card, order_number: orderNumber } = req.body ?? {};
    if (!card?.accountNumber) throw new ForteError('card.accountNumber is required', { status: 400 });
    send(res, await saleWithRawCard({ amount: parseAmount(amount), card, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});

/**
 * Manual card entry ("Enter card manually"): add a new card and charge it in one
 * step. Card-not-present / keyed sale. This is what the WKWebView card-entry page
 * posts to. Same server-side path as a keyed sale (saleWithRawCard), which also
 * derives the card_type and fills the billing name Forte requires.
 *
 * PCI note: this routes the raw PAN through the server, so it's guarded to
 * sandbox (saleWithRawCard refuses in production). For production, move card
 * capture to Forte.js tokenization so the PAN goes straight to Forte and the
 * server only ever sees a one-time token.
 */
payments.post('/manual-sale', async (req, res) => {
  try {
    const { amount, card, order_number: orderNumber } = req.body ?? {};
    if (!card?.accountNumber) throw new ForteError('Card number is required', { status: 400 });
    if (!card?.expireMonth || !card?.expireYear) throw new ForteError('Card expiry is required', { status: 400 });
    if (!card?.cvv) throw new ForteError('CVV is required', { status: 400 });
    send(res, await saleWithRawCard({ amount: parseAmount(amount), card, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});
