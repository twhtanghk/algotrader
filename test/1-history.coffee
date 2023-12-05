{history} = require '../data'
{Futu} = require 'futu'

debug = (obj) ->
  console.log JSON.stringify obj, null, 2
do ->
  try 
    broker = await new Futu host: 'localhost', port: 33333

    # get history data
    ret = await history 
      broker: broker
      market: 'hk'
      code: '01211'
    debug ret.map (i) ->
      i.time = new Date i.time * 1000
      i

  catch err
    console.error err
