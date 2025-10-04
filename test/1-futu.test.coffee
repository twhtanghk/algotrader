import _ from 'lodash'
import {describe, test} from 'vitest'
import {Futu} from '../futu.js'
import {inject} from 'ssl-root-cas'
import {concat} from 'rxjs'

describe 'futu', ->
  inject()
  futu = await new Futu()
  accounts = await futu.accounts()
  acc = await accounts[0]

  test 'constant', ->
    console.log Futu.constant
    console.log Futu.invert

  test 'cash', ->
    console.log _.pick await acc.cash(), [
      'power'
      'totalAssets'
      'cash'
      'marketVal'
    ]

  test 'position', ->
    ret = await (await accounts[0]).position()
    console.log ret.map (stock) ->
      _.pick stock, [
        'code'
        'name'
        'qty'
        'canSellQty'
        'price' 
        'costPrice'
        'val'
        'plVal'
        'plRatio'
      ]

  test 'orders', ->
    acc.subscribe console.log

  test 'datafeed', ->
    (await futu.dataKL {market: 'hk', code: '01211'})
      .subscribe console.log

  test 'quote', ->
    console.log await futu.quote {market: 'hk', code: '00700'}
