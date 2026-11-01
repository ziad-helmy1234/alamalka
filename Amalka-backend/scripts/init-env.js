// Creates .env from .env.example with a freshly generated JWT secret (no-op if .env exists).
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');
const root = path.join(__dirname, '..');
const target = path.join(root, '.env');
if (fs.existsSync(target)) {
  console.log('.env already exists - leaving it unchanged');
  process.exit(0);
}
let s = fs.readFileSync(path.join(root, '.env.example'), 'utf8');
s = s.replace(/^JWT_ACCESS_SECRET=.*$/m, 'JWT_ACCESS_SECRET=' + crypto.randomBytes(48).toString('base64url'));
fs.writeFileSync(target, s);
console.log('Created .env with a random JWT secret');
