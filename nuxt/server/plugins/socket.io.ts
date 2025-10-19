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

export default defineNitroPlugin(async (app) => {
  const engine = new Engine()
  const io = new Server()
  const broker = await new Futu()
  const accounts = await broker.accounts()
  const acc = await accounts[0]
  const detail = async (socket, code) => {
    // subscribe for quote update
    (await app.broker.quote({code}))
      .subscribe((data) => {
        socket.emit('quote', data)
      });
    // get delta
    (await delta({code, broker: app.broker}))
      .subscribe((data) => {
	logger.debug(JSON.stringify(data, null, 2))
        socket.emit('delta', data)
      })
    // get basic data including pe, pb
    socket.emit('basic', await broker.securitySnapshot({code}))
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
          await Promise.delay(1000)
          detail(socket, code)
        }
      })
      .on('watchlist', async (msg) => {
        const {name} = msg
	switch (name) {
	  case 'hsi':
            for await (const row of hsi.constituents) {
              await Promise.delay(1000)
	      detail(socket, '0' + row['stock_code'])
	    }
	    break
	  default:
            if (process.env[name]) {
              for (const code of process.env[name].split(',')) {
                await Promise.delay(1000)
                detail(socket, code)
              }
	    }
	    break
	}
      })
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
