'use strict'
chrome.tabs.onActivated.addListener (tabId, windowId) ->
  #chrome.tabs.get tabId, (tab) ->
  Promise.all([getDisabledSites,getCurrentUrl]).then (results) ->
    disabledSites = results[0]
    currentUrl = results[1]
    toggleText disabledSites[currentUrl]

logTiming = (message) ->
  d = new Date()
  console.log "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}:#{d.getMilliseconds()} - #{message}"

reSpecialChars = /([.?*+^$[\]\\(){}|-])/g
escapeRe = (str) ->
  (str+'').replace(reSpecialChars, "\\$1")

# Gobals
constellation =
  lead: []
  cm:   []

workerManager = []
openConsults = []
vegaUser = {}
rePunctuation = /[?:!.,;]*$/g

loadLookups = (options) ->

  workerArguments =
    'startId': 0
    'includeBiography': options.includeBiography
  workerConfig = [{
    workerUrl: "scripts/worker.js"
    initialDemand: "load leads"
    budgetedWorkers: 10
    officiallyOutOfMemory: "officiallyOutOfMemory"
    workerArguments: workerArguments
  },{
    workerUrl: "scripts/worker.js"
    initialDemand: "load cms"
    budgetedWorkers: 10
    officiallyOutOfMemory: "officiallyOutOfMemory"
    workerArguments: workerArguments
  }]
  workerManager = new malory(workerConfig)

getVegaUserName = () ->
  new Promise (resolve,reject) ->
    getCookies('glgroup.com')
    .then (cookies) ->
      vegaCookie = (cookie for cookie in cookies when cookie.name is 'glgadmin')[0]
      if vegaCookie?
        resolve /username=glgroup(\\|%5C)(\w+)/i.exec(vegaCookie.value)[2]
      else
        reject 'no vega user name found' 
    .then undefined,reject

getVegaUserUrl = (userName) ->
  "https://query.glgroup.com/person/getPersonByLoginName.mustache?Login=glgroup%5c#{userName}"

getVegaIdsPromise = () ->
  new Promise (resolve, reject) ->
    getStorageSyncPromise('vegaPersonId','vegaUserId')
    .then(resolve)
    .then(undefined,getVegaUserName)
    .then(getVegaUserUrl)
    .then(getJSON)
    .then (response) ->
      person = response[0]
      setStorageSyncPromise({vegaUserId:person.USER_ID,vegaPersonId:person.PERSON_ID})
    .then (vegaUser) ->
      resolve vegaUser
    .then undefined, reject

getOpenConsults = () ->
  getVegaIdsPromise().then(
   (user) -> vegaUser = user
  ).then( (user) ->
    getJSON("https://query.glgroup.com/consultations/quickLeadLoadConsultations.mustache?personId=#{user.vegaPersonId}&daysAgo=60")
  ).then(
    (response) -> openConsults = response
  )

coalesceMatches = (responses) ->
  coalescedMatchingNodes = {}
  for response in responses
    matchingNodes = response.workerArguments.matches
    for nodeIndex, nodeData of matchingNodes
      if !coalescedMatchingNodes[nodeIndex]?
        coalescedMatchingNodes[nodeIndex] = nodeData
      else
        coalescedMatchingCmGroup = coalescedMatchingNodes[nodeIndex].matchingCmGroups[0]
        for matchingCmGroup in nodeData.matchingCmGroups

          # Add open consults and vega user
          coalescedMatchingCmGroup.openConsults =  openConsults
          coalescedMatchingCmGroup.vegaUser =  vegaUser

          # TODO: Handle text content/html

          # Count
          coalescedMatchingCmGroup.count += matchingCmGroup.count

          # More Link
          if matchingCmGroup.cm
            for cmId in matchingCmGroup.cm
              if !coalescedMatchingCmGroup.cm
                coalescedMatchingCmGroup.cm = []
              coalescedMatchingCmGroup.cm.push cmId

          # Merge Results
          for key, result of matchingCmGroup.results
            coalescedMatchingCmGroup.results.push result

  for key, coalescedMatchingNode of coalescedMatchingNodes
    coalescedMatchingCmGroup = coalescedMatchingNode.matchingCmGroups[0]
    # Delete Displayed Leads if We Have More Than 5 Results
    if coalescedMatchingCmGroup.results.length > 5
      i = coalescedMatchingCmGroup.results.length-1
      while i >= 0 and coalescedMatchingCmGroup.results.length > 5
        coalescedResult = coalescedMatchingCmGroup.results[i]
        if coalescedResult.l?
          coalescedMatchingCmGroup.results.count--
          coalescedMatchingCmGroup.results.splice i,1
        i--

    # Shunt Displayed CMs to Mosaic Link
    if coalescedMatchingCmGroup.results.length > 5
      i = coalescedMatchingCmGroup.results.length-1
      while i >= 0 and coalescedMatchingCmGroup.results.length > 5
        coalescedResult = coalescedMatchingCmGroup.results[i]
        if !coalescedMatchingCmGroup.cm
          coalescedMatchingCmGroup.cm = []
        coalescedMatchingCmGroup.cm.push coalescedResult.c
        coalescedMatchingCmGroup.results.splice i,1
        i--
  coalescedMatchingNodes

chrome.runtime.onMessage.addListener (message, sender, sendResponse) ->
  response = null
  switch message.method
    when "pushAnalytics"
      _gaq.push(message.message)
      sendResponse {}
    when "search-new"
      nodeMetadata = message.nodeMetadata

      workerManager.demand('find names',{'nodeMetadata':nodeMetadata}).then (responses) ->
        matches = coalesceMatches responses
        sendResponse matches
    else
      sendResponse null

  # Keep the event listener open while we wait for a response
  # See https://code.google.com/p/chromium/issues/detail?id=330415
  return true

# Kick-Off
getOpenConsults()
chrome.system.memory.getInfo (memoryInfo) ->
  if memoryInfo.capacity > 4*1024*1024*1024
    loadLookups({'includeBiography':true})
  else
    loadLookups({'includeBiography':false})