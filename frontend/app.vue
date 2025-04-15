<template>
  <UApp>
    <position :account='account' />
    <order :account='account' />
  </UApp>
</template>

<script setup>
import {Futu} from '../futu.js'

const futu = await new Futu()
const account = await (await futu.accounts())[0]
</script>

<style>
@import "tailwindcss";
@import "@nuxt/ui";
</style>
