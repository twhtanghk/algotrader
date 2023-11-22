Promise = require 'bluebird'
stats = require 'stats-lite'
EventEmitter = require 'events'
{constituent, indicator} = require './data'
{ohlc} = require './analysis'

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
# not falling within the range [mean - n * stdev, mean + n * stdev]
filterByStdev = (broker, idx='HSI Constituent', n=2) ->
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      indicator broker, code
  list
    .filter (stock) ->
      stock.close <= stock.mean - n * stock.stdev or
      stock.close >= stock.mean + n * stock.stdev
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
  
  # compute support or resistance levels of df
  # subscribe code for stream ohlc data update
  # return eventEmitter to emit
  #   1: if ohlc data breakout for resistance level and higher than last close
  #   -1: if ohlc data breakout for support level and lower than last close
  level: ({market, code}, df, stream) ->
    ret = new EventEmitter()
    levels = ohlc 
      .levels df
      .sort ([priceA, idxA], [priceB, idxB]) ->
        priceA - priceB
    [min, ..., max] = levels
    stream
      .subscribe {market, code}
      .on 'data', ({close, lastClose}) ->
        if close > lastClose and close > max[0]
          ret.emit 1
        if close < lastClose and close < min[0]
          ret.emit -1
    ret

module.exports = {
  orderByRisk
  filterByStdev
  breakout
}
