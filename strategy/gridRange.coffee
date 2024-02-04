import {default as grid} from './grid'

export default ({low, high, gridSize, stopLoss}) ->
  grid {type: 'range', low, high, gridSize, stopLoss}
