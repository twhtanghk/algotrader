<template>
  <UTable sticky :data='items' :columns='columns' :sorting='sort'>
    <template #code-cell='{row}'>
      <TVUrl :code='row.original.owner?.code || row.original.code'>
        {{row.original.code}}
      </TVUrl>
    </template>
    <template #qty-cell='{row}'>
      <div :class="row.original.qty < 0 ? 'loss' : 'profit'">
        {{row.original.qty}}
      </div>
    </template>
    <template #costPrice-cell='{row}'>
      {{row.original.costPrice.toFixed(2)}}
    </template>
    <template #price-cell='{row}'>
      {{row.original.price.toFixed(2)}}
    </template>
    <template #pe-cell='{row}'>
      {{row.original.pe?.toFixed(2)}}
    </template>
    <template #pb-cell='{row}'>
      {{row.original.pb?.toFixed(2)}}
    </template>
    <template #val-cell='{row}'>
      {{row.original.val.toLocaleString()}}
    </template>
    <template #plVal-cell='{row}'>
      <div :class="row.original.plVal < 0 ? 'loss' : 'profit'">
        {{row.original.plVal.toLocaleString()}}
      </div>
    </template>
    <template #plRatio-cell='{row}'>
      <div :class="row.original.plRatio < 0 ? 'loss' : 'profit'">
        {{plRatio(row.original).toFixed(2)}}%
      </div>
    </template>
    <template #action-cell='{row}'>
      <UButton @click='trade(row.original)'>Trade</UButton>
    </template>
  </UTable>
</template>

<script setup>
import {reactive} from 'vue'
import {OrderCreate} from '#components'
import {socket, position, quote, basic} from './socket'
import {h, resolveComponent} from 'vue'

const UButton = resolveComponent('UButton')
const TVUrl= resolveComponent('tvurl')
const overlay = useOverlay()
const items = reactive([])
const newOrder = reactive({
  side: '',
  code: '',
  qty: 0
})
const columns = [
  {accessorKey: 'code', header: ({column}) => colHead(UButton, column, {label: 'Code'})},
  {accessorKey: 'name', header: ({column}) => colHead(UButton, column, {label: 'Name'})},
  {accessorKey: 'qty', header: 'Qty'},
  {accessorKey: 'costPrice', header: 'Cost'},
  {accessorKey: 'price', header: 'Price'},
  {accessorKey: 'pe', header: ({column}) => colHead(UButton, column, {label: 'PE'})},
  {accessorKey: 'pb', header: ({column}) => colHead(UButton, column, {label: 'PB'})},
  {accessorKey: 'val', header: ({column}) => colHead(UButton, column, {label: 'Value'})},
  {accessorKey: 'plVal', header: ({column}) => colHead(UButton, column, {label: 'PL'})},
  {accessorKey: 'plRatio', header: ({column}) => colHead(UButton, column, {label: 'PL%'})},
  {accessorKey: 'action', header: ''}
]
const modal = overlay.create(OrderCreate, {
  props: newOrder
})
const trade = async ({code, qty}) => {
  newOrder.code = code
  newOrder.qty = qty
  await modal.open()
}
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
const plRatio = ({costPrice, price}) => {
  return (price - costPrice) / costPrice * 100
}

socket
  .on('connect', () => {
    socket.emit('position')
  })
  .on('position', position(items))
  .on('quote', quote(items))
  .on('basic', basic(items))
</script>

<style>
.loss {
  color: red
}
.profit {
  color: green
}
</style>
