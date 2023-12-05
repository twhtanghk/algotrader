{Stream} = require '../data'
Futu = require('futu').default

debug = (obj) ->
  console.log JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    new Stream broker
      .subscribe {market: 'hk', code: process.argv[2]}, '1'
      .on 'data', (data) ->
        data.timestamp = new Date data.timestamp * 1000
        console.log data

  catch err
    console.error err
