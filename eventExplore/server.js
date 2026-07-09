import express from 'express';
import { config, configProblems } from './src/config.js';
import { payments } from './src/routes/payments.js';

const app = express();
app.use(express.json({ limit: '32kb' }));

// Never log a request body on this server: card-present and test payloads carry
// sensitive card data.
app.use((req, _res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

app.get('/health', (_req, res) => res.json({ ok: true, env: config.env, problems: configProblems() }));
app.use('/api/payments', payments);

app.listen(config.port, () => {
  const problems = configProblems();
  console.log(`\neventExplore API  →  http://localhost:${config.port}`);
  console.log(`  Forte env:      ${config.env} (${config.baseUrl})`);
  console.log(`  Org / Location: ${config.organizationId} / ${config.locationId}`);
  console.log(`  Currency:       ${config.currency}`);
  console.log(`  Verify:         GET http://localhost:${config.port}/api/payments/verify`);
  if (problems.length) {
    console.log('\n  ⚠  Not ready to charge cards:');
    for (const p of problems) console.log(`     - ${p}`);
  }
  console.log('');
});
