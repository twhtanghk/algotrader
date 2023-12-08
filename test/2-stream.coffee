{Stream} = require '../data'
Futu = require('futu').default

debug = (obj) ->
  console.log JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    stream = await new Stream
      broker: broker
      market: process.argv[2]
      code: process.argv[3]
      freq: '1'
    stream
      .on 'data', (data) ->
        data.timestamp = new Date data.timestamp * 1000
        console.log data

  catch err
    console.error err
