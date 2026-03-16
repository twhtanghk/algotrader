import _ from 'lodash'
import moment from 'moment'
import Promise from 'bluebird'
import {ReplaySubject, concat, from, filter, map, tap} from 'rxjs'
import {freqDuration, Broker} from './broker.js'
import {Order} from './order.js'
import ftWebsocket from 'futu-api'
import { ftCmdID } from 'futu-api'
import futuApi from 'futu-api/proto.js'
import {default as root} from './logger.js'

logger = root.child namespace: 'futu'

{PlateSetType, TradeDateMarket, SubType, RehabType, KLType, QotMarket} = futuApi.Qot_Common
{RetType} = futuApi.Common
{ModifyOrderOp, OrderType, OrderStatus, SecurityFirm, TrdEnv, TrdMarket, TrdSecMarket, TrdSide, TimeInForce, TrdCategory} = futuApi.Trd_Common

class FutuOrder extends Order
  @SIDE:
    unknown: TrdSide.TrdSide_Unknown
    buy: TrdSide.TrdSide_Buy
    buyBack: TrdSide.TrdSide_BuyBack
    sell: TrdSide.TrdSide_Sell
    sellShort: TrdSide.TrdSide_SellShort

  @TYPE:
    limit: OrderType.OrderType_Normal
    market: OrderType.OrderType_Market

  @STATUS:
    unsubmitted: OrderStatus.OrderStatus_Unsubmitted
    unknown: OrderStatus.OrderStatus_Unknown
    waitingSubmit: OrderStatus.OrderStatus_WaitingSubmit
    submitting: OrderStatus.OrderStatus_Submitting
    sumitFailed: OrderStatus.OrderStatus_SubmitFailed
    timeout: OrderStatus.OrderStatus_TimeOut
    submitted: OrderStatus.OrderStatus_Submitted
    filledPart: OrderStatus.OrderStatus_Filled_Part
    filledAll: OrderStatus.OrderStatus_Filled_All
    cancellingPart: OrderStatus.OrderStatus_Cancelling_Part
    cancellingAll: OrderStatus.OrderStatus_Cancelling_All
    cancelledPart: OrderStatus.OrderStatus_Cancelled_Part
    cancelledAll: OrderStatus.OrderStatus_Cancelled_All
    failed: OrderStatus.OrderStatus_Failed
    disabled: OrderStatus.OrderStatus_Disabled
    deleted: OrderStatus.OrderStatus_Deleted
    fillCancelled: OrderStatus.OrderStatus_FillCancelled

  constructor: (opts) ->
    super opts
    @side = (_.invert Order.SIDE)[@side] || @side
    @type = (_.invert Order.TYPE)[@type] || @type
    @status = (_.invert Order.STATUS)[@status] || @status
    @fillQty = opts.fillQty
    @fillAvgPrice = opts.fillAvgPrice

  @fromFutu: (i) ->
    {code, name, trdSide, orderType, orderStatus, orderID, orderStatus, price, qty, fillQty, fillAvgPrice, updateTimestamp, createTimestamp} = i
    new Order
      id: orderID.toNumber()
      code: code
      name: name
      side: Futu.invert.TrdSide[trdSide]
      type: Futu.invert.OrderType[orderType]
      status: Futu.invert.OrderStatus[orderStatus]
      price: price
      qty: qty
      fillQty: fillQty
      fillAvgPrice: fillAvgPrice
      updateTime: updateTimestamp
      createTime: createTimestamp

  toJSON: ->
    _.extend super(), {@fillQty, @fillAvgPrice}
      
class Account extends ReplaySubject
  serialNo: 0

  constructor: (opts) ->
    super()
    {broker, trdEnv, accID, trdMarketAuthList, accType, cardNum, securityFirm} = opts
    @broker = broker
    @id = accID
    @trdEnv = trdEnv
    @market = trdMarketAuthList
    @type = accType
    @cardNum = cardNum
    @securityFirm = securityFirm
    return do =>
      (concat await @historyOrder(), await @streamOrder())
        .subscribe (x) =>
          @next x
      return @

  historyOrder: ({beginTime, endTime}={}) ->
    beginTime ?= moment().subtract day: 3
    endTime ?= moment()
    req =
      c2s:
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market
    openOrder = Futu.errHandler await @broker.ws.GetOrderList req
    req.c2s.filterConditions =
      beginTime: beginTime.format 'YYYY-MM-DD hh:mm:ss'
      endTime: endTime.format 'YYYY-MM-DD hh:mm:ss'
    history = Futu.errHandler await @broker.ws.GetHistoryOrderList req
    from (openOrder.orderList
      .concat history.orderList
      .map (order) ->
        (FutuOrder.fromFutu order).toJSON()
    )

  streamOrder: ->
    req =
      c2s:
        accIDList: [@id]
    await @broker.ws.SubAccPush req
    @broker
      .pipe filter ({type, data}) ->
        type in ['Trd_UpdateOrder', 'Trd_UpdateOrderFill']
      .pipe map ({type, data}) ->
        (FutuOrder.fromFutu data.order).toJSON()

  placeOrder: (order) ->
    super order
    req =
      c2s:
        packetID:
          connID: @broker.ws.getConnID()
          serialNo: @serialNo++
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market
        trdSide: Order.SIDE[order.side]
        orderType: Order.TYPE[order.type]
        code: order.code
        qty: order.qty
        price: order.price
        secMarket: TrdSecMarket.TrdSecMarket_HK
    Futu.errHandler await @broker.ws.PlaceOrder req

  cancelOrder: (order) ->
    req =
      c2s:
        packetID:
          connID: @broker.ws.getConnID()
          serialNo: @serialNo++
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market
        orderID: order.id
        modifyOrderOp: ModifyOrderOp.ModifyOrderOp_Cancel
    Futu.errHandler await @broker.ws.ModifyOrder req

  updateOrder: (order) ->
    req =
      c2s:
        packetID:
          connID: @broker.ws.getConnID()
          serialNo: @serialNo++
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market
        orderID: order.id
        qty: order.qty
        price: order.price
        modifyOrderOp: ModifyOrderOp.ModifyOrderOp_Normal
    Futu.errHandler await @broker.ws.modifyOrder req
    
  position: ->
    req =
      c2s:
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market[0]
    (Futu.errHandler await @broker.ws.GetPositionList req).positionList

  cash: (opts={currency: 1}) ->
    {currency} = opts
    req =
      c2s:
        header:
          trdEnv: @trdEnv
          accID: @id
          trdMarket: @market[0]
        currency: currency
    (Futu.errHandler await @broker.ws.GetFunds req).funds

class Futu extends Broker
  @marketMap:
    'hk': QotMarket.QotMarket_HK_Security
    'us': QotMarket.QotMarket_US_Security

  @subTypeMap:
    'Basic': SubType.SubType_Basic
    'Broker': SubType.SubType_Broker
    '1': SubType.SubType_KL_1Min
    '5': SubType.SubType_KL_5Min
    '15': SubType.SubType_KL_15Min
    '30': SubType.SubType_KL_30Min
    '1h': SubType.SubType_KL_60Min
    '1d': SubType.SubType_KL_Day
    '1w': SubType.SubType_KL_Week
    '1m': SubType.SubType_KL_Month
    '3m': SubType.SubType_KL_Quarter
    '1y': SubType.SubType_KL_Year

  @freqMap: Futu.subTypeMap

  @klTypeMap:
    '1': KLType.KLType_1Min
    '5': KLType.KLType_5Min
    '15': KLType.KLType_15Min
    '30': KLType.KLType_30Min
    '1h': KLType.KLType_60Min
    '1d': KLType.KLType_Day
    '1w': KLType.KLType_Week
    '1m': KLType.KLType_Month
    '3m': KLType.KLType_Quarter
    '1y': KLType.KLType_Year

  @constant: {
    KLType
    ModifyOrderOp
    OrderStatus
    OrderType
    QotMarket
    RehabType
    RetType
    SecurityFirm
    SubType
    TradeDateMarket
    TrdEnv
    TrdMarket
    TrdSide
    TrdSecMarket
  }

  @invert = {
    KLType: _.invert Futu.constant.KLType
    ModifyOrderOp: _.invert Futu.constant.ModifyOrderOp
    OrderStatus: _.invert Futu.constant.OrderStatus
    OrderType: _.invert Futu.constant.OrderType
    QotMarket: _.invert Futu.constant.QotMarket
    RehabType: _.invert Futu.constant.RehabType
    RetType: _.invert Futu.constant.RetType
    SecurityFirm: _.invert Futu.constant.SecurityFirm
    SubType: _.invert Futu.constant.SubType
    TradeDateMarket: _.invert Futu.constant.TradeDateMarket
    TrdEnv: _.invert Futu.constant.TrdEnv
    TrdMarket: _.invert Futu.constant.TrdMarket
    TrdSide: _.invert Futu.constant.TrdSide
    TrdSecMarket: _.invert Futu.constant.TrdSecMarket
  }

  @optCode: (code) ->
    [input, symbol, date, side, price, ...] = code.match /([A-Z]{3})([0-9]{6})([CP])([0-9]+)/
    side = {C: 'call', P: 'put'}[side]
    {symbol, date, side, price}

  trdEnv: if process.env.TRDENV? then parseInt process.env.TRDENV else TrdEnv.TrdEnv_Simulate

  constructor: ({host, port} = {}) ->
    super()
    host ?= process.env.WSHOST || 'futu'
    port ?= 33333
    return do =>
      await new Promise (resolve, reject) =>
        @ws = new ftWebsocket()
        @ws.start host, port, false, null
        @ws.onlogin = resolve
        @ws.onPush = (cmd, data) =>
          try
            @next
              type: (_.find ftCmdID, cmd: cmd).name
              data: Futu.errHandler data
          catch err
            @error err
      @

  @errHandler: ({errCode, retMsg, retType, s2c}) ->
    if retType != Futu.constant.RetType.RetType_Succeed
      throw new Error "#{errCode}: #{retMsg}"
    else
      s2c

  subInfo: ->
    (Futu.errHandler await @ws.GetSubInfo c2s: isReqAllConn: true)
      .connSubInfoList
    
  historyKL: ({market, code, start, end, freq}) ->
    security =
      market: Futu.marketMap[market]
      code: code
    rehabType = RehabType.RehabType_Forward
    klType = Futu.klTypeMap[freq]
    beginTime = (start || moment().subtract freqDuration[freq].dataFetched)
      .format 'YYYY-MM-DD'
    endTime = (end || moment())
      .format 'YYYY-MM-DD HH:mm:ss' 
    {klList} = Futu.errHandler await @ws.RequestHistoryKL c2s: {rehabType, klType, security, beginTime, endTime}
    from klList.map (i) ->
      {timestamp, openPrice, highPrice, lowPrice, closePrice, volume, turnover, changeRate} = i
      market: market
      code: code
      freq: freq
      timestamp: timestamp
      open: openPrice
      high: highPrice
      low: lowPrice
      close: closePrice
      volume: volume.toNumber()
      turnover: turnover
      changeRate: changeRate
    
  streamKL: ({market, code, freq}) ->
    opts = {market, code, freq}
    market ?= 'hk'
    market = Futu.marketMap[market]
    await @ws.Sub
      c2s:
        securityList: [{market, code}]
        subTypeList: [Futu.freqMap[freq]]
        isSubOrUnSub: true
        isRegOrUnRegPush: true
    kl = filter ({type, data}) ->
      {klType, security} = data
      type == 'Qot_UpdateKL' and 
      market == security.market and
      code == security.code and
      Futu.klTypeMap[freq] == klType
    transform = map ({type, data}) ->
      {timestamp, openPrice, highPrice, lowPrice, closePrice, volume, turnover} = data.klList[0]
      market: opts.market
      code: code
      freq: freq
      timestamp: timestamp
      open: openPrice
      high: highPrice
      low: lowPrice
      close: closePrice
      volume: volume.toNumber()
      turnover: turnover
    @pipe kl, transform 

  orderBook: ({market, code}) ->
    opts = {market, code}
    market ?= 'hk'
    market = Futu.marketMap[market]
    await @ws.Sub
      c2s:
        securityList: [{market, code}]
        subTypeList: [Futu.constant.SubType.SubType_OrderBook]
        isSubOrUnSub: true
        isRegOrUnRegPush: true
    orderBook = filter ({type, data}) ->
      if type == 'Qot_UpdateOrderBook'
        {security} = data
        {market, code} = security
        market == security.market and
        code == security.code
      else
        false
    transform = map ({type, data}) ->
      market: opts.market
      code: code
      ask: data.orderBookAskList
      bid: data.orderBookBidList  
    @pipe orderBook, transform

  unsubAll: ->
    await @ws.Sub
      c2s:
        isSubOrUnSub: false
        isUnsubAll: true

  unsubKL: ({market, code, freq}) ->
    opts = {market, code, freq}
    market ?= 'hk'
    market = Futu.marketMap[market]
    await @ws.Sub
      c2s:
        securityList: [{market, code}]
        subTypeList: [Futu.subTypeMap[freq]]
        isSubOrUnSub: false
        isRegOrUnRegPush: true

  unsubOrderBook: ({market, code}) ->
    opts = {market, code}
    market ?= 'hk'
    market = Futu.marketMap[market]
    await @ws.Sub
      c2s:
        securityList: [{market, code}]
        subTypeList: [Futu.constant.SubType.SubType_OrderBook]
        isSubOrUnSub: false
        isRegOrUnRegPush: true
    
  marketState: ({market, code}) ->
    market ?= 'hk'
    market = Futu.marketMap[market]
    (Futu.errHandler await @ws.GetMarketState 
      c2s: securityList: [{market, code}]).marketInfoList

  securitySnapshot: ({market, code}) ->
    market ?= 'hk'
    opts =
      c2s:
        securityList: [
          {market: Futu.marketMap[market], code}
        ]
    [ret, ...] = (Futu.errHandler await @ws.GetSecuritySnapshot opts)
      .snapshotList
    val = 
      code: ret.basic.security.code
      name: ret.basic.name
      type: ret.basic.type
      isSuspend: ret.basic.isSuspend
      data: ret.equityExData
    if val.type == 8
      val.data = ret.optionExData
      val.owner = (await @securitySnapshot code: val.data.owner.code).data
    val

  optionChain: ({market, code, strikeRange, beginTime, endTime}) ->
    market ?= 'hk'
    beginTime ?= moment()
      .startOf 'month'
    endTime ?= moment()
      .endOf 'month'
    {optionChain} = Futu.errHandler await @ws.GetOptionChain
      c2s:
        owner:
          market: Futu.marketMap[market]
          code: code
        beginTime: beginTime.format 'YYYY-MM-DD'
        endTime: endTime.format 'YYYY-MM-DD'
    _.map optionChain, ({option, strikeTime, strikeTimestamp}) ->
      strikeTime: strikeTime
      option: _.filter option, ({call, put}) ->
        {basic, optionExData} = call
        {strikePrice} = optionExData
        [min, max] = strikeRange
        min <= strikePrice and strikePrice <= max

  quote: ({market, code}) ->
    market ?= 'hk'
    await @basicQuote {market, code}
    chkQuote = filter ({type, data}) ->
      type == 'Qot_UpdateBasicQot'
    chkMarket = filter ({type, data}) ->
      {security} = data.basicQotList[0]
      Futu.marketMap[market] == security.market and code == security.code
    transform = map ({type, data}) ->
      {security, updateTime, openPrice, highPrice, lowPrice, curPrice, volume, turnover} = data.basicQotList[0]
      market: security.market
      code: security.code
      timestamp: updateTime
      open: openPrice
      high: highPrice
      low: lowPrice
      close: curPrice
      volume: volume
      turnover: turnover
    @pipe chkQuote, chkMarket, transform

  basicQuote: ({market, code}) ->
    market ?= 'hk'
    m = Futu.marketMap[market]
    await @ws.Sub
      c2s:
        securityList: [{market: m, code}]
        subTypeList: [Futu.constant.SubType.SubType_Basic]
        isSubOrUnSub: true
        isRegOrUnRegPush: true
    req =
      c2s:
        securityList: [{market: m, code}]
    [ret, ...] = (Futu.errHandler await @ws.GetBasicQot req).basicQotList
    ret

  plateSet: ->
    opts =
      c2s:
        market: Futu.marketMap['hk']
        plateSetType: PlateSetType.PlateSetType_All
    Futu.errHandler (await @ws.GetPlateSet opts)

  plateSecurity: ({market, code} = {}) ->
    market ?= 'hk'
    market = Futu.marketMap[market]
    code ?= 'HSI Constituent'
    (Futu.errHandler await @ws.GetPlateSecurity
      c2s:
        plate: {market, code}).staticInfoList.map ({basic}) ->
          code: basic.security.code
          name: basic.name

  accounts: ->
    req =
      c2s:
        userID: 0
        trdCategory: TrdCategory.TrdCategory_Security
        needGeneralSecAccount: true
    (Futu.errHandler await @ws.GetAccList req)
      .accList
      .filter ({trdEnv, trdMarketAuthList}) ->
        # real account and hk in market list
        trdEnv == 1 and 1 in trdMarketAuthList
      .map (acc) =>
        acc.broker = @
        await new Account acc

  unlock: ({pwdMD5}) ->
    req =
      c2s:
        unlock: true
        securityFirm: SecurityFirm.SecurityFirm_FutuSecurities
        pwdMD5: pwdMD5
    Futu.errHandler await @ws.UnlockTrade req

export default {Futu}
export {Futu}
