moment = require 'moment'
{Futu} = require 'futu'
{data} = require '../data'
{levels, meanReversion} = require '../strategy'

do ->
  try
    broker = await new Futu host: 'localhost', port: 33333

    df = ->
      yield from await data {broker: broker, code: '00700', beginTime: moment('2022-01-01'), freq: '1d'}
    mean = -> 
      yield from await meanReversion df, {field: 'volume', chunkSize: 20, n: 0}
    vol = ->
      yield from await levels mean, 180
    for await i from vol()
      i.time = new Date i.time * 1000
      if i['volume.trend'] == 1 and i.breakout in [1, -1]
        console.log i
  catch err
    console.error err
