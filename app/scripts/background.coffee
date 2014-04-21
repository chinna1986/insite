'use strict'
chrome.tabs.onActivated.addListener (activeInfo) ->
  isDisabledSite().then (results) ->
    setIcon results.isDisabled

logTiming = (message) ->
  d = new Date()
  console.log "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}:#{d.getMilliseconds()} - #{message}"

reSpecialChars = /([.?*+^$[\]\\(){}|-])/g
escapeRe = (str) ->
  (str+'').replace(reSpecialChars, "\\$1")

# Gobals
workerManager = []
openConsults = []
vegaUser = {}
rePunctuation = /[?:!.,;]*$/g

decorateFlyoutControl = (text) ->
  "<span class='glggotnames-flyout-control' style='background-color:rgba(255,223,120,0.3);'>"+text+"&nbsp;<span class='glg-glyph-list' style='border: solid 1px; border-radius: 0.4em; font-size: .8em; padding: .1em 0.2em;'></span></span>"

loadLookups = (options) ->

  workerArguments =
    'startId': 0
    'includeBiography': options.includeBiography
  workerConfig = [{
    ###
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
    },{
    ###
    workerUrl: "scripts/worker.js"
    initialDemand: "load firms"
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

coalesceMatches = (responses, nodeMetadata) ->
  coalescedMatchingNodes = {}
  for response in responses
    matchingNodes = response.workerArguments.matches
    for nodeIndex, nodeData of matchingNodes

      # If this node index has yet to be populated, perform a direct copy
      if !coalescedMatchingNodes[nodeIndex]?
        coalescedMatchingNodes[nodeIndex] = nodeData
      else
        for matchingGroup in nodeData.matchingGroups

          # Check if this match has already been populated by a previous shard
          coalescedMatchingGroup = null
          for candidateCoalescedMatchingGroup in coalescedMatchingNodes[nodeIndex].matchingGroups
            if candidateCoalescedMatchingGroup.nameString is matchingGroup.nameString
              coalescedMatchingGroup = candidateCoalescedMatchingGroup

              # Add open consults and vega user
              coalescedMatchingGroup.openConsults =  openConsults
              coalescedMatchingGroup.vegaUser =  vegaUser

              # Count
              coalescedMatchingGroup.count += matchingGroup.count

              # Excess CMs
              if matchingGroup.cm
                if !coalescedMatchingGroup.cm
                  coalescedMatchingGroup.cm = []
                for cmId in matchingGroup.cm
                  coalescedMatchingGroup.cm.push cmId

              # Excess Leads
              if matchingGroup.lead
                if !coalescedMatchingGroup.lead
                  coalescedMatchingGroup.lead = []
                for leadId in matchingGroup.lead
                  coalescedMatchingGroup.lead.push leadId

              # Merge Results
              for key, result of matchingGroup.results
                coalescedMatchingGroup.results.push result

          # If this is a new match for a textnode
          if coalescedMatchingGroup is null
            coalescedMatchingGroup = matchingGroup
            coalescedMatchingNodes[nodeIndex].matchingGroups.push coalescedMatchingGroup


  for key, coalescedMatchingNode of coalescedMatchingNodes
    for coalescedMatchingGroup in coalescedMatchingNode.matchingGroups

      # Remove excess leads, for now
      if coalescedMatchingGroup.lead
        coalescedMatchingGroup.count = coalescedMatchingGroup.count - coalescedMatchingGroup.lead.length

      # Delete Displayed Leads if We Have More Than 5 Results
      if coalescedMatchingGroup.results.length > 5
        i = coalescedMatchingGroup.results.length-1
        while i >= 0 and coalescedMatchingGroup.results.length > 5
          coalescedResult = coalescedMatchingGroup.results[i]
          if coalescedResult.l?
            coalescedMatchingGroup.count--
            coalescedMatchingGroup.results.splice i,1
          i--

      # Shunt Displayed CMs to Mosaic Link
      if coalescedMatchingGroup.results.length > 5
        i = coalescedMatchingGroup.results.length-1
        while i >= 0 and coalescedMatchingGroup.results.length > 5
          coalescedResult = coalescedMatchingGroup.results[i]
          if !coalescedMatchingGroup.cm
            coalescedMatchingGroup.cm = []
          coalescedMatchingGroup.cm.push coalescedResult.c
          coalescedMatchingGroup.results.splice i,1
          i--

  # Add span decoration to matched names
  for key, coalescedMatchingNode of coalescedMatchingNodes
    coalescedMatchingNode.textContent = nodeMetadata[key].textContent
    for coalescedMatchingGroup in coalescedMatchingNode.matchingGroups
      nameString = coalescedMatchingGroup.nameString
      re = new RegExp("\\b"+nameString, "i")
      coalescedMatchingNode.textContent = coalescedMatchingNode.textContent.replace re, decorateFlyoutControl(nameString)
  coalescedMatchingNodes

chrome.runtime.onMessage.addListener (message, sender, sendResponse) ->
  response = null
  switch message.method
    when "getCurrentUrl"
      getCurrentUrl().then (currentUrl) ->
        sendResponse currentUrl
    when "setIcon"
      setIcon message.message
    when "pushAnalytics"
      _gaq.push(message.message)
      sendResponse {}
    when "search-new"
      workerManager.demand('find names',{'nodeMetadata':message.nodeWorkerData}).then (responses) ->
        matches = coalesceMatches responses, message.nodeContentData
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
