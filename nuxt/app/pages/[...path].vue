<template>
  <UApp>
    <component :is='view'/>
    <!--order :account='account' /-->
  </UApp>
</template>

<script setup lang="ts">
import {shallowRef} from 'vue'
import { reloadNuxtApp } from '#app'

const view = shallowRef(null)

const route = useRoute()
const name = route.path.split('/')
const module = await import(`~/components/${name[1]}.vue`)
view.value = module.default
</script>

<style>
@import "tailwindcss";
@import "@nuxt/ui";
</style>
