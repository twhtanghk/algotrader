import {describe, test} from 'vitest'
import {Futu} from '../futu.js'
import {inject} from 'ssl-root-cas'

describe 'futu', ->
  inject()
  futu = await new Futu()
  accounts = await futu.accounts()

  test 'constant', ->
    console.log Futu.constant
    console.log Futu.invert

  test 'cash', ->
    ret = await accounts[0].cash()
    {power, totalAssets, cash, marketVal} = ret
    console.log {power, totalAssets, cash, marketVal}

  test 'position', ->
    ret = await accounts[0].position()
    console.log ret.map (stock) ->
      {code, name, qty, canSellQty, price, costPrice, val, plVal, plRatio} = stock
      {code, name, qty, canSellQty, price, costPrice, val, plVal, plRatio}

  test 'orders', ->
    ret = await accounts[0].orders()
    console.log ret

  test 'datafeed', ->
    (await futu.dataKL {market: 'hk', code: '01211'})
      .subscribe console.log
