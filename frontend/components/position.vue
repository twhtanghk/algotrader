<template>
  <UTable sticky :data='items' :columns='columns' :sorting='sort'>
    <template #costPrice-cell='{row}'>
      {{row.original.costPrice.toFixed(2)}}
    </template>
    <template #price-cell='{row}'>
      {{row.original.price.toFixed(2)}}
    </template>
    <template #val-cell='{row}'>
      {{row.original.val.toLocaleString()}}
    </template>
    <template #pl-cell='{row}'>
      <div :class="row.original.plVal < 0 ? 'loss' : 'profit'">
        <div>{{row.original.plVal.toLocaleString()}}</div>
        <div>{{(row.original.plRatio * 100).toFixed(2)}}%</div>
      </div>
    </template>
    <template #action-cell='{row}'>
      <UButton @click='trade(row.original)'>Trade</UButton>
    </template>
  </UTable>
</template>

<script setup>
import _ from 'lodash'
import {reactive} from 'vue'
import {OrderCreate} from '#components'

const overlay = useOverlay()
const props = defineProps(['account'])
const items = reactive([])
const newOrder = reactive({
  broker: props.account.broker,
  side: '',
  code: '',
  qty: 0
})
const columns = [
  {accessorKey: 'code', header: 'Code'},
  {accessorKey: 'name', header: 'Name'},
  {accessorKey: 'qty', header: 'Qty'},
  {accessorKey: 'costPrice', header: 'Cost'},
  {accessorKey: 'price', header: 'Price'},
  {accessorKey: 'val', header: 'Value'},
  {accessorKey: 'pl', header: 'PL'},
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

for (const stock of await props.account.position())
  items.unshift(stock)
</script>
