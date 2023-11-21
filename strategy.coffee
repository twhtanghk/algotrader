Promise = require 'bluebird'
{constituent, indicator} = require './data'
stats = require 'stats-lite'

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

breakout =
  # compare last volume and mean(previous length-1) +- n * stdev
  # return 1: volume up, 0: none, -1: volume down
  volume: (df, n=2) ->
    [curr..., last] = df
    mean = stats.mean curr.map ({volume}) -> volume
    stdev = stats.stdev curr.map ({volume}) -> volume
    if last.volume > mean + n * stdev
      return 1
    else if last.volume < mean - n * stdev
      return -1
    else
      return 0

  # compare last close price and mean(previous length-1) +- n * stdev
  # return 1: price up, 0: none, -1: price down
  price: (df, n=2) ->
    [curr..., last] = df
    mean = stats.mean curr.map ({close}) -> close
    stdev = stats.stdev curr.map ({close}) -> close
    if last.close > mean + n * stdev
      return 1
    else if last.close < mean - n * stdev
      return -1
    else
      return 0
  
module.exports = {
  orderByRisk
  filterBy95
  breakout
}
