<template>
  <UModal title='Order'>
    <template #body>
      <UFormField label="Type" required>
        <UInputMenu name='type' v-model='type' :items='["limit", "market"]'/>
      </UFormField>
      <UFormField label="Code" required>
      <UInput name='code' v-model='props.code' />
      </UFormField>
      <UFormField label="Qty" required>
        <UInput name='qty' v-model='props.qty' />
      </UFormField>
      <UFormField label="Price" required>
        <UInput name='price' v-model='price' />
      </UFormField>
      <UFormField label="Total" required>
        {{price * qty}}
      </UFormField>
      <UFormField label="Valid" required>
        <UInputMenu name='valid' v-model='timeInForce' :items='["Day", "GTC"]'/>
      </UFormField>
    </template>
    <template #footer>
     <div class="flex gap-2">
        <UButton color="neutral" label="Cancel" variant='outline' @click='emit("close", false)' />
        <UButton class='buy' label="Buy" @click='confirmOrder("buy")' />
        <UButton class='sell' label="Sell" @click='confirmOrder("sell")' />

	<UModal :open='orderConfirm' title='Confirm Order'>
	  <template #body>
	    <div>Type: {{type}}</div>
	    <div>Side: {{side}}</div>
	    <div>Code: {{props.code}}</div>
	    <div>Name: {{props.name}}</div>
	    <div>Valid: {{timeInForce}}</div>
	    <div>Price: {{price}}</div>
	    <div>Qty: {{props.qty}}</div>
	    <div>Total: {{price * props.qty}}</div>
	  </template>
	  <template #footer>
            <UButton color='neutral' variant='outline' label="Cancel" @click='orderConfirm = false' />
            <UButton color='neutral' variant='outline' label="Confirm" @click='placeOrder' />
          </template>
	</UModal>
      </div>
    </template>
  </UModal>
</template>

<script setup>
import {ref, reactive} from 'vue'

const emit = defineEmits()
const isOpen = ref(false)
const props = defineProps(['broker', 'code', 'name', 'qty'])
const type = ref('limit')
const side = ref('buy')
const timeInForce = ref('Day')
const orderConfirm = ref(false)

const price = (await props.broker.quote({market: 'hk', code: props.code})).curPrice
const confirmOrder = (_side) => {
  side.value = _side
  orderConfirm.value = true
}
const placeOrder = () => {
  orderConfirm.value = false
  emit('close', false)
  console.log(side)
  console.log(props)
}
</script>

<style>
.buy {
  background-color: green;
}
.sell {
  background-color: red;
}
</style>
