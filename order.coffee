import {Subject} from 'rxjs'
import moment from 'moment'

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
    {@id, @code, @name, @side, @type, @status, @price, @qty, @timeInForce, createTime: moment.unix(@createTime), updateTime: moment.unix(@updateTime)}

export default {Order}
export {Order}
