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
levels = (df, chunkSize=180) ->
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
    if chunk.length == chunkSize
      series = chunk.map (data) ->
        data[field]
      i["#{field}.stdev"] = stats.stdev series
      i["#{field}.mean"] = stats.mean series
      
      if i[field] < i["#{field}.mean"] - n * i["#{field}.stdev"]
        i["#{field}.trend"] = -1
      else if i[field] > i["#{field}.mean"] + n * i["#{field}.stdev"]
        i["#{field}.trend"] = 1
      else
        i["#{field}.trend"] = 0
      chunk.shift()
    yield i

# supplement mean of close value
meanClose = (df, chunkSize=20) ->
  yield from await meanReversion df, {field: 'close', chunkSize: chunkSize, n: 0}

# supplement mean of volume value
meanVol = (df, chunkSize=20) ->
  yield from await meanReversion df, {field: 'volume', chunkSize: chunkSize, n: 0}

# supplement mean of close and vol, support and resistance levels
# of last specified chunkSize elements for input generator of ohlc series  
indicator = (df, [closeSize, volSize, levelSize]=[20, 20, 180]) ->
  close = ->
    yield from await meanClose df, closeSize
  vol = ->
    yield from await meanVol close, volSize
  yield from await levels vol, levelSize

# get constituent stocks of input index and sort by risk (stdev)
orderByRisk = (broker, idx='HSI Constituent', chunkSize=180) ->
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
      for await i from indicator df
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
        yield from await indicator df
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

# input generator of data series with indicators (levels, meanClose, meanVol)
# if vol > vol['mean'] * (1 + volRatio)
#   if df[2] is resistance level
#     buy at close price
#   if df[2] is support level
#     sell at close price
levelVol = (df, volRatio=0.2) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length == 5
      if 'volume.mean' of i and i['volume'] > i['volume.mean'] * (1 + volRatio)
        if ohlc.isSupport chunk, 2
          i.entryExit =
            side: 'buy'
            price: i.close
        if ohlc.isResistance chunk, 2
          i.entryExit =
            side: 'sell'
            price: i.close
      chunk.shift() 
    yield i
      
# input generator of data series with indicators (levels, meanClose, meanVol)
# if vol > vol['mean'] * (1 + volRatio) and volume down trend
#   if price up
#     sell at close
#   if price down
#     buy at close
priceVol = (df, volRatio=0.2) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length == 3 
      [a, b, c] = chunk
      if 'volume.mean' of c and c['volume'] > c['volume.mean'] * (1 + volRatio) and a.volume > b.volume and b.volume > c.volume
        if a.close > b.close and b.close > c.close
          i.entryExit =
            side: 'buy'
            price: i.close
        if a.close < b.close and b.close < c.close
          i.entryExit =
            side: 'sell'
            price: i.close
      chunk.shift()
    yield i
      
module.exports = {
  levels
  meanReversion
  meanClose
  meanVol
  indicator
  orderByRisk
  filterByStdev
  levelVol
  priceVol
}
