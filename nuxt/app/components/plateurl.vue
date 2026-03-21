<template>
  <a :href='url()' target='_blank'>
    <slot/>
  </a>
</template>

<script setup>
const props = defineProps(['code', 'name', 'interval'])
const interval = props.interval || '1D'
const url = () =>
  `/#/stocklist?code=${props.code}&name=${props.name}`
</script>
