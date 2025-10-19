import _ from 'lodash'
import {Promise} from 'bluebird'
import {describe, test} from 'vitest'
import {Futu} from '../futu.js'
import {inject} from 'ssl-root-cas'
import {concat} from 'rxjs'
import {delta} from '../rxStrategy.js'
import {default as root} from '../logger'

logger = root.child 
  namespace: 'futu.test'
  targets: 'stderr%json'

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

  test 'quote 1', ->
    futu
      .subscribe (x) ->
        logger.debug JSON.stringify x, null, 2
    await futu.quote {market: 'hk', code: '00700'}

  test 'subInfo 1', ->
    console.log JSON.stringify (await futu.subInfo()), null, 2

  test 'quote 2', ->
    futu
      .subscribe (x) ->
        console.log JSON.stringify x
    await futu.quote {market: 'hk', code: '00005'}

  test 'subInfo 2', ->
    console.log JSON.stringify (await futu.subInfo()), null, 2

  test 'unsubAll', ->
    await Promise.delay 60000
    console.log JSON.stringify (await futu.unsubAll()), null, 2

  test 'subInfo 3', ->
    console.log JSON.stringify (await futu.subInfo()), null, 2

  test 'securitySnapshot', ->
    console.log JSON.stringify (await futu.securitySnapshot code: '00700'), null, 2
    console.log JSON.stringify (await futu.securitySnapshot code: 'LEN251030P12000'), null, 2

  test 'delta', ->
    (await delta {broker: futu, code: '00700'})
      .subscribe (x) ->
        logger.info JSON.stringify x, null, 2
