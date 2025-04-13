// https://nuxt.com/docs/api/configuration/nuxt-config

export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',
  devtools: { enabled: true },
  modules: ['@nuxt/fonts', '@nuxt/icon', '@nuxt/ui'],
  server: {
    host: '0'
  },
  experimental: {
    clientNodeCompat: true
  },
  vite: {
    define: {
      "process.env.WSHOST": JSON.stringify(process.env.WSHOST)
    }
  }
})
