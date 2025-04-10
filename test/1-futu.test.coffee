import {expect, test} from 'vitest'
import {Futu} from '../futu.js'
import {inject} from 'ssl-root-cas'

inject()

test 'cash', {timeout: 10000}, ->
  futu = await new Futu()
  accounts = await futu.accounts()
  console.log await accounts[0].cash()
