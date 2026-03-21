<template>
  <UApp>
    <el :code='code'/>
  </UApp>
</template>

<script setup lang="ts">
import {resolveComponent} from 'vue'
const el = resolveComponent('stocks')
const route = useRoute()
const code = route.query.code
</script>

<style>
@import "tailwindcss";
@import "@nuxt/ui";
</style>
