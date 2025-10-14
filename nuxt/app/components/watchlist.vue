<template>
<div>
  <UInput v-model='name' @keyup.enter='update'/>
  <UTable sticky :data='items' :columns='columns' :sorting='sort'>
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
import _ from 'lodash'
import {reactive, ref} from 'vue'
import {socket} from './socket'
import {h, resolveComponent} from 'vue'

const UButton = resolveComponent('UButton')
const items = reactive([])
const name = ref('')
const columns = [
  {accessorKey: 'code', header: ({column}) => colHead(UButton, column, {label: 'Code'})},
  {accessorKey: 'name', header: ({column}) => colHead(UButton, column, {label: 'Name'})},
  {accessorKey: 'open', header: 'Open'},
  {accessorKey: 'high', header: 'High'},
  {accessorKey: 'low', header: 'Low'},
  {accessorKey: 'close', header: 'Close'},
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
  .on('watchlist', (msg) => {
    for (const stock of msg) {
      items.unshift(stock)
    }
  })
  .on('quote', (msg) => {
    const {code, close} = msg
    let found = _.find(items, {code})
    if (found)
      _.extend(found, msg)
    else
      items.unshift(msg)
  })
  .on('basic', (msg) => {
    const {code, type, name, data, owner} = msg
    let ret = _.pick(data, 'peRate', 'pbRate')
    if (type == 8)
      ret = _.pick(owner, 'peRate', 'pbRate')
    _.extend(msg, {pe: ret.peRate, pb: ret.pbRate})
    let found = _.find(items, {code})
    if (found)
      _.extend(found, msg)
    else
      items.unshift(msg)
  })

</script>

<style>
.loss {
  color: red
}
.profit {
  color: green
}
</style>
