# input time ascending order of ohlc data
# i.e. [
#   {date, open, high, low, close}
#   ...
# ]
isSupport = (df, i) ->
  df[i].low < df[i - 1].low and 
  df[i].low < df[i + 1].low and
  df[i + 1].low < df[i + 2].low and
  df[i - 1].low < df[i - 2].low

# input time ascending order of ohlc data
# i.e. [
#   {date, open, high, low, close}
#   ...
# ]
isResistance = (df, i) ->
  df[i].high > df[i - 1].high and 
  df[i].high > df[i + 1].high and
  df[i + 1].high > df[i + 2].high and
  df[i - 1].high > df[i - 2].high

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

# https://colab.research.google.com/drive/16yWD7FJ-moOc9jjymDgQjLXvW-yPKSf3?usp=sharing#scrollTo=kbcJ8L5nN1B-
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

module.exports = 
  ohlc: {
    isSupport
    isResistance
    mean
    meanDiff
    levels
  }
