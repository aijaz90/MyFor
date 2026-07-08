import express from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { config, configProblems } from './src/config.js';
import { payments } from './src/routes/payments.js';
import { checkout } from './src/routes/checkout.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

const app = express();
app.use(express.json({ limit: '32kb' }));

// Never log a request body on this server: in `direct` mode it contains a PAN.
app.use((req, _res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

app.get('/health', (_req, res) => res.json({ ok: true, env: config.env, problems: configProblems() }));

app.use('/api/payments', payments);
app.use('/checkout', checkout);
app.use(express.static(join(__dirname, 'public')));
app.get('/', (_req, res) => res.redirect('/checkout.html?amount=1.00'));

app.listen(config.port, () => {
  const problems = configProblems();
  console.log(`\neventExplore API  →  http://localhost:${config.port}`);
  console.log(`  Forte env:      ${config.env} (${config.baseUrl})`);
  console.log(`  Payment mode:   ${config.paymentMode}`);
  console.log(`  Checkout page:  http://localhost:${config.port}/checkout.html?amount=25.00`);
  if (problems.length) {
    console.log('\n  ⚠  Not ready to charge cards:');
    for (const p of problems) console.log(`     - ${p}`);
    console.log('     Copy .env.example → .env and fill in your sandbox credentials.');
  }
  console.log('');
});
