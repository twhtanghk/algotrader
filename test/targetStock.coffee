Futu = require('futu').default
{filterByStdev} = require '../strategy'

try
  broker = await new Futu host: 'localhost', port: 33333
  ret = (await filterByStdev broker)
    .map ({code, last}) ->
      last['close.mean.min'] = last['close.mean'] - 2 * last['close.stdev']
      last['close.mean.max'] = last['close.mean'] + 2 * last['close.stdev']
      {code, last}
  console.log JSON.stringify ret, null, 2
catch err
  console.error err
