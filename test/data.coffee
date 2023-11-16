{history} = require '../data'
{Futu} = require 'futu'

debug = (obj) ->
  console.error JSON.stringify obj, null, 2

do ->
  try 
    exchange = await new Futu host: 'localhost', port: 33333
    debug await history exchange,
      market: 'hk'
      code: '00700'
  catch err
    console.error err
