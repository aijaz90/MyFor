import { Router } from 'express';
import { config } from '../config.js';

export const checkout = Router();

/**
 * Terminal pages. The iOS WKWebView never renders these -- its navigation
 * delegate intercepts the URL and dismisses first. They exist so the flow also
 * works in a plain browser, and so a failed intercept degrades to something
 * legible rather than a blank screen.
 */
checkout.get('/complete', (req, res) => {
  res.type('html').send(terminalPage('Payment complete', `Transaction ${escapeHtml(req.query.transaction_id ?? 'n/a')}`, '#0a7d38'));
});

checkout.get('/cancel', (_req, res) => {
  res.type('html').send(terminalPage('Payment cancelled', 'No charge was made.', '#8a8a8e'));
});

function terminalPage(title, detail, color) {
  return `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font:16px -apple-system,system-ui,sans-serif;display:grid;place-items:center;height:100vh;margin:0;color:#1c1c1e}
h1{color:${color};font-size:20px;margin:0 0 8px}p{color:#6c6c70;margin:0}</style>
<div><h1>${escapeHtml(title)}</h1><p>${detail}</p></div>`;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/** Values the checkout page needs at render time, injected as JSON. */
checkout.get('/bootstrap', (req, res) => {
  res.json({
    paymentMode: config.paymentMode,
    forteJsUrl: config.forteJsUrl,
    apiLoginId: config.apiLoginId,
    amount: req.query.amount ?? '1.00',
    orderNumber: req.query.order_number ?? '',
    returnSuccess: config.returnSuccess,
    returnCancel: config.returnCancel,
  });
});
