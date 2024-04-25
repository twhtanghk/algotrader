import {from} from 'rxjs'
{find} = require('../rxStrategy').default 

try
  from [
    {low: 3, high: 1}
    {low: 2, high: 1}
    {low: 1, high: 2}
    {low: 2, high: 3}
    {low: 3, high: 2}
    {low: 4, high: 1}
    {low: 5, high: 5}
  ]
    .pipe find.resistance() 
    .pipe find.support() 
    .subscribe console.log
catch err
  console.error err
