#--------
# Globals
#--------
deltaUpdateInterval = 1000*10            # How often to perform deltas (in milliseconds)
completeUpdateInterval = 3*24*60*60*1000 # How often to perform complete updates (in milliseconds)
wordBlacklist = {'Read':null,'April':null,'New':null,'Science':null,'With':null,'Main':null,'Random':null,'Jobs':null,'Science':null,'Protest':null,'Next':null}
rePunctuation = /[?:!.,;]*$/g
reLetters = /[A-Za-z]/
lastUpdate = null
lastCompleteUpdate = null
fs = []
gazetteer = {}
map = {}
type = null
counter = null
prefix = null
maxId = -1
includeBiography = false

# Query Locations
baseUrl = 'http://query.glgroup.com'
dataQueries =
  'completeQueries':
    'status': baseUrl+'/gotNames/dw/getStatus.mysql.mustache'
    'cm':     baseUrl+'/cache4h/gotNames/dw/getCmAll.mysql.mustache'
    'lead':   baseUrl+'/cache4h/gotNames/dw/getLeadAll.mysql.mustache'
    'firm':   baseUrl+'/cache4h/gotNames/dw/getFirmAll.mysql.mustache'
  'deltaQueries':
    'status': baseUrl+'/gotNames/glglive/getStatus.mustache'
    'cm':     baseUrl+'/gotNames/glglive/getCmDelta.mustache'
    'lead':   baseUrl+'/gotNames/glglive/getLeadDelta.mustache'
    'firm':   baseUrl+'/gotNames/glglive/getCmDelta.mustache'

#------------------
# Utility Functions
#------------------
getMaxRecords = () ->
  250000

logTiming = (message) ->
  d = new Date()
  console.log "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}:#{d.getMilliseconds()} - #{type}_#{counter} - #{message}"

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

cleanName = (token) ->
  token ?= ''
  if type is 'cm' or type is 'lead'
    diacritics.remove(token).trim().toLowerCase().replace(rePunctuation, "")
  else
    token.toLowerCase()

encodeDate = (a) ->
  encodeURIComponent(a.getUTCMonth()+1 + "/" + a.getUTCDate() + "/" + a.getUTCFullYear() + " " + a.getUTCHours() + ":" + a.getUTCMinutes() + ":" + a.getUTCSeconds())

getDateFileName = (a) ->
  a.getFullYear()+"_"+(a.getMonth()+1)+"_"+a.getDate()+"_"+a.getHours()+"_"+a.getMinutes()+"_"+a.getSeconds()

#------------
# File System
#------------
readDeltaFiles = () ->
  dirReader = fs.root.createReader()
  deltaPrefix = prefix+'delta'
  deltaFileNames = []
  deltas = []

  # Get Delta Filenames and Sort
  results = dirReader.readEntries()
  for fileEntry in results
    if fileEntry.name.substr(0,prefix.length) is prefix
      deltaFileNames.push fileEntry.name
  deltaFileNames = deltaFileNames.sort()

  # Load and Parse Delta Filenames
  for fileName in deltaFileNames
    fileEntry = fs.root.getFile fileName, {create:false}
    reader = new FileReaderSync()
    text = reader.readAsText fileEntry.file()
    deltas.push JSON.parse(text)
  return deltas

removeFile = (searchFileName) ->
  try
    dirReader = fs.root.createReader()
    results = dirReader.readEntries()
    for fileEntry in results
      if fileEntry.name is searchFileName
        logTiming 'removed '+fileEntry.name
        fileEntry.remove()
        return true
    return false
  catch e
    return false

readFile = (searchFileName, isJson) ->
  try
    dirReader = fs.root.createReader()
    results = dirReader.readEntries()
    for fileEntry in results
      if fileEntry.name is searchFileName
        reader = new FileReaderSync()
        text = reader.readAsText fileEntry.file()
        if isJson
          return JSON.parse text
        else
          return text
  catch e
    if isJson
      return {}
    else
      return null

writeLookups = (fileDatum) ->
  # Write the Files Passed as an Argument to this Function
  for fileName, fileData of fileDatum
    removed = removeFile prefix+fileName # Remove the existing file, if any
    fileEntry = fs.root.getFile prefix+fileName, {create:true}
    switch fileData.constructor.name
      when 'Object' then dataBlob = new Blob([JSON.stringify(fileData)], {type: 'text/plain'})
      when 'Date' then dataBlob = new Blob([fileData.toUTCString()], {type: 'text/plain'})
      else dataBlob = new Blob([fileData], {type: 'text/plain'})
    fileEntry.createWriter().write dataBlob
    logTiming fileName + ' written'

# Check for Legacy Files and Erase
removeLegacyFiles = () ->
  legacyFileNames = ['cmMap','cmGazetteer','leadMap','leadGazetteer']
  for legacyFileName in legacyFileNames
    removeFile legacyFileName

#----------------
# Data Management
#----------------
updateLookups = () ->
  updateLookupsPromise().then () ->
    #logTiming 'querying deltas in ' + deltaUpdateInterval/1000 + ' seconds'
    #setTimeout updateLookups, deltaUpdateInterval

needsFullUpdate = (serverLastCompleteUpdate) ->
  if lastCompleteUpdate is null
    return true
  else if typeof lastCompleteUpdate is 'undefined'
    return true
  else if Object.keys(map).length is 0
    return true
  else if maxId is -1
    return true
  else if (serverLastCompleteUpdate - lastCompleteUpdate) > completeUpdateInterval and (lastCompleteUpdate - serverLastCompleteUpdate) isnt 0
    return true
  else
    return false

updateLookupsPromise = (startId) ->
  new Promise (resolve, reject) ->
    logTiming 'lastUpdate '+lastUpdate
    logTiming 'lastCompleteUpdate '+lastCompleteUpdate

    # Full Update
    getJSON(dataQueries.completeQueries.status).then (data) ->
      serverLastCompleteUpdate = new Date(data[1][0].statusDate)
      if needsFullUpdate(serverLastCompleteUpdate)

        # Erase existing gazetter and map
        gazetteer = {}
        map = {}

        # Download the Update
        logTiming 'downloading full update'
        query = dataQueries.completeQueries[type]+'?startId='+startId+'&maxRecords='+getMaxRecords()
        query += '&biography=true' if includeBiography is true
        getJSON(query).then (data) ->

          # Insert Data
          data = processMysqlResponse data
          clearLookups()
          addLookups(data)

          # Write Data
          logTiming 'lookups added, writing lookups'
          fileDatum =
            'map':                map,
            'gazetteer':          gazetteer,
            'lastUpdate':         serverLastCompleteUpdate,
            'lastCompleteUpdate': serverLastCompleteUpdate,
            'maxId':              maxId
          writeLookups fileDatum
          lastCompleteUpdate = serverLastCompleteUpdate
          resolve 'lookups updated'
        .then undefined, (error) ->
          reject error
      else
        resolve 'unable to process data download'
    .then undefined, (error) ->
      resolve 'unable to get server last complete update time'

    # Delta Update
    ###
    else
      if !lastUpdate
        lastUpdate = lastCompleteUpdate
      getJSON(dataQueries.deltaQueries.status).then (statusData) ->
        tentativeLastUpdate = new Date(statusData[0].currentTimestamp)
        getJSON(dataQueries.deltaQueries[type]+'?lastUpdated='+encodeDate(lastUpdate)).then (data) ->
          data = addLookups data
          logTiming 'delta lookups added, writing lookups'
          deltaFilename = "delta_"+getDateFileName(tentativeLastUpdate)
          fileDatum = {}
          fileDatum[deltaFilename] = data
          fileDatum['lastUpdate'] = tentativeLastUpdate
          writeLookups fileDatum
          lastUpdate = tentativeLastUpdate
          resolve 'all lookups imported'
        .then undefined, (error) ->
          reject error
      .then undefined, (error) ->
          reject errors
    ###
clearLookups = (data) ->
  map = {}
  gazetteer = {}

processMysqlResponse = (data) ->
  for datum in data
    if Array.isArray(datum)
      return datum

addLookups = (data) ->
  if data.length > 0

    # Detect Which Key is In Use
    keyProperties = ['l','c','f']
    for keyProperty in keyProperties
      if data[0][keyProperty]
        key = keyProperty

    # Add Properties
    for item, i in data
      addItem(item, item[key])

addItem = (item, key, mapFileWriter) ->

  # Store Max Key
  if key > maxId
    maxId = key

  # Store Person Details
  map[key] = item

  # Index First and Last Name
  name = cleanName item.n
  gazetteer[name] ?= []
  gazetteer[name].push key

  # Index First, Last, and Middle Name
  if item.m != ""
    namem = cleanName(item.n+" "+item.m)
    gazetteer[namem] ?= []
    gazetteer[namem].push key

loadLookups = (passedType, workerArguments, passedCounter) ->
  new Promise (resolve, reject) ->

    # Import diacritics
    importScripts('vendor-background.js') # Import Diacritics

    # Set Globals
    startId = workerArguments.startId
    type = passedType
    counter = passedCounter
    includeBiography = workerArguments.includeBiography
    prefix = type+'_'+counter+'_'

    # Initialize File System with a 1 GB Limit and Remove Legacy Files
    fs = webkitRequestFileSystemSync PERSISTENT, 1*1024*1024*1024
    removeLegacyFiles()

    # Get Update Times
    storedLastUpdate = readFile(prefix+'lastUpdate')
    storedLastCompleteUpdate = readFile(prefix+'lastCompleteUpdate')
    lastUpdate = new Date(storedLastUpdate) if storedLastUpdate
    lastCompleteUpdate = new Date(storedLastCompleteUpdate) if storedLastCompleteUpdate
    tempMaxId = readFile(prefix+'maxId')
    maxId = parseInt(tempMaxId) if tempMaxId?

    # Get Data
    map = readFile(prefix+'map',true)
    gazetteer = readFile(prefix+'gazetteer',true)

    ###
    # Apply Deltas
    deltaDatum = readDeltaFiles()
    for deltaData in deltaDatum
      addLookups(deltaData)
    ###

    # Update Lookups
    updateLookupsPromise(startId).then (maxId) ->
      resolve type
    , (error) ->
      console.log error
      reject error

#---------
# Listener
#---------

self.addEventListener "message", ((e) ->

  # Extract Arguments
  demand = e.data.demand
  workerArguments = e.data.workerArguments

  # Decide Which Course of Action to Take
  switch demand
    when 'load cms' then loadLookups('cm', workerArguments, e.data.counter).then () ->
      self.postMessage generateReturnMessage(workerArguments, demand)
    when 'load leads' then loadLookups('lead', workerArguments, e.data.counter).then () ->
      self.postMessage generateReturnMessage(workerArguments, demand)
    when 'load firms' then loadLookups('firm', workerArguments, e.data.counter).then () ->
      self.postMessage generateReturnMessage(workerArguments, demand)
    when 'find names'
      workerArguments.matches = findAllNames(workerArguments.nodeMetaData, workerArguments.nodeContentData)
      self.postMessage({'demand': demand, 'workerArguments': workerArguments})

), false

generateReturnMessage = (workerArguments, demand) ->
  workerArguments.startId = maxId+1
  logTiming "online with " + Object.keys(map).length + " records"
  if getMaxRecords() <= Object.keys(map).length
    message = {'demand': demand, 'workerArguments': workerArguments, 'officiallyOutOfMemory':true}
  else
    #setTimeout updateLookups, deltaUpdateInterval # If this is the last worker in the series, set a delta check
    #logTiming 'querying deltas in ' + deltaUpdateInterval/1000 + ' seconds'
    message = {'demand': demand, 'workerArguments': workerArguments}

#--------
# Matcher
#--------
getResponse = (query) ->
  if type is 'cm' or type is 'lead'
    normalizedQuery = diacritics.remove(query).toLowerCase()
  else
    normalizedQuery = query.trim()

  response = {}
  matchingIds = gazetteer[normalizedQuery]
  if matchingIds?
    response.count = matchingIds.length
    response.results = getResults matchingIds.slice(0,5)
    response[type] = matchingIds.slice(5)
  response

getResults = (matchingIds) ->
  results = []
  for matchingId in matchingIds
    results.push map[matchingId]
  results

findAllNames = (nodeData, nodeContentData) ->
  matches = {}
  for row, nodeIndex in nodeData
    if type is 'cm' or type is 'lead'
      match = findNames(row.tags, row.words)
    else
      textContent = nodeContentData[nodeIndex].textContent
      match = findFirmNames(textContent)
    if match?
      matches[nodeIndex] = match
  return matches

getWordDeck = (words) ->
  return words.slice 0, 6

getFollowingWord = (words, wordDeck) ->
  if words.length > wordDeck.length
    return words[wordDeck.length]
  else
    return null

findFirmNames = (textContent) ->
  words = textContent.split ' '
  matchingGroups = []

  # Iterate over each word, creating a word deck, and checking this deck against the map object
  previousWord = null
  nextWord = null
  while words.length > 0
    # Create a list of on-deck words and iterate backwards
    wordDeck = getWordDeck words
    nextWord = getFollowingWord words, wordDeck
    while wordDeck.length > 0
      matching = null
      if recognizeFirmPattern previousWord, nextWord, wordDeck
        candidateString = wordDeck.join(' ').toLowerCase()
        matching = getResponse candidateString
        if matching.count > 0
          matching.nameString = words.slice(0,wordDeck.length).join(' ')
          matchingGroups.push matching
          words = words.slice wordDeck.length
          nextWord = wordDeck.pop()
          break
        else
          nextWord = wordDeck.pop()
      else
        nextWord = wordDeck.pop()

    # If no match found remove the first word and try again
    previousWord = words.shift()

  if matchingGroups.length > 0
    results = {'matchingGroups':matchingGroups}

recognizeFirmPattern = (previousWord, nextWord, words) ->
  if words.length > 0
    wfc = words[0].substr(0,1).match(reLetters)

    # If the first character of the shifted (previous) word and the current word are capitalized
    if previousWord?
      pfc = previousWord.substr(0,1).match(reLetters)
      if pfc and pfc[0].toUpperCase() is pfc[0] and wfc and wfc[0].toUpperCase() is wfc[0]
        return false

    # If the first character of the shifted (previous) word and the current word are capitalized
    if nextWord?
      nfc = nextWord.substr(0,1).match(reLetters)
      if nfc and nfc[0].toUpperCase() is nfc[0] and wfc and wfc[0].toUpperCase() is wfc[0]
        return false

    # Check if the first word is entirely lower case
    if words[0] is words[0].toLowerCase()
      return false
    # If only one word, make sure that the word has more than 4 characters
    else if words.length is 1 and words[0].length <= 3 and not (words[0].toUpperCase() is words[0])
      return false
    else if nextWord is 'of' or previousWord is 'of'
      return false
    else if (words.length is 1) and (words[0] of wordBlacklist)
      return false
    else
      return true
  else
      return false

findNames = (tags, words) ->
  matchingGroups = []
  while words.length > 0
    # Check for a Match in Each Filter
    for filter in filters
      if recognizePattern(tags, words, filter)
        candidateString = generateCandidateString(words, filter)
        matching = getResponse candidateString
        if matching.count > 0
          matching.nameString = generatePresentationString(words, filter)
          matchingGroups.push matching
          tags.splice 0,filter.trailingSpaces.length
          words.splice 0,filter.trailingSpaces.length
          break
    words.shift()
    tags.shift()
  if matchingGroups.length > 0
    results = {'matchingGroups':matchingGroups}

recognizePattern = (tags, words, filter) ->
  if words.length >= filter.trailingSpaces.length
    patternMatch = true
    for wordPatterns, i in filter.pattern
      for patternEntry, patternValue of wordPatterns
        roundMatch = false
        if patternEntry == 'eqLength'                               # Length
          if words[i].length == patternValue then roundMatch = true
        else if patternEntry == 'gtLength'                          # Greater Than Length
          if words[i].length > patternValue then roundMatch = true
        else if patternEntry == 'value'                             # Value
          if words[i] is patternValue then roundMatch = true
        if patternEntry == 'types'                                  # Type
          for patternType in patternValue
            if tags[i] is patternType then roundMatch = true
        if roundMatch isnt true
          break
      if roundMatch isnt true
        patternMatch = roundMatch
        break
  patternMatch

generateCandidateString = (words, filter) ->
  candidateString = []
  for position, i in filter.positions
    if position != null
      candidateString[position] = words[i]
  candidateString.join ' '

generatePresentationString = (words, filter) ->
  candidateString = []
  for trailingSpaceEntry, i in filter.trailingSpaces
    candidateString += words[i]
    if trailingSpaceEntry == true
      candidateString += ' '
  candidateString

# Define Filters
filters = [
  #0 - First Middle Last
  positions:[0,2,1],
  trailingSpaces:[true,true,false],
  pattern:[
    {gtLength:1, types:['nnp','nnps']},
    {types:['nnp','nnps']},
    {gtLength:1, types:['nnp','nnps']}
  ]
,
  #1 - First M. Last
  positions:[0,2,null,1],
  trailingSpaces:[true,false,true,false],
  pattern:[
    {types:['nnp','nnps'], gtLength:1},
    {eqLength:1},
    {value:'.'},
    {types:['nnp','nnps'], gtLength:1}
  ]
,
  #2 -First Last
  positions:[0,1],
  trailingSpaces:[true,false],
  pattern:[
    {gtLength:1, types:['nnp','nnps']},
    {gtLength:1, types:['nnp','nnps']}
  ]
,
  #3 - Last, First Middle
  positions:[1,null,0,2],
  trailingSpaces:[false,true,true,false],
  pattern:[
    {gtLength:1, types:['nnp','nnps']},
    {gtLength:1, value:','},
    {types:['nnp','nnps']},
    {types:['nnp','nnps']}
  ]
,
  #4 - Last, First M.
  positions:[1,null,0,2,null],
  trailingSpaces:[false,true,true,false,true],
  pattern:[
    {gtLength:1, types:['nnp','nnps']},
    {value:','},
    {gtLength:1, types:['nnp','nnps']},
    {eqLength:1},
    {value:'.'}
  ]
,
  #5 - Last, First
  positions:[1,null,0],
  trailingSpaces:[false,true,false],
  pattern:[
    {gtLength:1, types:['nnp','nnps']},
    {value:','},
    {gtLength:1, types:['nnp','nnps']}
  ]
]
