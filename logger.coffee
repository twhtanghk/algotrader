import {createLogger} from 'bs-logger'

opts =
  context:
    application: 'algotrader'
  targets: 'stderr'
if process.env.LOG_LEVEL
  Object.assign opts, level: process.env.LOG_LEVEL

export default createLogger opts
