import _ from 'lodash'
import moment from 'moment'
import {Subject, concat, map} from 'rxjs'

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

class Broker extends Subject
  # rx subject to emit update of cash value
  cash: new Subject()
  # rx subject to emit update of all trades status
  trade: new Subject()
  # rx subject to emit update of position
  position: new Subject()

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
      .pipe map (x) ->
        _.extend x, timestamp: moment.unix x.timestamp
  quote: ({market, code}) ->
    throw new Error 'calling Broker virtual method quote'

export default {freqDuration, Broker}
export {freqDuration, Broker}
