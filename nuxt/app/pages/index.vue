<template>
  <UApp>
    <component :is='view'/>
    <!--order :account='account' /-->
  </UApp>
</template>

<script setup lang="ts">
import {ref, resolveComponent} from 'vue'

const route = useRoute()
const view = ref(null)
const name = route.hash.split('/')
const module = await import(`~/components/${name[1]}.vue`)
view.value = module.default
</script>

<style>
@import "tailwindcss";
@import "@nuxt/ui";
</style>
