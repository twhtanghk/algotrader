import {scan, zip, map} from 'rxjs'

# input time ascending order of ohlc data
# i.e. [
#   {date, open, high, low, close}
#   ...
# ]
isSupport = (df, i, field='low') ->
  df[i][field] < df[i - 1][field] and 
  df[i][field] < df[i + 1][field] and
  df[i + 1][field] < df[i + 2][field] and
  df[i - 1][field] < df[i - 2][field]

# input time ascending order of ohlc data
# i.e. [
#   {date, open, high, low, close}
#   ...
# ]
isResistance = (df, i, field='high') ->
  df[i][field] > df[i - 1][field] and 
  df[i][field] > df[i + 1][field] and
  df[i + 1][field] > df[i + 2][field] and
  df[i - 1][field] > df[i - 2][field]

# mean of price range i.e. high - low
mean = (df) ->
  sum = 0
  for {high, low} in df
    sum += high - low
  sum / df.length

# check if price is too close to existng levels
meanDiff = (mean, price, levels) ->
  for [y, idx] in levels
    if Math.abs(price - y) < mean
      return false
  return true

# > See [details](https://colab.research.google.com/drive/16yWD7FJ-moOc9jjymDgQjLXvW-yPKSf3?usp=sharing#scrollTo=kbcJ8L5nN1B-)
# get list of support and resistance price levels
levels = (df) ->
  ret = []
  avg = mean df
  for i in [2..(df.length - 3)]
    if isSupport df, i
      if meanDiff avg, df[i].low, ret
        ret.push [df[i].low, i]
    if isResistance df, i
      if meanDiff avg, df[i].high, ret
        ret.push [df[i].high, i]
  ret

# mean of ohlc high and low difference
meanBar = -> (obs) ->
  reducer = (sum, x) ->
    {high, low} = x
    sum + Math.abs(high - low)
  meanBar = obs
    .pipe scan reducer, 0
    .pipe map (sum, i) ->
      sum / (i + 1)
  (zip obs, meanBar)
    .pipe map ([ohlc, meanBar]) ->
      _.extend ohlc, meanBar: [
        meanBar.toFixed 2
        (meanBar * 100 / ohlc.close).toFixed 2
      ]     

export default
  ohlc: {
    isSupport
    isResistance
    mean
    meanDiff
    levels
    meanBar
  }
