Promise = require 'bluebird'
{constituent, indicator} = require './data'

# get constituent stocks of input index and sort by risk (stdev)
orderByRisk = (broker, idx='HSI Constituent') ->
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      indicator broker, code
  list
    .sort (stockA, stockB) ->
      stockA.stdev - stockB.stdev

# get constituent stock of input index and sortlisted those stocks
# not falling within the range [mean - 2 * stdev, mean + 2 * stdev]
filterBy95 = (broker, idx='HSI Constituent') ->
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      indicator broker, code
  list
    .filter (stock) ->
      stock.close <= stock.mean - 2 * stock.stdev or
      stock.close >= stock.mean + 2 * stock.stdev
    .sort (stockA, stockB) ->
      stockA.stdev - stockB.stdev

module.exports = {
  orderByRisk
  filterBy95
}
