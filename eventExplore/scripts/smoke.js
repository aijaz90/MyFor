/**
 * Proves the server is wired to the real Forte host, without needing credentials.
 *
 *   node scripts/smoke.js
 *
 * With no credentials this expects a Forte-shaped auth error -- which is itself
 * the useful signal: it means the URL, headers and JSON body all reached Forte's
 * application layer rather than bouncing off nginx.
 *
 * Observed: empty credentials => HTTP 400 "API Access ID and/or API Secure Key
 * is missing in the header"; wrong-but-present credentials => HTTP 401
 * "API Access ID and API Secure Key combination not found". Both prove reach.
 */
import { config } from '../src/config.js';

const url = `${config.baseUrl}/organizations/${config.organizationId || 'org_000000'}/locations/${config.locationId || 'loc_000000'}/transactions`;
const basic = Buffer.from(`${config.accessId}:${config.secureKey}`).toString('base64');

const res = await fetch(url, {
  method: 'POST',
  headers: {
    Authorization: `Basic ${basic}`,
    'X-Forte-Auth-Organization-Id': config.organizationId || 'org_000000',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ action: 'sale', authorization_amount: 1.0 }),
});

const text = await res.text();
console.log(`POST ${url}`);
console.log(`HTTP ${res.status}`);
console.log(text.slice(0, 400));

const authError = (res.status === 400 || res.status === 401) && text.includes('response_desc');

if (res.ok) {
  console.log('\n✓ Forte accepted the request.');
} else if (authError) {
  console.log('\n✓ Reached Forte. Endpoint and headers are correct; supply real credentials to charge.');
} else if (text.trimStart().startsWith('<')) {
  console.log('\n✗ Got HTML, not JSON — wrong base URL for this environment.');
} else {
  console.log('\n? Unexpected. Read the body above.');
}
