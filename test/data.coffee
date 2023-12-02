moment = require 'moment'
{history, Stream, data} = require '../data'
{Futu} = require 'futu'

debug = (obj) ->
  console.error JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    # get history data
    debug await history 
      broker: broker
      market: 'hk'
      code: '00700'

    # create stream of live data
    stream = new Stream broker

    # subscribe for live stock ohlc data of specified market and code
    stream.subscribe 
      market: 'hk'
      code: '00700'

    # subscribe for live options ohlc data of specified market and code
    stream.subscribe
      market: 'hk'
      code: 'TCH231129C330000'

    # display ohlc data of subscribed specified stock or options
    stream.on 'data', console.log

    # get broker portfolilo or position
    console.log await broker.position()

    # get broker past orders
    for await i from broker.historyOrder()
      console.log i

    # get broker past filled orders
    for await i from broker.historyDeal()
      console.log i

    # get hsi constituents stock
    for i from await broker.plateSecurity()
      console.log i

    # get ohlc data from async generator
    for await i from data {broker: broker, code: '00700', beginTime: moment '2022-10-01'}
      i.time = new Date i.time * 1000
      console.log i
  catch err
    console.error err
