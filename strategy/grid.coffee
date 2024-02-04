import {map} from 'rxjs'

# see https://www.linkedin.com/pulse/grid-trading-forex-markets-cmsprime-mz0df
# grid trading strategy
# type = range or trend
export default ({type, low, high, gridSize, stopLoss}) -> (obs) ->
  gridSize ?= 3
  stopLoss ?= 0.01
  grids = []
  typeMap =
    range: ['sell', 'buy']
    trend: ['buy', 'sell']
  for i in [low..high] by (high - low) / gridSize
    grids.push i
  obs
    .pipe map (i) ->
      {open, close} = i
      for price, index in grids
        if i['close.trend'] == 1 and open < price and price < close
          i.entryExit =
            strategy: "grid #{type}"
            side: typeMap[type][0]
            plPrice: [
              high
              close * (1 - stopLoss)
            ]
        else if i['close.trend'] == -1 and open > price and price > close
          i.entryExit =
            strategy: "grid #{type}"
            side: typeMap[type][1]
            plPrice: [
              low
              close * (1 + stopLoss)
            ]
      i
