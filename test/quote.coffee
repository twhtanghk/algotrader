moment = require 'moment'
{Stream, data} = require '../data'
{meanReversion} = require '../strategy'
{Futu} = require 'futu'

do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    # get ohlc data from async generator
    df = ->
      yield from await data {broker: broker, code: '00700', beginTime: moment('2023-11-01'), freq: '15'}
    vol = ->
      yield from await meanReversion df, {field: 'volume', n: 0}
    for await i from df()
      i.timestamp = new Date i.timestamp * 1000
      console.log i
  catch err
    console.error err
