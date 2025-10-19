import {createLogger, LogLevels} from 'bs-logger'

opts =
  context:
    application: 'algotrader'
  targets: "stderr:#{LogLevels[process.env.LOG_LEVEL || 'info']}%simple"

export default createLogger opts
