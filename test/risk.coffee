Futu = require('futu').default
{orderByRisk} = require '../strategy'

try
  broker = await new Futu host: 'localhost', port: 33333
  ret = (await orderByRisk broker)
    .map ({code, last}) ->
      last['close.min'] = last['close.mean'] - 2 * last['close.stdev']
      last['close.max'] = last['close.mean'] + 2 * last['close.stdev']
      {code, last}
  console.log JSON.stringify ret, null, 2
catch err
  console.error err
