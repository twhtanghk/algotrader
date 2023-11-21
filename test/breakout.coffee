import {argv} from 'process'
{Futu} = require 'futu'
{history} = require '../data'
{breakout} = require '../strategy'

do ->
  try
    broker = await new Futu host: 'localhost', port: 33333
    df = await history broker, {code: argv[2]}
    ret = []
    for i in [30..(df.length - 1)]
      vol = breakout.price df[(i - 30)..i]
      if vol != 0
        ret.push [new Date(df[i].time * 1000), df[i], vol, i]
    console.log ret
  catch err
    console.error err
