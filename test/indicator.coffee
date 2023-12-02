moment = require 'moment'
{Futu} = require 'futu'
{data} = require '../data'
{indicator} = require '../strategy'

do ->
  try
    broker = await new Futu host: 'localhost', port: 33333

    df = ->
      yield from await data {broker: broker, code: process.argv[2], beginTime: moment('2022-01-01'), freq: '1d'}
    for await i from indicator df, 180
      if i.breakout in [1, -1]
        i.timestamp = new Date i.timestamp * 1000
        console.log i
  catch err
    console.error err
