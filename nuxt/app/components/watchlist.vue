<template>
<div>
  <USelect v-model='name' :items='list' @change='update'/>
  <UTable sticky :data='items' :columns='columns' :sorting='sort'>
    <template #code-cell='{row}'>
      <TVUrl :code='row.original.owner?.code || row.original.code'>
        {{row.original.code}}
      </TVUrl>
    </template>
    <template #open-cell='{row}'>
      {{row.original.open?.toFixed(2)}}
    </template>
    <template #high-cell='{row}'>
      {{row.original.high?.toFixed(2)}}
    </template>
    <template #low-cell='{row}'>
      {{row.original.low?.toFixed(2)}}
    </template>
    <template #close-cell='{row}'>
      {{row.original.close?.toFixed(2)}}
    </template>
    <template #delta-cell='{row}'>
      {{row.original.delta?.toFixed(2)}}
    </template>
    <template #pe-cell='{row}'>
      {{row.original.pe?.toFixed(2)}}
    </template>
    <template #pb-cell='{row}'>
      {{row.original.pb?.toFixed(2)}}
    </template>
  </UTable>
</div>
</template>

<script setup>
import {reactive, ref} from 'vue'
import {socket, watchlist, quote, delta, basic} from './socket'
import {h, resolveComponent} from 'vue'

const config = useRuntimeConfig()
const UButton = resolveComponent('UButton')
const TVUrl= resolveComponent('tvurl')
const items = reactive([])
const list = config.public.watchlist.split(',')
const name = ref(list[0])
const columns = [
  {accessorKey: 'code', header: ({column}) => colHead(UButton, column, {label: 'Code'})},
  {accessorKey: 'name', header: ({column}) => colHead(UButton, column, {label: 'Name'})},
  {accessorKey: 'open', header: 'Open'},
  {accessorKey: 'high', header: 'High'},
  {accessorKey: 'low', header: 'Low'},
  {accessorKey: 'close', header: 'Close'},
  {accessorKey: 'delta', header: ({column}) => colHead(UButton, column, {label: 'Delta'})},
  {accessorKey: 'pe', header: ({column}) => colHead(UButton, column, {label: 'PE'})},
  {accessorKey: 'pb', header: ({column}) => colHead(UButton, column, {label: 'PB'})},
]
const sort = ref([
  {id: 'name', desc: true}
])
const colHead = (el, col, opts) => {
  opts.icon = col.getIsSorted() 
    ? col.getIsSorted() === 'asc' 
      ? 'i-lucide-arrow-up-narrow-wide'
      : 'i-lucide-arrow-down-wide-narrow'
      : 'i-lucide-arrow-up-down',
  opts.class = '-mx-2.5'
  opts.onClick = () => col.toggleSorting(col.getIsSorted() === 'asc')
  return h(UButton, opts)
}
const update = () => {
  items.splice(0)
  socket.emit('watchlist', {name: name.value})
}

socket
  .on('connect', () => {
    update()
  })
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
</style>
