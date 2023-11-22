{Futu} = require 'futu'
{history, Stream} = require '../data'
{breakout} = require '../strategy'

do ->
  try
    broker = await new Futu host: 'localhost', port: 33333
    market = 'hk'
    code = '00388'
    df = await history broker, {market, code}
    stream = await new Stream broker
    breakout
      .level {market, code}, df, stream
      .on '1', ->
        console.log 'up'
      .on '-1', ->
        console.log 'down'
  catch err
    console.error err
