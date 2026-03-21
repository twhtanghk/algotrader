<template>
<div>
  <USelect v-model='name' :items='list' @change='update'/>
  <stocks :code='name'/>
</div>
</template>

<script setup>
import {reactive, ref} from 'vue'
import {socket, watchlist, quote, delta, basic} from './socket'
import {h, resolveComponent} from 'vue'

const config = useRuntimeConfig()
const UButton = resolveComponent('UButton')
const stocks = resolveComponent('stocks')
const items = reactive([])
const list = config.public.watchlist.split(',')
const name = ref(list[0])
const update = () => {
  items.splice(0)
  socket.emit('watchlist', {name: name.value})
}

socket
  .on('connect', update)
  .on('watchlist', watchlist(items))
  .on('quote', quote(items))
  .on('basic', basic(items))
  .on('delta', delta(items))
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
