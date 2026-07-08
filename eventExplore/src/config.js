import 'dotenv/config';

const bool = (v) => v === 'true' || v === '1';

// Base URLs verified empirically on 2026-07-08 by POSTing dummy Basic auth
// credentials and observing a Forte-shaped 401 body rather than a 404/503:
//
//   sandbox: https://sandbox.forte.net/api/v3/...  -> 401 {"response":{...}}
//            https://sandbox.forte.net/v3/...      -> 503 (nginx, wrong path)
//   prod:    https://api.forte.net/v3/...          -> 401 {"response":{...}}
//
// Note the sandbox host requires the extra /api prefix and production does not.
const BASE_URLS = {
  sandbox: 'https://sandbox.forte.net/api/v3',
  production: 'https://api.forte.net/v3',
};

const env = process.env.FORTE_ENV === 'production' ? 'production' : 'sandbox';

export const config = {
  env,
  baseUrl: BASE_URLS[env],
  port: Number(process.env.PORT || 3000),

  accessId: process.env.FORTE_API_ACCESS_ID || '',
  secureKey: process.env.FORTE_API_SECURE_KEY || '',
  organizationId: process.env.FORTE_ORGANIZATION_ID || '',
  locationId: process.env.FORTE_LOCATION_ID || '',

  paymentMode: process.env.PAYMENT_MODE === 'fortejs' ? 'fortejs' : 'direct',
  forteJsUrl: process.env.FORTE_JS_URL || '',
  apiLoginId: process.env.FORTE_API_LOGIN_ID || '',

  returnSuccess: process.env.CHECKOUT_RETURN_SUCCESS || '/checkout/complete',
  returnCancel: process.env.CHECKOUT_RETURN_CANCEL || '/checkout/cancel',
};

/** Problems that make Forte calls impossible, surfaced at boot instead of at first request. */
export function configProblems() {
  const problems = [];
  if (!config.accessId) problems.push('FORTE_API_ACCESS_ID is unset');
  if (!config.secureKey) problems.push('FORTE_API_SECURE_KEY is unset');
  if (!config.organizationId.startsWith('org_')) problems.push('FORTE_ORGANIZATION_ID must look like org_123456');
  if (!config.locationId.startsWith('loc_')) problems.push('FORTE_LOCATION_ID must look like loc_123456');

  if (config.paymentMode === 'fortejs') {
    if (!config.forteJsUrl) problems.push('PAYMENT_MODE=fortejs requires FORTE_JS_URL (ask your Forte rep)');
    if (!config.apiLoginId) problems.push('PAYMENT_MODE=fortejs requires FORTE_API_LOGIN_ID');
  }
  if (config.paymentMode === 'direct' && config.env === 'production') {
    problems.push('PAYMENT_MODE=direct is forbidden in production: it routes raw PAN through this server');
  }
  return problems;
}

export const isConfigured = () => configProblems().length === 0;
