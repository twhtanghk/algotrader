<template>
  <UTable sticky :data='items' :columns='columns'>
    <template #costPrice-cell='{row}'>
      {{row.original.costPrice.toFixed(2)}}
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
  </UTable>
</template>

<script setup>
import _ from 'lodash'
import {reactive} from 'vue'

const props = defineProps(['account'])
const items = reactive([])
const columns = [
  {accessorKey: 'code', header: 'Code'},
  {accessorKey: 'name', header: 'Name'},
  {accessorKey: 'qty', header: 'Qty'},
  {accessorKey: 'costPrice', header: 'Cost'},
  {accessorKey: 'price', header: 'Price'},
  {accessorKey: 'val', header: 'Value'},
  {accessorKey: 'pl', header: 'PL'}
]

for (const stock of await props.account.position())
  items.unshift(stock)
</script>

<style>
.loss {
  color: red;
}
.profit {
  color: green;
}
table tr td:nth-child(n+3) {
  text-align: right;
}
</style>
