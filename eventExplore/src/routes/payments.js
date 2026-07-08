import { Router } from 'express';
import { config } from '../config.js';
import {
  ForteError,
  saleWithToken,
  saleWithRawCard,
  saleWithEncryptedSwipe,
  forteMeta,
} from '../forteClient.js';

export const payments = Router();

/** Amounts arrive as strings from the browser; reject anything that isn't sane money. */
function parseAmount(input) {
  const amount = Number(input);
  if (!Number.isFinite(amount) || amount <= 0) throw new ForteError('amount must be a positive number', { status: 400 });
  if (Math.round(amount * 100) !== amount * 100) throw new ForteError('amount may not have sub-cent precision', { status: 400 });
  return amount;
}

function send(res, result) {
  // Approved and declined are both HTTP 200 from Forte. Mirror that distinction
  // explicitly so the client can never mistake "call worked" for "money moved".
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
  res.json({ ...forteMeta(), paymentMode: config.paymentMode });
});

/** Production path: browser tokenized via forte.js, we only see the token. */
payments.post('/token-sale', async (req, res) => {
  try {
    const { one_time_token: oneTimeToken, amount, order_number: orderNumber } = req.body ?? {};
    if (!oneTimeToken) throw new ForteError('one_time_token is required', { status: 400 });
    send(res, await saleWithToken({ amount: parseAmount(amount), oneTimeToken, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});

/** Sandbox wiring path. Guarded twice: here and inside saleWithRawCard. */
payments.post('/direct-sale', async (req, res) => {
  try {
    if (config.paymentMode !== 'direct') throw new ForteError('direct-sale is disabled (PAYMENT_MODE is not "direct")', { status: 403 });
    const { amount, card, order_number: orderNumber } = req.body ?? {};
    if (!card?.accountNumber) throw new ForteError('card.accountNumber is required', { status: 400 });
    send(res, await saleWithRawCard({ amount: parseAmount(amount), card, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});

/**
 * Card-present path for the DynaFlex II Go.
 * The reader's encrypted output is relayed here by the iOS app, never by the
 * WebView -- WKWebView has no Bluetooth access at all. See CardReaderBridge.swift.
 *
 * Wire shape is UNVERIFIED; see saleWithEncryptedSwipe().
 */
payments.post('/swipe-sale', async (req, res) => {
  try {
    const { amount, swipe, order_number: orderNumber } = req.body ?? {};
    if (!swipe?.encryptedTrack || !swipe?.ksn) throw new ForteError('swipe.encryptedTrack and swipe.ksn are required', { status: 400 });
    send(res, await saleWithEncryptedSwipe({ amount: parseAmount(amount), swipe, orderNumber }));
  } catch (err) {
    fail(res, err);
  }
});
