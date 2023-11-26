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

# compute support or resistance levels of df for specified chunkSize
# return generator of elements with levels and breakout value
# 1 : if ohlc data breakout for resistance level and 
#     higher than last close
# -1: if ohlc data breakout for support level and 
#     lower than last close
# 0 : no breakout
levels = (df, chunkSize=20) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length < chunkSize
      yield i
    else if chunk.length == chunkSize
      [..., last] = chunk
      last.levels = ohlc 
        .levels chunk
        .map ([price, idx]) ->
          price
        .sort (a, b) ->
          a - b
      last.breakout = 0
      for l in last.levels
        sign = Math.sign(last.close - last.lastClose)
        if sign == 1 and last.lastClose < l and l < last.close
          last.breakout = 1
        else if sign == -1 and last.lastClose > l and l > last.close
          last.breakout = -1
      yield last
      chunk.shift()

# return generator of elements with mean, stdev of specified field
# for last chunkSize of elements
# element[#{field}.trend] = -1 down trend if element[field] < mean - n * stdev
# element[#{field}.trend] = 1 up trend if element[field] > mean + n * stdev
# otherwise element[#{field}.trend] = 0
meanReversion = (df, {field, chunkSize, n}) ->
  chunkSize ?= 60
  n ?= 2
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length < chunkSize
      yield i
    else if chunk.length == chunkSize
      [..., last] = chunk
      series = chunk.map (data) ->
        data[field]
      last["#{field}.stdev"] = stats.stdev series
      last["#{field}.mean"] = stats.mean series
      
      if last[field] < last["#{field}.mean"] - n * last["#{field}.stdev"]
        last["#{field}.trend"] = -1
      else if last[field] > last["#{field}.mean"] + n * last["#{field}.stdev"]
        last["#{field}.trend"] = 1
      else
        last[field + '.trend'] = 0
      yield last
      chunk.shift()

module.exports = {
  orderByRisk
  filterByStdev
  levels
  meanReversion
}
