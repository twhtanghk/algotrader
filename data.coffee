{Readable} = require 'stream'
import fromEmitter from '@async-generators/from-emitter'
import moment from 'moment'
{ohlc} = require './analysis'
stats = require 'stats-lite'

# stream to provide update of ohlc data for subscribed stocks
class Stream extends Readable
  # futu, 'hk', '00700', '1d'
  constructor: ({@broker, @market, @code, @freq}) ->
    super objectMode: true

    # data: {market, code, timestamp, open, high, low, close, volume, turnover} 
    @broker.on 'candle', (data) =>
      {market, code, freq} = data
      if market == @market and code == @code and freq == @freq
        @resume()
        @push data

    return do =>
      await @broker.subscribe {@market, @code, subtype: @broker.constructor.subTypeMap[@freq]}
      @

  _destroy: ->
    try
      await @broker.unsubscribe {@market, @code, @freq}
    catch err
      console.error err

  _read: ->
    @pause()
    
# get history ohlc data for specified start/end time and update frequency
history = ({broker, market, code, start, end, freq} = {}) ->
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
          klType: broker.constructor.klTypeMap[freq]
          beginTime: start.format 'YYYY-MM-DD'
          endTime: end.format 'YYYY-MM-DD'
      klList

# async generator to get ohlc data for specified broker, stock market and code,
# beginTime, and freq
# return generator and destroy function as {g, destroy} 
data = ({broker, market, code, beginTime, freq}) ->
  market ?= 'hk'
  freq ?= '1'
  stream = (await new Stream {broker, market, code, freq})
  destroy = ->
    stream.destroy()
  g = ->
    if beginTime?
      now = moment()
      endTime = moment beginTime
        .endOf 'month'
      while beginTime.isBefore now
        yield from await history 
          broker: broker
          market: market
          code: code
          start: beginTime
          end: endTime
          freq: freq
        beginTime = beginTime
          .add 1, 'month'
          .startOf 'month'
        endTime = moment beginTime
          .endOf 'month'
    yield from await fromEmitter stream, onNext: 'data'
  {g, destroy}

###
# get constituents stock of specified index
# > index:
#   > HK.HSI Constituent	HSI constituent stocks
#   > HK.HSCEI Stock		HSCEI constituent stocks
#   > HK.Motherboard		Main Plate of Hong Kong Stocks
#   > HK.GEM		GEM(Growth Enterprise Market) Hong Kong Stocks
#   > HK.BK1910		All Hong Kong stocks
#   > HK.BK1911		Main Plate H shares
#   > HK.BK1912	GEM H shares
#   > HK.Fund	ETF (Hong Kong Stock Fund)
#   > HK.BK1600	Hot List (Hong Kong)
#   > HK.BK1921	Listed new shares-Hong Kong stocks
#   > SH.3000000	Shanghai Main Plate
#   > SH.BK0901	Shanghai Stock Exchange B shares
#   > SH.BK0902	Shenzhen Stock Exchange B shares
#   > SH.3000002	Shanghai and Shenzhen Index
#   > SH.3000005	All A-shares (Shanghai and Shenzhen)
#   > SH.BK0600	Hot List (Shanghai and Shenzhen)
#   > SH.BK0992	Science Innovation Plate
#   > SH.BK0921	Listed New Shares - A-shares
#   > SZ.3000001	SZSE Main Plate
#   > SZ.3000003	Small and Medium Plate
#   > SZ.3000004	The Growth Enterprise Market (Deep)
#   > US.USAALL	All US stocks
###
constituent = (broker, idx='HSI Constituent') ->
  await broker.plateSecurity code: idx

freqDuration =
  '1': week: 1
  '5': week: 1
  '15': week: 1
  '30': week: 1
  '1h': week: 1
  '1d': year: 1
  '1w': year: 10
  '1m': year: 30
  '3m': year: 30
  '1y': year: 60

export default {
  Stream
  history
  data
  constituent
  freqDuration
}
