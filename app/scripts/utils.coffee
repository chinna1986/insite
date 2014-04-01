getUrl = (opts) ->
  new Promise (resolve,reject) ->
    url = opts.url
    method = opts.method ? 'GET'
    data = opts.data
    req = new XMLHttpRequest()
    req.open method, url
    if method is 'POST'
      req.setRequestHeader 'Content-type', 'application/json'
    req.onload = ->
      if req.status is 200
        resolve req.response
      else
        reject Error(req.statusText)
      return
    req.onerror = ->
      reject Error('Network Error')
      return
    if data?
      req.send(data)
    else
      req.send()
    return

getJSON = (opts) ->
  opts = {url:opts,method:'GET'} if typeof opts is 'string'
  getUrl(opts).then JSON.parse

getCookies = (domain) ->
  new Promise (resolve, reject) ->
    chrome.cookies.getAll domain:domain, (cookies) ->
      if cookies?
        resolve cookies
      else
        reject "no cookies found"

setStorageSyncPromise = (data) ->
  new Promise (resolve, reject) ->
    chrome.storage.sync.set data, (err) ->
      if err?
        reject err
      else
        resolve data

getStorageSyncPromise = (key...) ->
  new Promise (resolve, reject) ->
    chrome.storage.sync.get key, (items) ->
      items ?= {}
      if Object.keys(items).length > 0
        resolve items
      else
        reject "no values found in sync storage for #{key.join(',')}"

# Get the disabledSits list and set the browserAction text
getDisabledSites = new Promise (resolve, reject) ->
  getStorageSyncPromise('disabledSites').then (result) ->
    try
      if result.disabledSites?
        result = JSON.parse(result.disabledSites)
        resolve result
      else
        resolve {}
    catch e
      resolve {}

# Get the domain of the active tab from Chrome
getCurrentUrl = new Promise (resolve, reject) ->
    chrome.tabs.query { currentWindow: true, active: true }, (tabs) ->
      try
        currentUrl = tabs[0].url
        currentUrl = currentUrl.slice currentUrl.indexOf('//')+2
        currentUrl = currentUrl.slice 0,currentUrl.indexOf('/')
        resolve currentUrl
      catch e
        reject e
        
# Grey out the icon or restore to normal
setIcon = (enabled) ->
  iconName = 'icon-' + if enabled then '' else 'bw-'
  iconDict =
    '16': "images/#{iconName}16.png"
    '19': "images/#{iconName}19.png"
    '38': "images/#{iconName}38.png"
    '128': "images/#{iconName}128.png"
  chrome.browserAction.setIcon path:"images/#{iconName}38.png"

toggleDisabledSites = (disabledSites, currentUrl) ->
  disabledSites[currentUrl] = if disabledSites[currentUrl] is false then true else false;
  setStorageSyncPromise({'disabledSites':JSON.stringify(disabledSites)}).then (result) ->
    setIcon disabledSites[currentUrl]
    toggleText disabledSites[currentUrl]
    _gaq.push(['_trackEvent', event.target.id, 'clicked', 'enabled', enabled])


hash = (name) ->
  name

  ###
  hashValue = murmurhash3_32_gc(name, 5)
  hashValue = murmurhash3_32_gc(name, 5)
  hashString = hashValue.toString
  newHash = ""
  i = 0
  while i < hashString.length
    newHash += encodingMap[hashString.slice(i, i + 2)]
    i = i + 2
  newHash
  ###

adler32 = (a, b, c, d, e, f) ->
  b = 65521
  c = 1
  d = e = 0

  while f = a.charCodeAt(e++)
    c = (c + f) % b
    d = (d + c) % b
  (d << 16) | c
  
  
encodingMap =
  1:"!"
  2:'"'
  3:"#"
  4:"$"
  5:"%"
  6:"&"
  7:"'"
  8:"("
  9:")"
  10:"*"
  11:"+"
  12:","
  13:"-"
  14:"."
  15:"/"
  16:"0"
  17:"1"
  18:"2"
  19:"3"
  20:"4"
  21:"5"
  22:"6"
  23:"7"
  24:"8"
  25:"9"
  26:":"
  27:";"
  28:"<"
  29:":"
  30:">"
  31:"?"
  32:"@"
  33:"A"
  34:"B"
  35:"C"
  36:"D"
  37:"E"
  38:"F"
  39:"G"
  40:"H"
  41:"I"
  42:"J"
  43:"K"
  44:"L"
  45:"M"
  46:"N"
  47:"O"
  48:"P"
  49:"Q"
  50:"R"
  51:"S"
  52:"T"
  53:"U"
  54:"V"
  55:"W"
  56:"X"
  57:"Y"
  58:"Z"
  59:"["
  60:"\\"
  61:"]"
  62:"^"
  63:"_"
  64:"`"
  65:"a"
  66:"b"
  67:"c"
  68:"d"
  69:"e"
  70:"f"
  71:"g"
  72:"h"
  73:"i"
  74:"j"
  75:"k"
  76:"l"
  77:"m"
  78:"n"
  79:"o"
  80:"p"
  81:"q"
  82:"r"
  83:"s"
  84:"t"
  85:"u"
  86:"v"
  87:"w"
  88:"x"
  89:"y"
  90:"z"
  91:"{"
  92:"|"
  93:"}"
  94:"~"
  95:"!!"
  96:'""'
  97:"##"
  98:"$$"
  99:"%%"
  100:"&&"
