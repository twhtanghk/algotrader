moment = require 'moment'
{Futu} = require 'futu'
{data} = require '../data'
{indicator, entryExit} = require '../strategy'

try
  broker = await new Futu host: 'localhost', port: 33333
  df = ->
    yield from await data
      broker: broker
      market: 'hk'
      code: process.argv[2]
      beginTime: moment().subtract 2, 'year'
      freq: '1'
  ind = ->
    yield from await indicator df
  for await i from ind()
    i.timestamp = new Date i.timestamp * 1000
    console.log JSON.stringify i, null, 2
catch err
  console.error err
