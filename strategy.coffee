Promise = require 'bluebird'
moment = require 'moment'
stats = require 'stats-lite'
EventEmitter = require 'events'
{constituent, history, data} = require('./data').default
{ohlc} = require('./analysis').default
{uniqBy, lookBack} = require('generator').default

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

# input generator of data series with indicators (levels, meanClose, meanVol)
# yield entryExit
#   for sell if close > close.mean + n * close.stdev
#   for buy if close.mean - n * close.stdev > close
meanReversion = (df, {chunkSize, n, plRatio}={}) ->
  chunkSize ?= 60
  n ?= 2
  plRatio ?= [0.01, 0.005]
  for await i from df()
    price = (i.high + i.low) / 2
    if i['close'] > i['close.mean'] + n * i['close.stdev']
      i.entryExit =
        side: 'sell'
        plPrice: [
          ((1 - plRatio[0]) * price).toFixed 2
          ((1 + plRatio[1]) * price).toFixed 2
        ]
    if i['close.mean'] - n * i['close.stdev'] > i['close']
      i.entryExit =
        side: 'buy'
        plPrice: [
          ((1 + plRatio[0]) * price).toFixed 2
          ((1 - plRatio[1]) * price).toFixed 2
        ]
    yield i
    
# return generator for elements with mean, stdev of specified field
# for last chunkSize of elements
# element[#{field}.trend] = -1 down trend if element[field] < mean - n * stdev
# element[#{field}.trend] = 1 up trend if element[field] > mean + n * stdev
meanField = (df, {field, chunkSize, n}) -> ->
  chunkSize ?= 60
  n ?= 2
  for await {i, chunk} from lookBack(df, chunkSize)()
    series = chunk.map (j) -> j[field]
    i["#{field}.stdev"] = stats.stdev series
    i["#{field}.mean"] = stats.mean series
    i["#{field}.trend"] = switch
      when i[field] < i["#{field}.mean"] - n * i["#{field}.stdev"] then -1
      when i[field] > i["#{field}.mean"] + n * i["#{field}.stdev"] then 1
      else 0
    yield i

# supplement mean of close value
meanClose = (df, {chunkSize, n}={}) ->
  chunkSize ?= 20
  n ?= 2
  meanField df, {field: 'close', chunkSize: chunkSize, n: n}

# supplement mean of volume value
meanVol = (df, {chunkSize, n}={}) ->
  chunkSize ?= 20
  n ?= 0
  meanField df, {field: 'volume', chunkSize: chunkSize, n: n}

# supplement mean of close and vol, support and resistance levels
# of last specified chunkSize elements for input generator of ohlc series  
indicator = (df, [closeSize, volSize, levelSize]=[20, 20, 180]) -> ->
  close = meanClose df, chunkSize: closeSize
  vol = meanVol close, chunkSize: volSize
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
          code: code
          start: beginTime
          freq: '1d'
        for i in await broker.historyKL opts
          yield i
      last = null
      for await i from indicator(df)()
        last = i
      {code, last}
  list
    .sort (stockA, stockB) ->
      stockA.last['close.stdev'] - stockB.last['close.stdev']
        
# get constituent stock of input index and sortlisted those stocks
# not falling within the range [mean - n * stdev, mean + n * stdev]
filterByStdev = (opts={}) ->
  {broker, idx, beginTime, chunkSize, n} = opts
  idx ?= 'HSI Constituent'
  beginTime ?= moment()
    .subtract 6, 'month'
  chunkSize ?= 60
  n ?= 2
  list = await Promise
    .mapSeries (await constituent broker, idx), (code) ->
      await Promise.delay 1000
      df = ->
        yield from await broker.historyKL
          market: 'hk'
          code: code
          start: beginTime
          freq: '1d'
      last = null
      for await i from (meanClose meanVol df)() 
        last = i
      {code, last}
  list
    .filter ({last}) ->
      last['close'] <= last['close.mean'] - n * last['close.stdev'] or
      last['close'] >= last['close.mean'] + n * last['close.stdev']
    .sort (stockA, stockB) ->
      stockA.last['close.stdev'] - stockB.last['close.stdev']

# input async generator of data series
# keep history of last chunkSize of elements
# filter those items satisfy the input predicate for last chunkSize of elements
filter = (df, predicate, chunkSize=1) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length == chunkSize
      if predicate chunk
        yield i
      chunk.shift()
    else
      yield i

# input generator of data series with indicators (levels, meanClose, meanVol)
# if vol > vol['mean'] * (1 + volRatio)
#   if df[2] is resistance level
#     buy at close price
#   if df[2] is support level
#     sell at close price
levelVol = (df, {volRatio, plRatio}={volRatio: 0.2, plRatio: [0.01, 0.005]}) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length == 5
      if 'volume.mean' of i and i['volume'] > i['volume.mean'] * (1 + volRatio)
        price = (i.high + i.low) / 2
        if ohlc.isSupport chunk, 2
          i.entryExit =
            side: 'buy'
            plPrice: [
              ((1 + plRatio[0]) * price).toFixed 2
              ((1 - plRatio[1]) * price).toFixed 2
            ]
        if ohlc.isResistance chunk, 2
          i.entryExit =
            side: 'sell'
            plPrice: [
              ((1 - plRatio[0]) * price).toFixed 2
              ((1 + plRatio[1]) * price).toFixed 2
            ]
      chunk.shift() 
    yield i
      
# input generator of data series with indicators (levels, meanClose, meanVol)
# if vol > vol['mean'] * (1 + volRatio) and volume down trend
#   if price up
#     sell
#   if price down
#     buy
priceVol = (df, {volRatio, plRatio}={volRatio: 0.2, plRatio: [0.01, 0.005]}) ->
  chunk = []
  for await i from df()
    chunk.push i
    if chunk.length == 3 
      [a, b, c] = chunk
      if 'volume.mean' of c and c['volume'] > c['volume.mean'] * (1 + volRatio) and a.volume > b.volume and b.volume > c.volume
        price = (i.high + i.low) / 2
        if a.close > b.close and b.close > c.close
          i.entryExit =
            side: 'buy'
            plPrice: [
              ((1 + plRatio[0]) * price).toFixed 2
              ((1 - plRatio[1]) * price).toFixed 2
            ]
        if a.close < b.close and b.close < c.close
          i.entryExit =
            side: 'sell'
            plPrice: [
              ((1 - plRatio[0]) * price).toFixed 2
              ((1 + plRatio[1]) * price).toFixed 2
            ]
      chunk.shift()
    yield i
      
# buy at low price level
# buy at mid grid level if price hits higher grid level
# sell at mid grid level if price hits lower grid level
# sell all at high price level
gridTrend = (df, {low, high, gridSize, stopLoss}) ->
  gridSize ?= 3
  stopLoss ?= 0.01
  levels = []
  for i in [low..high] by (high - low) / gridSize
    levels.push i
  for await {i, chunk} from lookBack(df, 2)()
    series = chunk.map ({close}) -> close
    if series.length == 2
      for price, index in levels
        if series[0] < price and price < series[1]
          i.entryExit =
            side: 'buy'
            plPrice: [
              price
              if index == 0 then low * (1 - stopLoss) else levels[index - 1]
            ]
        else if series[0] > price and price > series[1]
          i.entryExit =
            side: 'sell'
            plPrice: [
              if i == series.length - 1 then high * (1 + stopLoss) else levels[i - 1]
              price
            ]
    yield i

export default {
  levels
  meanReversion
  meanField
  meanClose
  meanVol
  indicator
  orderByRisk
  filterByStdev
  filter
  levelVol
  priceVol
  gridTrend
}
