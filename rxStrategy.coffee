_ = require 'lodash'
Promise = require 'bluebird'
moment = require 'moment'
stats = require 'stats-lite'
EventEmitter = require 'events'
{constituent, history, data} = require('./rxData').default
{ohlc} = require('./analysis').default
import {skipLast, take, tap, zip, bufferCount, concat, filter, toArray, map, takeLast, buffer, last} from 'rxjs'

support = (field='low') -> (obs) ->
  first = obs
    .pipe take 2
  curr = obs
    .pipe bufferCount 5, 1
    .pipe skipLast 2
    .pipe map (x) ->
      ret = x[0][field] > x[1][field] and 
        x[1][field] > x[2][field] and 
        x[2][field] < x[3][field] and 
        x[3][field] < x[4][field]
      if ret
        _.extend x[2], support: ret
      x[2]
  concat first, curr
      
resistance = (field='high') -> (obs) ->
  first = obs
    .pipe take 2
  curr = obs
    .pipe bufferCount 5, 1
    .pipe skipLast 2
    .pipe map (x) ->
      ret = x[0][field] < x[1][field] and
        x[1][field] < x[2][field] and
        x[2][field] > x[3][field] and
        x[3][field] > x[4][field]
      if ret
        _.extend x[2], resistance: ret
      x[2]
  concat first, curr
      
# provide entryExit according to input support or resistance levels array
levels = ({arr, plRatio}) -> (obs) ->
  plRatio ?= [0.01, 0.005]
  obs
    .pipe map (i) ->
      {low, high, open, close} = i
      price = (high + low) / 2
      found = arr.find (l) ->
        low < l and l < high
      if found?
        if open < close
          i.entryExit ?= []
          i.entryExit.push
            strategy: 'levels'
            side: 'buy'
            plPrice: [
              ((1 + plRatio[0]) * price).toFixed 2
              ((1 - plRatio[1]) * price).toFixed 2
            ]
        else if open > close
          i.entryExit ?= []
          i.entryExit.push
            strategy: 'levels'
            side: 'sell'
            plPrice: [
              ((1 - plRatio[0]) * price).toFixed 2
              ((1 + plRatio[1]) * price).toFixed 2
            ]
      i    

# input generator of data series with indicators (levels, meanClose, meanVol)
# yield entryExit
#   for sell if close > close.mean + n * close.stdev
#   for buy if close.mean - n * close.stdev > close
meanReversion = ({chunkSize, n, plRatio}={}) -> (obs) ->
  chunkSize ?= 60
  n ?= 2
  plRatio ?= [0.01, 0.005]
  obs
    .pipe map (i) ->
      price = (i.high + i.low) / 2
      if i['close'] > i['close.mean'] + n * i['close.stdev']
        i.entryExit ?= []
        i.entryExit.push
          strategy: 'meanReversion'
          side: 'sell'
          plPrice: [
            ((1 - plRatio[0]) * price).toFixed 2
            ((1 + plRatio[1]) * price).toFixed 2
          ]
      if i['close.mean'] - n * i['close.stdev'] > i['close']
        i.entryExit ?= []
        i.entryExit.push
          strategy: 'meanReversion'
          side: 'buy'
          plPrice: [
            ((1 + plRatio[0]) * price).toFixed 2
            ((1 - plRatio[1]) * price).toFixed 2
          ]
      i
    
# return generator for elements with mean, stdev of specified field
# for last chunkSize of elements
# element[#{field}.trend] = -1 down trend if element[field] < mean - n * stdev
# element[#{field}.trend] = 1 up trend if element[field] > mean + n * stdev
meanField = (ohlc, {field, n}) ->
  n ?= 2
  series = ohlc.map (i) -> i[field]
  [..., end] = ohlc
  ret = {}
  ret[field] = end[field]
  ret['timestamp'] = end['timestamp']
  ret["#{field}.stdev"] = stats.stdev series
  ret["#{field}.mean"] = stats.mean series
  ret["#{field}.trend"] = switch
    when end[field] < ret["#{field}.mean"] - n * ret["#{field}.stdev"] then -1
    when end[field] > ret["#{field}.mean"] + n * ret["#{field}.stdev"] then 1
    else 0
  ret

# supplement mean of close value
meanClose = (ohlc) ->
  meanField ohlc, {field: 'close'}

# supplement mean of volume value
meanVol = (df) ->
  meanField df, {field: 'volume'}

# stdev of specifed field
stdev = (field, size=20) -> (obs) ->
  ret = obs
    .pipe bufferCount size, 1
    .pipe map (x) ->
      series = x.map (i) -> i[field]
      ind = {}
      ind["#{field}.stdev"] = stats.stdev series
      ind
  zip obs, (concat (new Array size - 1), ret)
    .pipe map ([ohlc, ind]) ->
      _.extend ohlc, ind

# supplement mean of close and vol, support and resistance levels
# of last specified chunkSize elements for input generator of ohlc series  
indicator = (size=20) -> (obs) ->
  ret = obs
    .pipe bufferCount size, 1
    .pipe map (x) ->
      _.extend {},
        (_.pick (meanClose x), ['close.mean', 'close.stdev', 'close.trend', 'close.volatility']),
        (_.pick (meanVol x), ['volume.mean', 'volume.stdev', 'volume.trend'])
  zip obs, (concat (new Array size - 1), ret)
    .pipe map ([ohlc, ind]) ->
      _.extend ohlc, ind
    .pipe stdev 'close.stdev'

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
  await Promise.mapSeries (await constituent broker, idx), ({code, name}) ->
    await Promise.delay 1000
    opts =
      market: 'hk'
      code: code
      start: beginTime
      freq: '1d'
    (await broker.historyKL opts)
      .pipe (takeLast chunkSize), toArray()
      .pipe map (x) ->
        ret =
          market: opts.market
          code: opts.code
          name: name
          freq: opts.freq
        [..., end] = x
        _.extend ret, end, (meanClose x), (meanVol x)

# input generator of data series with indicators (levels, meanClose, meanVol)
# if vol > vol['mean'] * (1 + volRatio)
#   if df[2] is resistance level
#     buy at close price
#   if df[2] is support level
#     sell at close price
levelVol = ({volRatio, plRatio}={volRatio: 0.2, plRatio: [0.01, 0.005]}) ->
  (obs) ->
    obs
      .pipe bufferCount 5, 1
      .pipe map (chunk) ->
        i = chunk[2]
        if i['volume'] > i['volume.mean'] * (1 + volRatio)
          price = (i.high + i.low) / 2
          if ohlc.isSupport chunk, 2
            i.entryExit ?= []
            i.entryExit.push
              strategy: 'levelVol'
              side: 'buy'
              plPrice: [
                ((1 + plRatio[0]) * price).toFixed 2
                ((1 - plRatio[1]) * price).toFixed 2
              ]
          if ohlc.isResistance chunk, 2
            i.entryExit ?= []
            i.entryExit.push
              strategy: 'levelVol'
              side: 'sell'
              plPrice: [
                ((1 - plRatio[0]) * price).toFixed 2
                ((1 + plRatio[1]) * price).toFixed 2
              ]
        i
      
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
          i.entryExit ?= []
          i.entryExit.push
            strategy: 'priceVol'
            side: 'buy'
            plPrice: [
              ((1 + plRatio[0]) * price).toFixed 2
              ((1 - plRatio[1]) * price).toFixed 2
            ]
        if a.close < b.close and b.close < c.close
          i.entryExit ?= []
          i.entryExit.push
            strategy: 'priceVol'
            side: 'sell'
            plPrice: [
              ((1 - plRatio[0]) * price).toFixed 2
              ((1 + plRatio[1]) * price).toFixed 2
            ]
      chunk.shift()
    yield i
      
# see https://www.linkedin.com/pulse/grid-trading-forex-markets-cmsprime-mz0df
# grid trading strategy
# type = range or trend
grid = ({type, low, high, gridSize, stopLoss}) -> (obs) ->
  gridSize ?= 3
  stopLoss ?= 0.01
  grids = []
  typeMap =
    range: ['sell', 'buy']
    trend: ['buy', 'sell']
  for i in [low..high] by (high - low) / gridSize
    grids.push i
  obs
    .pipe map (i) ->
      {open, close} = i
      for price, index in grids
        if i['close.trend'] == 1 and open < price and price < close
          i.entryExit ?= []
          i.entryExit.push
            strategy: "grid #{type}"
            side: typeMap[type][0]
            plPrice: [
              high
              close * (1 - stopLoss)
            ]
        else if i['close.trend'] == -1 and open > price and price > close
          i.entryExit ?= []
          i.entryExit.push
            strategy: "grid #{type}"
            side: typeMap[type][1]
            plPrice: [
              low
              close * (1 + stopLoss)
            ]
      i

# ranging market condition
# sell at mid grid level if price hits higher grid level
# buy at mid grid level if price hits lower grid level
gridRange = ({low, high, gridSize, stopLoss}={}) -> (obs) ->
  grid({type: 'range', low, high, gridSize, stopLoss})(obs)

# trend market condition
# buy at mid grid level if price hits higher grid level
# sell at mid grid level if price hits lower grid level
gridTrend = ({low, high, gridSize, stopLoss}={}) -> (obs) ->
  grid({type: 'trend', low, high, gridSize, stopLoss})(obs)

# volume higher than n * stdev
volUp = ({n}={}) -> (obs) ->
  n ?= 2
  obs
    .pipe map (i) ->
      if i['volume'] > i['volume.mean'] + n * i['volume.stdev']
        i.entryExit ?= []
        i.entryExit.push
          strategy: 'volUp'
          side: true
      i

# https://blueberrymarkets.com/learn/advanced/price-action-trading-strategy/
# pin bar with long lower or upper wick
pinBar = ({percent}={}) -> (obs) ->
  percent ?= 50
  obs
    .pipe map (i) ->
      {high, low, open, close} = i
      if high - Math.max(open, close) > (high - low) * percent / 100
        i.entryExit ?= []
        i.entryExit.push
          strategy: 'pinBar'
          side: 'sell'
      else if Math.min(open, close) - low > (high - low) * percent / 100
        i.entryExit ?= []
        i.entryExit.push
          strategy: 'pinBar'
          side: 'buy'
      i

# inside bar reversal
insideBar = -> (obs) ->
  decision = [
    {mb: -1, ib: -1, action: 'sell'}
    {mb: -1, ib: 1, action: 'buy'}
    {mb: 1, ib: -1, action: 'sell'}
    {mb: 1, ib: 1, action: 'buy'}
  ]
  first = obs
    .pipe take 1
  next = obs
    .pipe bufferCount 2, 1
    .pipe map ([a, b]) ->
      found = _.find decision,
        mb: Math.sign(a.close - a.open)
        ib: Math.sign(b.close - b.open)
      if a.high > b.high and a.low < b.low
        b.entryExit ?= []
        b.entryExit.push
          strategy: 'insideBar'
          side: found?.action
      b
  concat first, next

export default {
  find: {
    support
    resistance
  }
  levels
  meanReversion
  meanField
  meanClose
  meanVol
  stdev
  indicator
  orderByRisk
  filterByStdev
  levelVol
  priceVol
  gridTrend
  gridRange
  volUp
  pinBar
  insideBar
}
