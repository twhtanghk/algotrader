{Futu} = require 'futu'
{orderByRisk} = require '../strategy'

try
  broker = await new Futu host: 'localhost', port: 33333
  ret = (await orderByRisk broker)
    .map (stock) ->
      stock.min = stock.mean - 2 * stock.stdev
      stock.max = stock.mean + 2 * stock.stdev
      stock
  console.log JSON.stringify ret, null, 2
catch err
  console.error err
