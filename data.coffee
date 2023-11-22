{Readable} = require 'stream'
import moment from 'moment'
{ohlc} = require './analysis'
stats = require 'stats-lite'

# supported market
market = [
  'hk'
  'us'
]

# frequency to provide update of ohlc data
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

# stream to provide update of ohlc data for subscribed stocks
class Stream extends Readable
  # codes = {market, code} or [{market, code}, ....]
  constructor: (@broker) ->
    super objectMode: true
    # data: {market, code, timestamp, open, high, low, close, lastClose, volume, turnover} 
    @broker.on 'candle', (data) =>
      @resume()
      @push data

  # subscribe stocks for ohlc data update and frequency for the update
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
    @

  # unsubscribe stocks for ohlc data update and frequency for the update
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
    @

  _read: ->
    @pause()
    
# get history ohlc data for specified start/end time and update frequency
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

# get last.close, mean, stdev, support and resistance levels of specified stock
indicator = (broker, code) ->
  df = await history broker,
    market: 'hk'
    code: code
  [..., last] = df
  close = last.close
  levels = ohlc
    .levels df
    .sort ([closeA, idxA], [closeB, idxB]) ->
      closeA - closeB
  mean = stats.mean levels.map ([close, idx]) ->
    close
  stdev = stats.stdev levels.map ([close]) -> close
  { code, close, mean, stdev, levels }

module.exports = {
  market
  freq
  Stream
  history
  constituent
  indicator
}
