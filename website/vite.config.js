import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, rootDir, '');
  const backend = env.VITE_API_PROXY_TARGET || 'http://127.0.0.1:6055';

  return {
    plugins: [react()],
    server: {
      proxy: {
        '/api': backend,
        '/uploads': backend,
        '/catalog': backend,
      },
    },
    build: {
      outDir: path.resolve(rootDir, '../backend/public/store'),
      emptyOutDir: true,
    },
  };
});
