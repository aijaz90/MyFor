# eventExplore — CSG Forte backend for the MrFor iOS app

Node/Express backend that talks to the **Forte REST API v3**, plus the checkout
page the iOS app loads in a `WKWebView`.

No Forte credential ever ships inside the iOS app. The app talks only to this
server; this server talks to Forte.

## Run it

```bash
cd eventExplore
npm install
cp .env.example .env      # fill in sandbox credentials
npm start
```

Then `http://localhost:3000/checkout.html?amount=25.00`.

`npm run smoke` proves this server can reach Forte without needing credentials —
it expects a Forte-shaped auth error, which means the URL, headers and JSON body
all landed on Forte's application layer.

## Credentials you need

All from the Forte dashboard → **Developer → API Credentials**. Sandbox first.

| `.env` key | Looks like | Notes |
|---|---|---|
| `FORTE_API_ACCESS_ID` | `xxxxxxxx` | Basic-auth username |
| `FORTE_API_SECURE_KEY` | `xxxxxxxx` | Basic-auth password; shown once |
| `FORTE_ORGANIZATION_ID` | `org_123456` | Also sent as `X-Forte-Auth-Organization-Id` |
| `FORTE_LOCATION_ID` | `loc_123456` | The processing endpoint (≈ Merchant ID) |
| `FORTE_API_LOGIN_ID` | `xxxxxxxx` | **Only** value exposed to the browser. Mints one-time tokens; cannot move money. |

## Verified facts

Confirmed by live probe on 2026-07-08, not from memory:

- **Sandbox** base: `https://sandbox.forte.net/api/v3` — note the `/api` prefix.
  Without it, nginx answers `503`.
- **Production** base: `https://api.forte.net/v3`.
- Auth: HTTP Basic (`access_id:secure_key`) **plus** `X-Forte-Auth-Organization-Id`.
- Transactions: `POST {base}/organizations/{org_id}/locations/{loc_id}/transactions`
- Empty credentials → `400 "…missing in the header"`. Wrong credentials →
  `401 "…combination not found"`. Both prove you reached Forte.
- Approval is signalled **inside a 200 response** as `response.response_code === "A01"`.
  A successful HTTP call is *not* a successful payment. This server maps declines
  to `402` so the client can never confuse the two.

## Payment modes

`PAYMENT_MODE` in `.env`:

- **`direct`** (default) — the page posts the raw card number to this server,
  which calls Forte. Works immediately in sandbox, needs nothing extra. Puts
  this server in **full PCI-DSS scope**. The server refuses to run this mode
  when `FORTE_ENV=production`.
- **`fortejs`** — the browser tokenizes straight to Forte via `forte.js`; this
  server only ever sees a `one_time_token` (valid 60 min). PCI scope: SAQ-A-EP.
  **This is what you ship.**

`fortejs` needs `FORTE_JS_URL`, which is **left blank on purpose**. I could not
verify the script URL from public sources — Forte's devdocs are a client-rendered
SPA and the sample files sit behind their support portal. Every URL I guessed
(`api.forte.net/js/v1/forte.min.js` and friends) returned 404/503. Ask your Forte
rep for the exact `<script src>` per environment. A wrong URL fails silently, so
the page refuses to enable the Pay button until it's set.

Two other `fortejs` details worth knowing:
- Card inputs have **no `name` attribute**. That's what keeps card data out of a
  normal form POST, i.e. out of your server. Don't add names.
- The success callback field is read as `r.onetime_token || r.one_time_token`.
  Confirm which spelling Forte actually returns.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Boot status + config problems |
| `GET` | `/checkout.html?amount=&order_number=` | The page the WebView loads |
| `GET` | `/checkout/bootstrap` | Render-time values for the page |
| `GET` | `/checkout/complete`, `/checkout/cancel` | Terminal URLs the app intercepts |
| `POST` | `/api/payments/token-sale` | `{ one_time_token, amount }` → sale |
| `POST` | `/api/payments/direct-sale` | Sandbox only; raw card |
| `POST` | `/api/payments/swipe-sale` | Card-present. **Unverified — see below.** |

---

## The card reader: what's actually true

Hardware: **MagTek DynaFlex II Go** (BLE + USB-C, EMV chip, NFC/contactless, magstripe, DUKPT).

**A `WKWebView` cannot talk to this reader.** No Web Bluetooth, no WebUSB. The
only route is native Swift → JS, which is what the `cardReader` message handler
in `ForteCheckoutView.swift` is for. Advice to use a "keyboard emulation" reader
that types the PAN into a focused field is actively harmful: that means an
*unencrypted* reader spraying plaintext card numbers into your app, dragging the
whole app into PCI scope — the exact opposite of why you'd use a WebView.

Also: **the Forte React Native SDK will not help.** Per Forte's own page it does
tokenization only, scoped to "mobile browser and in-app payments." It mentions
card readers, EMV, and in-person payments zero times.

Two blockers remain, and only Forte can clear them:

1. **Decryption.** Forte's docs state the reader's DUKPT ciphertext "can only be
   decrypted by the Magensa decryption service." Your server cannot decrypt it.
   Either Forte relays the blob to Magensa for you, or you hold your own Magensa
   credentials and decrypt first.
2. **The API shape.** Forte documents eDynamo/DynaFlex through the *MagTek SCRA
   Web API Host Service* — a **Windows** service on localhost (USB is Windows-only).
   Their support portal says the DynaFlex II Go works with the REST API over BLE
   on iOS, but no iOS integration guide is publicly reachable.

So `swipe-sale` and `saleWithEncryptedSwipe()` use **placeholder field names**
(`swipe_data`, `ksn`, `encryption_method`). Do not ship against them untested.

### Send these to your Forte integrations rep

1. We're building a **native iOS** app. Is there a supported path to run a
   **DynaFlex II Go over Bluetooth LE** against the REST API v3 from iOS, without
   the Windows MTSCRA host service? If so, where is the integration guide?
2. For a card-present sale, **what are the exact JSON field names** on the
   `transactions` endpoint for the encrypted read (encrypted track, KSN,
   encryption method)?
3. Does Forte **relay the DUKPT ciphertext to Magensa** on our behalf, or do we
   need our own Magensa account and decryption step first?
4. Does our **location need an EMV certification** before card-present
   transactions will authorize? What's the process and timeline?
5. What is the exact **`forte.js` script URL** for sandbox and for production?
6. For the REST API, does a `one_time_token` go in as `card.one_time_token`, or
   as a top-level `paymethod_token`?

## App Store note

You're selling event tickets — real-world goods/services. Apple permits
third-party payment processing for that, so Forte is fine. If you ever sell
digital content or in-app unlocks, Apple requires In-App Purchase and will reject
a Forte flow for those items.

## Before production

- [ ] Switch `PAYMENT_MODE=fortejs`; never run `direct` against production.
- [ ] Serve over HTTPS (the iOS app's ATS will otherwise block plain HTTP).
- [ ] Don't trust the WebView redirect as proof of payment. It's a UI signal.
      Confirm server-side (webhook, or `GET` the transaction) before releasing tickets.
- [ ] Never log request bodies — in `direct` mode they contain a PAN.
- [ ] Move `order_number` → real order records, and make sales idempotent so a
      retried request can't double-charge.
