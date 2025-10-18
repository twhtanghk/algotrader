<template>
  <ULink :to='url()' target='_blank'>
    <slot/>
  </ULink>
</template>

<script setup>
const props = defineProps(['code', 'desc', 'interval'])
const desc = props.desc || props.code
const interval = props.interval || '1D'
const url = () =>
  `https://www.tradingview.com/chart/?symbol=HKEX:${props.code?.replace(/^0+/, '')}&interval=${interval}`
</script>
