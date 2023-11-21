{history, Stream, constituent, indicator} = require '../data'
{Futu} = require 'futu'
Promise = require 'bluebird'

try
  broker = await new Futu host: 'localhost', port: 33333
  for code in await constituent broker
    console.log "#{JSON.stringify await indicator broker, code}"
    await Promise.delay 1000
catch err
  console.error err
