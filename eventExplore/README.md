# eventExplore — CSG Forte backend for the MrFor iOS app

Node/Express backend that holds the Forte credentials and calls the **Forte REST
API v3**. The iOS app (native, MagTek DynaFlex II Go over Bluetooth) talks only
to this server; no Forte secret ever ships inside the app.

## Run it

```bash
cd eventExplore
npm install
npm start
```

`.env` holds your **sandbox** credentials (verified working).

- `GET /health` — boot status
- `GET /api/payments/verify` — read-only credential check (returns your DBA name)

## Verified against your live sandbox

Confirmed by real calls with your keys, not from memory:

- Environment **sandbox** (`https://sandbox.forte.net/api/v3`); production rejects these keys.
- Location `loc_429434` "SBO Abacusoft Corp, CA" under org `org_525310`.
- Auth: HTTP Basic (`API Key : Secret Key`) + `X-Forte-Auth-Organization-Id`.
- A keyed sandbox sale **returned `approved:true`, `A01`, a real auth code.** The
  card-not-present charge path works end to end.
- Forte v3 has **no transaction `currency` field** (rejected); currency is set by
  the location. This location **requires `billing_address.first_name`/`last_name`**.
- Approval is inside a 200 (`response_code === "A01"`); declines map to `402`.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Boot status |
| `GET` | `/api/payments/verify` | Read-only credential/connectivity check |
| `GET` | `/api/payments/config` | Non-secret config |
| `POST` | `/api/payments/card-present-sale` | DynaFlex encrypted read → sale (**blocked, see below**) |
| `POST` | `/api/payments/test-sale` | Sandbox keyed card; proves the flow |

## SECURITY

Keys were shared in plaintext; they live only in `.env` (git-ignored).
**Rotate the Secret Key before production.** Never log request bodies.

---

## MagTek DynaFlex II Go — SDK integrated + build-verified ✅

MagTek's **Universal SDK (MTUSDK v1.0.1)** is now linked into the app and the
real card-reading engine compiles and links for **both device (arm64) and
simulator**. Architecture (`MrFor/Payments/`):

- **`MTUSDK.xcframework`, `MTSCRA.xcframework`, `CocoaMQTT.xcframework`** in
  `MrFor/Frameworks/` — linked and embedded (Embed & Sign) in the MrFor target.
  (MTUSDK weak-links MTSCRA and hard-links CocoaMQTT, so all three are required.)
- **`ReaderModels.swift`** — shared types + a compile-time seam. Because MTUSDK is
  linked, `canImport(MTUSDK)` is true and the app uses **`MagTekReader`**.
  (`BluetoothManager`, the CoreBluetooth fallback, remains for builds without the
  framework. The UI is identical either way.)
- **`MagTekReader.swift`** — the real engine, written against the actual MTUSDK
  headers + MagTek's sample app (verified Swift symbols, not guesses):
  `setDeviceType(MMS, BLE_EMV)` → `startDiscover()` → `onDeviceList` → connect via
  `getControl().open()` + `subscribeAll` → `start(ITransaction.amount(… quickChip:true))`
  → `onEvent(…)`. The encrypted data for the processor is captured from the
  **`AuthorizationRequest`** event (the ARQC + EMV tag block) or `CardData` (MSR),
  then posted to `/card-present-sale`. We deliberately do **not** decrypt locally
  (the sample's local `MTEncryptedData` uses a test BDK key) — the encrypted bytes
  go to the backend → Forte → Magensa.
- The Bluetooth permission string is set. For **USB-C** (optional; BLE needs
  nothing more) add `UISupportedExternalAccessoryProtocols` = `com.magtek.dynaflex2go`.

To pair over BLE: power on the reader, hold power to **4 beeps** (pairing mode),
connect from the app's Bluetooth screen (default pair code `000000`).

> Note: the three `.xcframework` binaries are committed under `MrFor/Frameworks/`.
> They're large; consider git-lfs if the repo size becomes a concern.

### The remaining blocker — the card-present schema from Forte

The `/card-present-sale` route reaches Forte correctly, but Forte rejects the
card-present card fields. I probed the Forte sandbox parser directly with your
keys — **every plausible field name is rejected** as not a member of `card`:

```
swipe_data, track_data, encrypted_track, magneprint, magnesafe, swipe,
encryption, tracks, card_swipe, emv, emv_data, track1, dukpt   →  all rejected
```

Meanwhile the card-not-present fields (`account_number`, `card_type`, …) are
accepted. So card-present data does **not** go on the `card` object the way we'd
guess, and this location is most likely **not yet provisioned for card-present**.
This cannot be reverse-engineered safely — it must come from Forte.

**Send your Forte integrations rep exactly this:**

1. Is location `loc_429434` **enabled for card-present / EMV** transactions? If
   not, what's the process and timeline (EMV certification)?
2. For a **MagTek DynaFlex II Go**, what is the **exact JSON** on the
   `transactions` endpoint for an encrypted chip/contactless (**ARQC**) read and
   for an encrypted **MSR** swipe? (Field names + where they nest — they are not
   members of the `card` object.)
3. Does Forte **relay the DUKPT/MagneSafe ciphertext to Magensa** for decryption
   on our behalf, or do we need our own Magensa account and a decryption step
   before calling Forte?
4. Do these sandbox keys get promoted to **production**, or are separate
   production credentials issued?

Once they answer #2, update the `card` payload in `forteClient.js`
`saleWithEncryptedCard` to match, and card-present sales will go through.

## App Store note

Selling event tickets (real-world goods) — Apple permits third-party payment, so
Forte is fine. Digital-only content would force In-App Purchase.

## Before production

- [ ] Rotate the Secret Key.
- [ ] Link the MagTek framework; reconcile any symbol names in `MagTekReader.swift`.
- [ ] Get Forte's card-present schema (Step 2) and enable EMV on the location.
- [ ] Production credentials; `FORTE_ENV=production`; app pointed at an HTTPS backend.
- [ ] Make sales idempotent so a retried request can't double-charge.
- [ ] Reconcile server-side (webhook / GET transaction) — never trust a client signal alone.
