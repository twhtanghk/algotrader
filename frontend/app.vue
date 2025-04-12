<template>
  <div>
    <position :account='account' />
  </div>
</template>

<script setup>
import {Futu} from '../futu.js'

const futu = await new Futu()
const account = await (await futu.accounts())[0]
</script>
