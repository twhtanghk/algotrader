<template>
  <UApp>
    <el/>
  </UApp>
</template>

<script setup lang="ts">
import {resolveComponent} from 'vue'

const el = resolveComponent('plate')
</script>

<style>
@import "tailwindcss";
@import "@nuxt/ui";
</style>
