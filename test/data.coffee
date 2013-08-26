module "Data"

## HELPER FUNCTIONS
parse = (e) -> polyjs.debug.parser.getExpression(e).expr
transformData = (data, spec) ->
  data.getData (err, x)-> if err? then console.err err else x
  polyjs.data.frontendProcess spec, data, (err, x) -> if err? then console.err err else x
fill = (dataSpec) ->
  dataSpec.filter ?= []
  for f in dataSpec.filter
    f.expr = parse(f.expr)
  dataSpec.sort ?= []
  for val in dataSpec.sort
    val.var = parse(val.var).name
    val.sort = parse val.sort
  dataSpec.select ?= []
  dataSpec.select = (parse str for str in dataSpec.select)
  dataSpec.trans ?= []
  dataSpec.trans = (parse(a) for a in dataSpec.trans)
  dataSpec.stats ?= {}
  dataSpec.stats.stats ?= []
  for stat in dataSpec.stats.stats
    stat.args = (parse(a) for a in stat.args)
    stat.expr = parse stat.expr
  dataSpec.stats.groups ?= []
  dataSpec.stats.groups = (parse(a) for a in dataSpec.stats.groups)
  return dataSpec

test "smoke test", ->
  jsondata= [
    {x: 2, y: 4},
    {x: 2, y: 4}
  ]
  data = polyjs.data (data: jsondata)
  deepEqual data.raw, jsondata

test "transforms -- numeric binning", ->
  data = polyjs.data
    data: [
      {x: 12, y: 42},
      {x: 33, y: 56},
    ]
  trans = transformData data, fill(trans:["bin(x, 10)", "bin(y, 5)"])

  deepEqual trans.data, [
      {x: 12, y: 42, 'bin([x],10)': 10, 'bin([y],5)': 40},
      {x: 33, y: 56, 'bin([x],10)': 30, 'bin([y],5)': 55},
    ]

  data = polyjs.data
    data: [
      {x: 1.2, y: 1},
      {x: 3.3, y: 2},
      {x: 3.3, y: 3},
    ]
  trans = transformData data, fill(trans:["bin(x,1)", "lag(y,1)"])
  deepEqual trans.data, [
      {x: 1.2, y: 1, 'bin([x],1)': 1, 'lag([y],1)': undefined},
      {x: 3.3, y: 2, 'bin([x],1)': 3, 'lag([y],1)': 1},
      {x: 3.3, y: 3, 'bin([x],1)': 3, 'lag([y],1)': 2},
    ]

  data = polyjs.data
    data: [
      {x: 1.2, y: 1},
      {x: 3.3, y: 2},
      {x: 3.3, y: 3},
    ]
  trans = transformData data, fill(trans:["bin(x,1)", "lag(y,2)"])
  deepEqual trans.data, [
      {x: 1.2, y: 1, 'bin([x],1)': 1, 'lag([y],2)': undefined},
      {x: 3.3, y: 2, 'bin([x],1)': 3, 'lag([y],2)': undefined},
      {x: 3.3, y: 3, 'bin([x],1)': 3, 'lag([y],2)': 1},
    ]

test "transforms -- dates binning", ->

test "filtering", ->
  data = polyjs.data data: [
    {x: 1.2, y: 1},
    {x: 3.3, y: 2},
    {x: 3.4, y: 3},
  ]
  trans = transformData data,
    trans: [
      { key: 'x', trans: "bin", binwidth: 1, name: "bin(x, 1)" }
      { key: 'y', trans: "lag", lag: 1, name: "lag(y, 1)" }
    ]
    filter:
      x:
        lt: 3
  deepEqual trans.data, [
      {x: 1.2, y: 1, 'bin(x, 1)': 1, 'lag(y, 1)': undefined},
    ]

  trans = transformData data,
    trans: [
      { key: 'x', trans: "bin", binwidth: 1, name: "bin(x, 1)"}
      { key: 'y', trans: "lag", lag: 1, name: "lag(y, 1)"}
    ]
    filter:
      x:
        lt: 3.35
        gt: 1.2
  deepEqual trans.data, [
      {x: 3.3, y: 2, 'bin(x, 1)': 3, 'lag(y, 1)': 1},
    ]

  trans = transformData data,
    trans: [
      { key: 'x', trans: "bin", binwidth: 1, name: "bin(x, 1)"}
      { key: 'y', trans: "lag", lag: 1, name: "lag(y, 1)"}
    ]
    filter:
      x:
        le: 3.35, ge: 1.2
      y:
        lt: 100
  deepEqual trans.data, [
      {x: 1.2, y: 1, 'bin(x, 1)': 1, 'lag(y, 1)': undefined},
      {x: 3.3, y: 2, 'bin(x, 1)': 3, 'lag(y, 1)': 1},
    ]

  data = polyjs.data data:[
    {x: 1.2, y: 1, z: 'A'},
    {x: 3.3, y: 2, z: 'B'},
    {x: 3.4, y: 3, z: 'B'},
  ]
  trans = transformData data,
    filter: z: in: 'B'
  deepEqual trans.data, [
      {x: 3.3, y: 2, z:'B'}
      {x: 3.4, y: 3, z:'B'}
    ]

  trans = transformData data,
    filter: z: in: ['A', 'B']
  deepEqual trans.data, [
      {x: 1.2, y: 1, z:'A'}
      {x: 3.3, y: 2, z:'B'}
      {x: 3.4, y: 3, z:'B'}
    ]

test "statistics - count", ->
  data = polyjs.data data:[
    {x: 'A', y: 1, z:1}
    {x: 'A', y: 1, z:2}
    {x: 'A', y: 1, z:1}
    {x: 'A', y: 1, z:2}
    {x: 'A', y: 1, z:1}
    {x: 'A', y: 1, z:2}
    {x: 'B', y: 1, z:1}
    {x: 'B', y: 1, z:2}
    {x: 'B', y: 1, z:1}
    {x: 'B', y: 1, z:2}
    {x: 'B', y: undefined, z:1}
    {x: 'B', y: null, z:2}
  ]
  trans = transformData data,
    stats:
      stats: [
        key: 'y', stat: 'count', name: 'count(y)'
      ]
      groups: ['x']
  deepEqual trans.data, [
      {x: 'A', 'count(y)': 6}
      {x: 'B', 'count(y)': 4}
    ]

  trans = transformData data,
    stats:
      stats: [
        key: 'y', stat: 'count', name: 'count(y)'
      ]
      groups: ['x', 'z']
  deepEqual trans.data, [
      {x: 'A', z:1, 'count(y)': 3}
      {x: 'A', z:2, 'count(y)': 3}
      {x: 'B', z:1, 'count(y)': 2}
      {x: 'B', z:2, 'count(y)': 2}
    ]

  trans = transformData data,
    stats:
      stats: [
        key: 'y', stat: 'unique', name: 'unique(y)'
      ],
      groups: ['x', 'z']
  deepEqual trans.data, [
      {x: 'A', z:1, 'unique(y)': 1}
      {x: 'A', z:2, 'unique(y)': 1}
      {x: 'B', z:1, 'unique(y)': 1}
      {x: 'B', z:2, 'unique(y)': 1}
    ]

  trans = transformData data,
    stats:
      stats: [
        {key: 'y', stat: 'count', name: 'count(y)'}
        {key: 'y', stat: 'unique', name: 'unique(y)'}
      ]
      groups: ['x', 'z']
  deepEqual trans.data, [
      {x: 'A', z:1, 'count(y)':3, 'unique(y)': 1}
      {x: 'A', z:2, 'count(y)':3, 'unique(y)': 1}
      {x: 'B', z:1, 'count(y)':2, 'unique(y)': 1}
      {x: 'B', z:2, 'count(y)':2, 'unique(y)': 1}
    ]

  data = polyjs.data data:[
    {x: 'A', y: 1, z:1}
    {x: 'A', y: 2, z:2}
    {x: 'A', y: 3, z:1}
    {x: 'A', y: 4, z:2}
    {x: 'A', y: 5, z:1}
    {x: 'B', y: 1, z:1}
    {x: 'B', y: 2, z:2}
    {x: 'B', y: 3, z:1}
    {x: 'B', y: 4, z:2}
  ]
  trans = transformData data,
    stats:
      stats: [
        {key: 'y', stat: 'min', name: 'min(y)'}
        {key: 'y', stat: 'max', name: 'max(y)'}
        {key: 'y', stat: 'median', name: 'median(y)'}
      ]
      groups: ['x']
  deepEqual trans.data, [
      {x: 'A', 'min(y)': 1, 'max(y)': 5, 'median(y)': 3}
      {x: 'B', 'min(y)': 1, 'max(y)': 4, 'median(y)': 2.5}
    ]

  data = polyjs.data data:[
    {x: 'A', y: 15, z:1}
    {x: 'A', y: 3, z:2}
    {x: 'A', y: 4, z:1}
    {x: 'A', y: 1, z:2}
    {x: 'A', y: 2, z:1}
    {x: 'A', y: 6, z:2}
    {x: 'A', y: 5, z:1}
    {x: 'B', y: 1, z:1}
    {x: 'B', y: 2, z:2}
    {x: 'B', y: 3, z:1}
    {x: 'B', y: 4, z:2}
  ]
  trans = transformData data,
    stats:
      stats: [
        key: 'y', stat: 'box', name: 'box(y)'
      ]
      groups: ['x']
  deepEqual trans.data, [
      {x: 'A', 'box(y)': {q1:1, q2:2.5, q3:4, q4:5.5, q5:6, outliers:[15]}}
      {x: 'B', 'box(y)': {outliers:[1,2,3,4]}}
    ]

test "meta sorting", ->
  data = polyjs.data data:[
    {x: 'A', y: 3}
    {x: 'B', y: 1}
    {x: 'C', y: 2}
  ]
  trans = transformData data,
    sort:
      x: {sort: 'y', asc: true}
  deepEqual _.pluck(trans.data, 'x'), ['B','C','A']

  trans = transformData data,
    sort:
      x: {sort: 'y', asc: true, limit: 2}
  deepEqual _.pluck(trans.data, 'x'), ['B','C']

  trans = transformData data,
    sort:
      x: {sort: 'y', asc: false, limit: 1}
  deepEqual _.pluck(trans.data, 'x'), ['A']

  data = polyjs.data data:[
    {x: 'A', y: 3}
    {x: 'B', y: 1}
    {x: 'C', y: 2}
    {x: 'C', y: 2}
  ]
  trans = transformData data,
    sort: x:
      sort: 'sum(y)',
      stat: {key: 'y', stat:'sum', name:'sum(y)'},
      asc: false,
      limit: 1
  deepEqual _.pluck(trans.data, 'x'), ['C', 'C']

  data = polyjs.data data:[
    {x: 'A', y: 3}
    {x: 'B', y: 1}
    {x: 'C', y: 2}
    {x: 'C', y: 2}
  ]
  trans = transformData data,
    sort: x:
      sort: 'sum(y)',
      stat: {key: 'y', stat:'sum', name:'sum(y)'},
      asc: true,
      limit: 1
  deepEqual _.pluck(trans.data, 'x'), ['B']

