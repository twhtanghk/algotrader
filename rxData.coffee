_ = require 'lodash'
{Subject, take, from, merge, concat, filter, tap, map} = require 'rxjs'
moment = require 'moment'
{ohlc} = require './analysis'

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

class Order extends Subject
  @SIDE: ['buy', 'sell']
  @TYPE: ['limit', 'market']
  @TIMEINFORCE: ['gtc']

  constructor: ({@account, @id, @code, @name, @side, @type, @status, @price, @qty, @timeInForce, @createTime, @updateTime}) ->
    super()
    @type ?= 'LIMIT'
    @timeInForce ?= 'GTC'
    @createTime ?= moment().unix()

  toJSON: ->
    {@id, @code, @name, @side, @type, @status, @price, @qty, @timeInForce, @createTime, @updateTime}

class Account extends Subject
  position: ->
    throw new Error 'calling Account virtual method position'
  historyOrder: ({beginTime, endTime}) ->
    throw new Error 'calling Account virtual method historyOrder'
  streamOrder: ->
    throw new Error 'calling Account virtual method streamOrder'
  placeOrder: (order) ->
    throw new Error 'calling Account virtual method streamOrder'
  cancelOrder: (order) ->
    throw new Error 'calling Account virtual method cancelOrder'
  fundAvailable: (order) ->
    {code, pair, side, qty, price} = order
    pos = await @position()
    bal = [
      pos[pair[0]] || 0
      pos[pair[1]] || 0
    ]
    (side == 'buy' and bal[1] > qty * price) or (side == 'sell' and bal[0] > qty)
  orders: ({beginTime}={}) ->
    history = (await @historyOrder {beginTime})
      .pipe map (order) ->
        type: 'orderList'
        data: order
    brokerUpdate = (await @streamOrder())
      .pipe tap console.log
      .pipe map (order) ->
        type: 'orderChg'
        data: order
    (merge history, brokerUpdate, @)
      .pipe filter ({type}) ->
        type.match /order.*/

class TestAccount extends Account
  balance: null
  code: null
  orderList: []
  ocoList: []
  stream:
    order: new Subject()
    oco: new Subject()
    position: new Subject()

  constructor: ({balance}) ->
    super()
    @balance = balance

  next: (ohlc) ->
    super()
    {open, high, low, high} = ohlc
    @ocoList
      .map ({id, code, pair, side, qty, below, above, status}, i) =>
        if status != 'FILLED'
          bal = @position()
          if low <= below.price and below.price <= high
            console.log "oco #{i} filled"
            # check position
            ret = @placeOrder {code, pair, side, qty, price: below.price, ocoId: i}
            _.extend @ocoList[i], ret
          if low <= above.price and above.price <= high
            console.log "oco #{i} filled"
            # check position
            ret = @placeOrder {code, pair, side, qty, price: above.price, ocoId: i}
            _.extend @ocoList[i], ret

  position: ->
    @balance

  historyOrder: ->
    @orderList

  placeOrder: (order) ->
    {code, pair, side, price, qty} = order
    if not await @fundAvailable order
      throw new Error "fund not available for order #{side} #{qty} at #{price}"
    if code != pair[0] + pair[1]
      throw new Error "invalid code #{code} #{pair}"
    if side not in ['buy', 'sell']
      throw new Error "invalid side #{side}"
    qty = qty * (if side == 'buy' then 1 else -1)
    @balance[pair[0]] = @balance[pair[0]] + qty
    @balance[pair[1]] = @balance[pair[1]] - price * qty
    @orderList.push _.extend order, {id: @orderList.length, status: 'FILLED'}
    @stream.order.next order
    @stream.position.next @position()
    order

  placeOCO: (order) ->
    @ocoList.push _.extend order, id: @ocoList.length
    @stream.oco.next order
    order

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
  defaultAcc: ->
    (await @accounts())[0]
  testAcc: (balance) ->
    new TestAccount balance
  orderBook: ({market, code}) ->
    throw new Error 'calling Broker virtual method orderBook'
  quickQuote: ({market, code}) ->
    new Promise (resolve, reject) =>
      subscription = (await @orderBook {market, code})
        .pipe take 1
        .subscribe 
          next: ({bid, ask}) ->
            subscription.unsubscribe()
            resolve 
              buy: bid[0].price
              sell: ask[0].price
          error: reject

module.exports = {
  Order
  Account
  Broker
  constituent
  freqDuration
}
