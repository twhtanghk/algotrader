Promise = require 'bluebird'
moment = require 'moment'
stats = require 'stats-lite'
EventEmitter = require 'events'
{constituent, history, data} = require './data'
{ohlc} = require './analysis'

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
        # upward breakout for one of existing levels
        if sign == 1 and last.lastClose < l and l < last.close
          last.breakout = 1
        # downward breakout for one of existing levels
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

# supplement mean of close value
meanClose = (df, chunkSize=20) ->
  yield from await meanReversion df, {field: 'close', chunkSize: chunkSize, n: 0}

# supplement mean of volume value
meanVol = (df, chunkSize=20) ->
  yield from await meanReversion df, {field: 'volume', chunkSize: chunkSize, n: 0}

# supplement mean of close and vol, support and resistance levels
# of last chunkSize elements for input generator of ohlc series  
indicator = (df, chunkSize=20) ->
  close = ->
    yield from await meanClose df, chunkSize
  vol = ->
    yield from await meanVol close, chunkSize
  yield from await levels vol, chunkSize

# get constituent stocks of input index and sort by risk (stdev)
orderByRisk = (broker, idx='HSI Constituent', chunkSize=60) ->
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      beginTime = moment()
        .subtract 6, 'month'
      df = ->
        opts =
          broker: broker
          code: code
          beginTime: beginTime
          freq: '1d'
        for i in await history opts
          yield i
      last = null
      for await i from indicator df, chunkSize
        last = i
      {code, last}
  list
    .sort (stockA, stockB) ->
      stockA.last['close.stdev'] - stockB.last['close.stdev']
        
# get constituent stock of input index and sortlisted those stocks
# not falling within the range [mean - n * stdev, mean + n * stdev]
filterByStdev = (broker, idx='HSI Constituent', chunkSize=60, n=2) ->
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      beginTime = moment()
        .subtract 6, 'month'
      df = ->
        opts =
          broker: broker
          code: code
          beginTime: beginTime
          freq: '1d'
        for i in await history opts
          yield i
      ind = -> 
        yield from await indicator df, chunkSize
      last = null
      for await i from ind() 
        last = i
      {code, last}
  list
    .filter ({last}) ->
      last['close'] <= last['close.mean'] - n * last['close.stdev'] or
      last['close'] >= last['close.mean'] + n * last['close.stdev']
    .sort (stockA, stockB) ->
      stockA.last['close.stdev'] - stockB.last['close.stdev']

module.exports = {
  levels
  meanReversion
  indicator
  orderByRisk
  filterByStdev
}
