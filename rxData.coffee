import {Subject, concat} from 'rxjs'
import {Readable} from 'stream'
import {EventEmitter} from 'events'
import fromEmitter from '@async-generators/from-emitter'
import moment from 'moment'
{ohlc} = require './analysis'
stats = require 'stats-lite'

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

# key: [actual duration, duration of data to be fetched]
freqDuration =
  '1': 
    duration: minute: 1
    dataFetched: week: 1
  '5':
    duration: minute: 5
    dataFetched: week: 1
  '15': 
    duration: minute: 15
    dataFetched: week: 1
  '30': 
    duration: minute: 30
    dataFetched: week: 1
  '1h':
    duration: hour: 1
    dataFetched: week: 1
  '1d':
    duration: day: 1
    dataFetched: year: 1
  '1w': 
    duration: week: 1
    dataFetched: year: 10
  '1m': 
    duration: month: 1
    dataFetched: year: 30
  '3m':
    duration: month: 3
    dataFetched: year: 30
  '1y': 
    duration: year: 1
    dataFetched: year: 60

class Order extends EventEmitter
  @SIDE: ['BUY', 'SELL']
  @TYPE: ['LIMIT', 'MARKET']
  @TIMEINFORCE: ['GTC']

  constructor: ({account, code, side, type, price, quantity, timeInForce, createTime, updateTime}) ->
    super()
    @account = account
    @code = code
    @side = side || 'BUY'
    @type = type || 'LIMIT'
    @price = price
    @quantity = quantity
    @timeInForce = timeInForce || 'GTC'
    @createTime = createTime
    @updateTime = updateTime

class Account extends EventEmitter
  orderList: []
  position: ->
    throw new Error 'calling Account virtual method position'
  historyOrder: ({start, end}) ->
    throw new Error 'calling Account virtual method historyOrder'
  streamOrder: ->
    throw new Error 'calling Account virtual method streamOrder'
  placeOrder: (opts) ->
    throw new Error 'calling Account virtual method placeOrder'
  orders: ({start}) ->
    history = []
    if start?
      history = await @historyOrder {start}
    ->
      yield from history
      yield from await fromEmitter await @streamOrder()

class Broker extends Subject
  constructor: ->
    super() 
  historyKL: ({market, code, start, end, freq} = {}) ->
    throw new Error 'calling Broker virtual method historyKL'
  streamKL: ({market, code, freq} = {}) ->
    throw new Error 'calling Broker virtual method streamKL'
  dataKL: ({market, code, start, freq}) ->
    freq ?= '1'
    opts = {market, code, start, freq}
    concat (await @historyKL opts), (await @streamKL opts)
  accounts: ->
    throw new Error 'calling Broker virtual method accounts'

export default {
  Order
  Account
  Broker
  constituent
  freqDuration
}
