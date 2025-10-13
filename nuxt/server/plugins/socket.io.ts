import {Futu} from 'algotrader/futu.js'
import {Server as Engine} from 'engine.io'
import {Server} from 'socket.io'
import {defineEventHandler} from 'h3'

export default defineNitroPlugin(async (app) => {
  const engine = new Engine()
  const io = new Server()
  const broker = await new Futu()
  const accounts = await broker.accounts()
  const acc = await accounts[0]

  app.broker = await new Futu()
  io.bind(engine)
  io.on('connection', (socket) => {
    console.log('connected')
    socket.on('position', async (msg) => {
      socket.emit('position', await acc.position())
    })
    socket.on('subscribe', async (msg) => {
      const {action, code, freq} = msg
      switch(action) {
        case 'quote':
          (await app.broker.quote({code}))
            .subscribe((data) => {
              socket.emit('quote', data)
            })
          socket.emit('basic', await broker.securitySnapshot({code}))
	  break
	case 'orderBook':
	  (await app.broker.streamOrder())
	    .subscribe((data) => {
              socket.emit('orderBook', data)
            })
	  break
	case 'candlestick':
	  (await app.broker.streamKL({code, freq}))
	    .subscribe((data) => {
              socket.emit('candlestick', data)
            })
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
