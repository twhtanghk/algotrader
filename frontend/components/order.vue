<template>
  <UTable sticky :data='items' :columns='columns'>
    <template #side-cell='{row}'>
      {{row.original.side.replace(/^TrdSide_/, '')}}
    </template>
    <template #type-cell='{row}'>
      {{row.original.type.replace(/^OrderType_/, '')}}
    </template>
    <template #status-cell='{row}'>
      {{row.original.status.replace(/^OrderStatus_/, '')}}
    </template>
    <template #createTime-cell='{row}'>
      {{moment(row.original.createTime).format('DD/MM/YYYY hh:mm:ss')}}
    </template>
    <template #updateTime-cell='{row}'>
      {{moment(row.original.updateTime).format('DD/MM/YYYY hh:mm:ss')}}
    </template>
  </UTable>
</template>

<script setup>
import moment from 'moment'
import {reactive} from 'vue'

const props = defineProps(['account'])
const items = reactive([])
const columns = [
  {accessorKey: 'code', header: 'Code'},
  {accessorKey: 'name', header: 'Name'},
  {accessorKey: 'side', header: 'Side'},
  {accessorKey: 'type', header: 'Type'},
  {accessorKey: 'status', header: 'Status'},
  {accessorKey: 'price', header: 'Price'},
  {accessorKey: 'qty', header: 'Qty'},
  {accessorKey: 'timeInForce', header: 'Valid Time'},
  {accessorKey: 'createTime', header: 'createTime'},
  {accessorKey: 'updateTime', header: 'updateTime'}
]

props.account
  .subscribe((order) =>
    items.push(order))
</script>

<style>
.loss {
  color: red;
}
.profit {
  color: green;
}
</style>
