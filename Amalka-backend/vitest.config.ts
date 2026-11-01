import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    setupFiles: ['tests/setup-env.ts'],
    globalSetup: ['tests/global-setup.ts'],
    // Tests share one Postgres database → run files one at a time.
    fileParallelism: false,
    pool: 'forks',
    testTimeout: 30_000,
    hookTimeout: 120_000,
  },
});
