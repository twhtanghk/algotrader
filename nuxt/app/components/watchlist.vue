<template>
<div>
  <USelect v-model='name' :items='list' class='w-64'/>
  <stocks :code='name'/>
</div>
</template>

<script setup>
import {ref, resolveComponent} from 'vue'

const config = useRuntimeConfig()
const stocks = resolveComponent('stocks')
const list = config.public.watchlist.split(',')
const name = ref(list[0])
</script>

<style>
.loss {
  color: red
}
.profit {
  color: green
}
tbody tr:hover {
  background-color: #f0f0f0;
}
</style>
