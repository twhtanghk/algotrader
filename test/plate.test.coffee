import _ from 'lodash'
import {Promise} from 'bluebird'
import {describe, test} from 'vitest'
import {Futu} from '../futu.js'
import {default as root} from '../logger'

logger = root.child namespace: 'futu.test'

describe 'futu', ->
  futu = await new Futu()
  accounts = await futu.accounts()
  acc = await accounts[0]

  test 'plate', ->
    logger.info JSON.stringify await futu.plateSet()

  test 'plateSecurity', ->
    logger.info JSON.stringify await futu.plateSecurity code: 'LIST1267'
