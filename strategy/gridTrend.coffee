import {default as grid} from './grid'

export default ({low, high, gridSize, stopLoss}) ->
  grid {type: 'trend', low, high, gridSize, stopLoss}
