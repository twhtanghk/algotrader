<template>
  <UTable sticky :data='items' :columns='columns' :sorting='sort'>
    <template #code-cell='{row}'>
      <PlateUrl :code='row.original.code' :name='row.original.name'>
        {{row.original.code}}
      </PlateUrl>
    </template>
    <template #name-cell='{row}'>
      {{row.original.name}}
    </template>
    <template #delta-cell='{row}'>
      {{row.original.delta?.toFixed(2)}}
    </template>
  </UTable>
</template>

<script setup>
import {reactive} from 'vue'
import {socket, position, quote, basic, delta, plate} from './socket'
import {h, resolveComponent} from 'vue'

const UButton = resolveComponent('UButton')
const PlateUrl= resolveComponent('plateurl')
const overlay = useOverlay()
const items = reactive([])
const columns = [
  {accessorKey: 'code', header: ({column}) => colHead(UButton, column, {label: 'Code'})},
  {accessorKey: 'name', header: ({column}) => colHead(UButton, column, {label: 'Name'})},
  {accessorKey: 'delta', header: ({column}) => colHead(UButton, column, {label: 'Delta'})},
]
const sort = ref([
  {id: 'code', desc: true}
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

socket
  .on('connect', () => {
    socket.emit('plate')
  })
  .on('delta', delta(items))
  .on('plate', plate(items))
</script>

<style>
tbody tr:hover {
  background-color: #f0f0f0;
}
</style>
