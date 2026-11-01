import { execSync } from 'node:child_process';

/** Recreate the test database from the migrations once per test run. */
export default function setup() {
  if (process.env.SKIP_DB_SETUP === '1') return; // unit tests only
  const url =
    process.env.TEST_DATABASE_URL ?? 'postgresql://amalka:amalka_dev_password@localhost:5433/amalka_test?schema=public';
  execSync('npx prisma migrate reset --force --skip-seed --skip-generate', {
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: url },
  });
}
