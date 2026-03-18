import _ from 'lodash'
import {io} from 'socket.io-client'

export const socket = io('', {transports: ['websocket']})

export const position = (items) => { return (msg) => {
  for (const stock of msg)
    items.unshift(stock)
}}

export const watchlist = (items) => { return (msg) => {
  for (const stock of msg)
    items.unshift(stock)
}}

export const plate = (items) => { return (msg) => {
  items.unshift(msg)
}}

export const quote = (items) => { return (msg) => {
  const {code, close} = msg
  _.extend(_.find(items, {code}), {
    price: close
  })
}}

export const delta = (items) => { return (msg) => {
  const {code, close, delta} = msg
  const stdev = msg['close.stdev']
  const mean = msg['close.mean']
  const found = _.find(items, {code})
  msg.delta = (close - mean) / stdev
  if (found)
    _.extend(found, _.pick(msg, 'delta'))
  else
    items.unshift(msg) 
}}

export const basic = (items) => { return (msg) => {
  const {code, type, data, owner} = msg
  let ret = _.pick(data, 'peRate', 'pbRate', 'dividendLFYRatio')
  if (type == 8) {
    ret = _.pick(owner, 'peRate', 'pbRate', 'dividendLFYRatio')
    _.extend(owner, data.owner)
  }
  _.extend(msg, {pe: ret.peRate, pb: ret.pbRate, div: ret.dividendLFYRatio})

  const found = _.find(items, {code})
  if (found)
    _.extend(found, msg, {owner})
  else
    items.unshift(msg)
}}
