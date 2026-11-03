import fs from 'node:fs'
import { fileURLToPath, URL } from 'node:url'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'

function apkMetadataPlugin(): Plugin {
  const updateApkJson = () => {
    try {
      const apkPath = fileURLToPath(new URL('./public/downloads/eva-beta.apk', import.meta.url))
      const jsonPath = fileURLToPath(new URL('./src/config/apkMetadata.json', import.meta.url))
      let sizeBytes = 0
      let sizeFormatted = '~59 MB'

      if (fs.existsSync(apkPath)) {
        const stats = fs.statSync(apkPath)
        sizeBytes = stats.size
        const mb = Math.round(stats.size / (1024 * 1024))
        sizeFormatted = `~${mb} MB`
      }

      const content = JSON.stringify({ sizeBytes, sizeFormatted }, null, 2) + '\n'
      if (!fs.existsSync(jsonPath) || fs.readFileSync(jsonPath, 'utf-8') !== content) {
        fs.writeFileSync(jsonPath, content, 'utf-8')
      }
    } catch (e) {
      console.warn('Gagal memperbarui apkMetadata.json:', e)
    }
  }

  return {
    name: 'apk-metadata-plugin',
    buildStart() {
      updateApkJson()
    },
    configureServer(server) {
      updateApkJson()
      const apkPath = fileURLToPath(new URL('./public/downloads/eva-beta.apk', import.meta.url))
      server.watcher.add(apkPath)
      server.watcher.on('all', (_event, filePath) => {
        if (filePath.endsWith('eva-beta.apk')) {
          updateApkJson()
        }
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [apkMetadataPlugin(), react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5174,
    strictPort: true,
    host: true,
    allowedHosts: ['eva.test', 'localhost', '127.0.0.1'],
  },
})

