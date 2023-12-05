moment = require 'moment'
Futu = require('futu').default
{data} = require '../data'
strategy = require '../strategy'

try
  broker = await new Futu host: 'localhost', port: 33333
  [..., method, code] = process.argv
  df = ->
    yield from await data
      broker: broker
      market: 'hk'
      code: code
      beginTime: moment().subtract 2, 'month'
      freq: '1'
  ind = ->
    yield from await strategy['indicator'] df
  action = ->
    yield from await strategy[method] ind
  for await i from action()
    if 'entryExit' of i
      i.timestamp = new Date i.timestamp * 1000
      console.log JSON.stringify i, null, 2
catch err
  console.error err
