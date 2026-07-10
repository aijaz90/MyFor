import 'dotenv/config';

// Base URLs verified empirically by POSTing dummy Basic auth and observing a
// Forte-shaped 401 rather than a 404/503, and confirmed 2026-07-09 with the
// real sandbox keys (GET on the location returned 200):
//
//   sandbox: https://sandbox.forte.net/api/v3/...   (note the extra /api)
//   prod:    https://api.forte.net/v3/...
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
  currency: process.env.FORTE_CURRENCY || 'USD',

  // The org sent in the X-Forte-Auth-Organization-Id header. This must be the
  // organization the API Access ID was ISSUED UNDER. For a plain merchant account
  // that's the same as FORTE_ORGANIZATION_ID (leave this blank). For a partner
  // account, set this to your partner/parent org — Forte then lets you charge the
  // merchant org named in FORTE_ORGANIZATION_ID (the URL path).
  authOrganizationId: process.env.FORTE_AUTH_ORGANIZATION_ID || process.env.FORTE_ORGANIZATION_ID || '',
};

/** Problems that make Forte calls impossible, surfaced at boot instead of at first request. */
export function configProblems() {
  const problems = [];
  if (!config.accessId) problems.push('FORTE_API_ACCESS_ID is unset');
  if (!config.secureKey) problems.push('FORTE_API_SECURE_KEY is unset');
  if (!config.organizationId.startsWith('org_')) problems.push('FORTE_ORGANIZATION_ID must look like org_123456');
  if (!config.locationId.startsWith('loc_')) problems.push('FORTE_LOCATION_ID must look like loc_123456');
  return problems;
}

export const isConfigured = () => configProblems().length === 0;
