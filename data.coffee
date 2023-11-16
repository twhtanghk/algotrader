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
  constructor: (exchange, codes, freq='1') ->
    super objectMode: true
    if not Array.isArray codes
      codes = [codes]

    do =>
      for {market, code} in codes
        await exchange.subscribe
          market: market
          code: code
          subtype: freq

    # data: {market, code, timestamp, open, high, low, close, lastClose, volume, turnover} 
    exchange.on 'candle', (data) ->
      @push data

    @
    
history = (exchange, {market, code, start, end, freq} = {}) ->
  market ?= 'hk'
  end ?= moment()
  start ?= moment end
    .subtract 6, 'month'
  freq ?= '1d'
  switch market
    when 'hk'
      {klList} = await exchange
        .historyKL
          security:
            market: exchange.constructor.marketMap[market]
            code: code
          klType: exchange.constructor.freqMap[freq]
          beginTime: start.format 'YYYY-MM-DD'
          endTime: end.format 'YYYY-MM-DD'
      klList

module.exports =
  market: market
  freq: freq
  Stream: Stream
  history: history
