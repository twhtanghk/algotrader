moment = require 'moment'
Futu = require('futu').default
{data} = require('../data').default
strategy = require('../strategy').default

try
  broker = await new Futu host: 'localhost', port: 33333
  [..., method, code] = process.argv
  {g, destroy} = await data
    broker: broker
    market: 'hk'
    code: code
    beginTime: moment().subtract 2, 'month'
    freq: '1'
  for await i from strategy[method] strategy['indicator'] g
    i.time = new Date i.time * 1000
    if process.env.DEBUG or 'entryExit' of i
      i.timestamp = new Date i.timestamp * 1000
      console.log JSON.stringify i, null, 2
catch err
  console.error err
