moment = require 'moment'
{data} = require '../data'
{meanReversion} = require '../strategy'
{Futu} = require 'futu'

do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    # get ohlc data from async generator
    df = ->
      yield from await data {broker: broker, code: '00700', beginTime: moment('2022-01-01'), freq: '1d'}
    meanClose = (df) ->
      yield from await meanReversion df, field: 'close'
    meanVolume = (df) ->
      yield from await meanReversion df, field: 'volume'
    for await i from do -> yield from await meanVolume -> yield from await meanClose df
      i.time = new Date i.time * 1000
      console.log i
  catch err
    console.error err
