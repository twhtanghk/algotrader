moment = require 'moment'
Futu = require('futu').default
{data} = require('../data').default
{meanClose} = require('../strategy').default

try
  broker = await new Futu host: 'localhost', port: 33333
  {g, destroy} = await data
      broker: broker
      market: 'hk'
      code: process.argv[2]
      beginTime: moment().subtract year: 2
      freq: '1'
  for await i from meanClose(g)()
    i.timestamp = new Date i.timestamp * 1000
    console.log JSON.stringify i, null, 2
catch err
  console.error err
