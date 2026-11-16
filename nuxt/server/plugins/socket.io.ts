import {default as Promise} from 'bluebird'
import {Futu} from 'algotrader/futu.js'
import {delta} from 'algotrader/rxStrategy.js'
import {Server as Engine} from 'engine.io'
import {Server} from 'socket.io'
import {defineEventHandler} from 'h3'
import {default as root} from 'algotrader/logger.js'
import hsi from 'algotrader/hsi.json'

const logger = root.child({
  namespace: 'server/plugins/socket.io.ts',
  targets: 'stderr%json'
})

const sleep = 2000

export default defineNitroPlugin(async (app) => {
  const engine = new Engine()
  const io = new Server()
  const broker = await new Futu()
  const accounts = await broker.accounts()
  const acc = await accounts[0]
  const subscriptions = (socket) => {
    if (!socket.data.subs)
      socket.data.subs = new Map()
    return socket.data.subs
  }
  const clear = (socket) => {
    for (const subs of subscriptions(socket).values())
      for (const sub of subs)
        sub.unsubscribe?.()
    subscriptions(socket).clear()
  }
  const detail = async (socket, code, generation) => {
    const stale = () => generation != null && generation !== socket.data.generation
    if (stale())
      return
    const subs = subscriptions(socket)
    if (subs.has(code))
      return
    // subscribe for quote update
    const quoteSource = await app.broker.quote({code})
    if (stale())
      return
    const quote = quoteSource.subscribe((data) => {
      socket.emit('quote', data)
    });
    // get delta
    const trendSource = await delta({code, broker: app.broker})
    if (stale()) {
      quote.unsubscribe()
      return
    }
    const trend = trendSource.subscribe((data) => {
      logger.debug(JSON.stringify(data, null, 2))
      socket.emit('delta', data)
    })
    subs.set(code, [quote, trend])
    // get basic data including pe, pb
    const basic = await app.broker.securitySnapshot({code})
    if (stale()) {
      quote.unsubscribe()
      trend.unsubscribe()
      subs.delete(code)
      return
    }
    socket.emit('basic', basic)
  }

  app.broker = await new Futu()
  io.bind(engine)
  /*
   * position: futu position, quote, basic
   * watchlist: quote, basic
   */
  io.on('connection', (socket) => {
    console.log('connected')
    socket
      .on('position', async (msg) => {
        const ret = await acc.position()
        socket.emit('position', ret)
        for (const {code} of ret) {
          await Promise.delay(sleep)
          detail(socket, code)
        }
      })
      .on('watchlist', async (msg) => {
        const {name} = msg
        // stop streaming the previous selection and tell client to reset
        clear(socket)
        socket.data.generation = (socket.data.generation || 0) + 1
        const generation = socket.data.generation
        socket.emit('watchlist:clear')
	switch (name) {
	  case 'hsi':
            for await (const row of hsi.constituents) {
              await Promise.delay(sleep)
              if (generation !== socket.data.generation)
                break
	      detail(socket, '0' + row['stock_code'], generation)
	    }
	    break
	  default:
	    let codes = []
	    if (process.env[name]) // watchlist
              codes = process.env[name].split(',')
            else // plate or sector
              codes = (await app.broker.plateSecurity({code: name})).map(({code}) => { return code })
            for (const code of codes) {
              await Promise.delay(sleep)
              if (generation !== socket.data.generation)
                break
              detail(socket, code, generation)
            }
	    break
	}
      })
      .on('plate', async (msg) => {
        for (const sector of await app.broker.plateSet()) {
          await Promise.delay(sleep)
	  socket.emit('plate', sector)
	  detail(socket, sector.code)
	}
      })
    socket.on('disconnect', () => clear(socket))
  })
  app.router.use('/socket.io/', defineEventHandler({
    handler(event) {
      console.log(event)
      engine.handleRequest(event.node.req, event.node.res)
      event._handled = true
    },
    websocket: {
      open(peer) {
	engine.prepare(peer._internal.nodeReq)
        engine.onWebSocket(peer._internal.nodeReq, peer._internal.nodeReq.socket, peer.websocket)
      }
    }
  }))
})
