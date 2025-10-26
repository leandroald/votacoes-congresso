import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@pages': path.resolve(__dirname, 'src/pages'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@lib': path.resolve(__dirname, 'src/lib'),
    },
  },
  server: {
    proxy: {
      '/api-camara': {
        target: 'https://dadosabertos.camara.leg.br',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api-camara/, '/api/v2'),
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq) => {
            proxyReq.setHeader('Origin', 'https://dadosabertos.camara.leg.br');
          });
        },
      },
      '/api-senado': {
        target: 'https://legis.senado.leg.br',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api-senado/, '/dadosabertos'),
      },
    },
  },
});

