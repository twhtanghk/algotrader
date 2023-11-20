{Readable} = require 'stream'
import moment from 'moment'

market = [
  'hk'
  'us'
]

freq = [
  '1'
  '5'
  '15'
  '1h'
  '1d'
  '1w'
  '1m'
  '1y'
]

class Stream extends Readable
  # codes = {market, code} or [{market, code}, ....]
  constructor: (@broker) ->
    super objectMode: true
    # data: {market, code, timestamp, open, high, low, close, lastClose, volume, turnover} 
    @broker.on 'candle', (data) =>
      @resume()
      @push data

  subscribe: (codes, freq) ->
    if not Array.isArray codes
      codes = [codes]

    do =>
      {marketMap, freqMap} = @broker.constructor
      for {market, code} in codes
        await @broker.subscribe
          market: marketMap[market]
          code: code
          subtype: freqMap[freq]

  unSubscribe: (codes, freq) ->
    if not Array.isArray codes
      codes = [codes]

    do =>
      {marketMap, freqMap} = @broker.constructor
      for {market, code} in codes
        await @broker.unSubscribe
          market: marketMap[market]
          code: code
          subtype: freqMap[freq]

  _read: ->
    @pause()
    
history = (broker, {market, code, start, end, freq} = {}) ->
  market ?= 'hk'
  end ?= moment()
  start ?= moment end
    .subtract 6, 'month'
  freq ?= '1d'
  switch market
    when 'hk'
      {klList} = await broker
        .historyKL
          security:
            market: broker.constructor.marketMap[market]
            code: code
          klType: broker.constructor.freqMap[freq]
          beginTime: start.format 'YYYY-MM-DD'
          endTime: end.format 'YYYY-MM-DD'
      klList

module.exports =
  market: market
  freq: freq
  Stream: Stream
  history: history
