'use strict'

rejects = ['head','style','title','link','meta','script','object','iframe','input','select','textarea']

logTiming = (message) ->
  d = new Date()
  console.log "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}:#{d.getMilliseconds()} - #{message}"

formatNames = (results) ->
  for result in results
    if result.m
      result.m = result.m[0].toUpperCase() + result.m.slice(1)
      result.n = result.n.replace("|"," "+result.m+" ")
    else
      result.n = result.n.replace("|"," ")
  results

convertToArray = (anObject) ->
  anArray = []
  for key, value of anObject
    anArray.push value
  return anArray

renderFlyout = (node,matches) ->

  if matches.cm?.length > 0
    moreCount = matches.cm.length
    moreUrl = matches.cm.join(',')
  processedMatches = formatNames(matches.results)

  flyoutRoot = document.createElement 'span'
  flyoutRoot.classList.add 'glggotnames-flyout-menu'

  flyoutShadow = flyoutRoot.webkitCreateShadowRoot()
  flyoutShadow.applyAuthorStyles = false
  #flyoutShadow.resetStyleInheritance = true

  flyout = document.createElement 'span'

  flyout.innerHTML = Templates["flyout"].render {matches:processedMatches, count:matches.count, moreCount:moreCount, moreUrl:moreUrl}
  while flyout.childNodes.length > 0
    flyoutShadow.appendChild(flyout.firstChild)

  for resultKey, resultValue of matches.results
    councilMemberId = parseInt(resultValue.c ? resultValue.l)
    analyticsEvents = ['add-to-consult','name','bio','more']
    for value in analyticsEvents
      eventElement = flyout.querySelectorAll("#" + value)[resultKey]
      if eventElement?
        setClickHandler eventElement, councilMemberId, value

  document.body.appendChild flyoutRoot
  
  flyoutRoot

bindFlyout = (icon,matches) ->

  #add moseover handlers to show/hide
  icon.addEventListener 'mouseover', (event) ->

    flyout = renderFlyout(icon,matches)
    f = flyout.webkitShadowRoot.querySelector('ul')
    h = icon
    chrome.runtime.sendMessage {method:'pushAnalytics', message:['_trackEvent', 'flyout', 'displayed', document.location.href]}, (response) ->

    addLeadToConsult = (leadId) ->
      (event) ->
        link = this
        event.preventDefault()
        url = 'https://query.glgroup.com/councilLead/attachLeadToConsult.mustache'
        data =
          userId: matches.vegaUser?.vegaUserId?.toString()
          leadId: leadId
          meetingRequestId: link.getAttribute 'href'
        getJSON({url:url,method:'POST',data:JSON.stringify(data)}).then(
          (response) -> link.parentElement.innerHTML = "Lead Added To Consult" 
        ).then( undefined,(err) ->
          link.parentElement.innerHTML = "Could Not Add Lead To Consult"
        )

    showConsultsList = (lead) ->
      lead.addEventListener 'click',(event) ->
        row = this.parentElement.parentElement
        unless row.querySelector('.glg-consults-list')?
          consultsList = document.createElement 'div'
          consultsList.innerHTML = Templates["consultslist"].render {consults:matches.openConsults}
          for consult in consultsList.querySelectorAll('.glg-add-to-consult')
            consult.addEventListener 'click', addLeadToConsult(this.getAttribute('href'))
          consultsList.querySelector('.glg-close-button a').addEventListener 'click', (event) ->
            event.preventDefault()
            consultsList.parentNode.removeChild consultsList
          row.appendChild consultsList
          ###while consultsList.childNodes.length > 0
            row.appendChild(consultsList.firstChild)
          ###
        event.preventDefault()

    leads = flyout.webkitShadowRoot.querySelectorAll('.glg-add-lead')
    l = leads.length-1
    while l>-1
      showConsultsList(leads.item(l))
      l--
      
    f.style.visibility = 'visible'
    f.style.opacity = '1'
    f.style.transitionDelay = '0s'
    left = h.getBoundingClientRect().left + document.body.scrollLeft + h.offsetWidth
    top = h.getBoundingClientRect().top + document.body.scrollTop

    hasRightWidth = document.documentElement.clientWidth > h.getBoundingClientRect().left + h.offsetWidth  + f.offsetWidth
    hasBottomHeight = document.documentElement.clientHeight> h.getBoundingClientRect().top + f.offsetHeight
    hasLeftWidth = h.getBoundingClientRect().left + h.offsetWidth  > f.offsetWidth
    hasTopHeight = h.getBoundingClientRect().top > f.offsetHeight

    switch
    #right bottom
      when hasRightWidth and hasBottomHeight
        f.style.left = left + 'px'
        f.style.top = top + 'px'

    #otherwise right top
      when hasRightWidth and hasTopHeight
        f.style.left = left + 'px'
        f.style.top = (top - f.offsetHeight) + 'px'

    #otherwise left bottom
      when hasLeftWidth and hasBottomHeight
        f.style.left = (left - f.offsetWidth) + 'px'
        f.style.top = (top + h.offsetHeight) + 'px'

    #otherise left top
      when hasLeftWidth and hasTopHeight
        f.style.left = (left - f.offsetWidth) + 'px'
        f.style.top = (top - f.offsetHeight) + 'px'

    #default case: right bottom
      else
        f.style.left = left + 'px'
        f.style.top = top + 'px'

    timeout = null
    icon.addEventListener 'mouseout', () ->
      timeout = setTimeout (->
        flyout.remove()
      ), 500

    f.addEventListener 'mouseover', (event) ->
      if timeout? then clearTimeout timeout

    f.addEventListener 'mouseout', () ->
      timeout = setTimeout (->
        flyout.remove()
      ), 500

setClickHandler = (eventElement, councilMemberId, key) ->
  eventElement.addEventListener "click", ->
    chrome.runtime.sendMessage {method:'pushAnalytics', message:['_trackEvent', 'councilMember', "clicked-#{key}", document.location.href, councilMemberId]}, (response) ->

getNodes = (rootNode) ->
  walker = document.createTreeWalker rootNode, NodeFilter.SHOW_ALL, ((node) ->
    if rejects.indexOf(node.parentNode.nodeName.toLowerCase()) > -1
      return NodeFilter.FILTER_REJECT
    else if node.nodeType is node.TEXT_NODE and node.textContent isnt '' and node.textContent.trim().length > 0
      return NodeFilter.FILTER_ACCEPT
    else
      return NodeFilter.FILTER_SKIP
  ), false
  
  nodes = []
  nodeMetadata = []
  while walker.nextNode()
    node = walker.currentNode
    text = node.textContent
    words = rita.RiTa.tokenize(text ? '')
    tags = rita.RiTa.getPosTags(words ? [])
    nodeMetadata.push {'worker':{'tags':tags, 'words':words, 'skip':1},'content':{'textContent':text}}
    nodes.push node
  results = {'nodes':nodes, 'nodeMetadata':nodeMetadata}

processData = (nodes, nodeMetadata) ->
  chrome.runtime.sendMessage {'method':'search-new', 'nodeMetadata':nodeMetadata}, (allMatches) ->
    # Append, quickly
    for nodeIndex, nodeMatch of allMatches

      parentNode = nodes[nodeIndex].parentNode
      newNode = document.createElement 'span'
      newNode.innerHTML = nodeMatch.nameString
      parentNode.replaceChild newNode, nodes[nodeIndex]

      icons = parentNode.querySelectorAll('.glg-glyph-list')
      count = 0
      for icon in icons
        bindFlyout icon, nodeMatch.matchingCmGroups[count]
        count++

blacklist = ['glgroup.com','glg.it','mail.google.com','facebook.com']
isBlacklisted = () ->
  fullDomainName = document.location.hostname.toLowerCase()
  secondLevelDomainName = fullDomainName.split(".").slice(0,-2).join(".")
  blacklist.indexOf(secondLevelDomainName) > -1 or blacklist.indexOf(fullDomainName) > -1

toggleExtension = (enabled) ->
  unless isBlacklisted(document.location.hostname)
    # if we're enabled, find names and add flyouts
    if enabled
      results = getNodes(document.body)
      nodes = results.nodes
      nodeMetadata = results.nodeMetadata
      processData(nodes,nodeMetadata)

    #if we're disabled, remove all flyouts
    else
      #replace highlighted names with original text
      highlights = document.querySelectorAll '.glggotnames-flyout-control'
      for highlight in highlights
        text = document.createTextNode highlight.textContent.trim()
        highlight.parentNode.replaceChild text, highlight
      #remove flyout menus
      for flyout in document.querySelectorAll '.glggotnames-flyout-menu'
        flyout.parentNode.removeChild(flyout)

#toggle flyouts on the page when extension is enabled/disabled
chrome.storage.onChanged.addListener (changes, namespace) ->
  if changes['enabled']?
    toggleExtension changes['enabled'].newValue

#listen for pageload
observer = new MutationObserver (mutations) ->
  nodes = []
  nodeMetadata = []
  for mutation in mutations
    if mutation.addedNodes.length > 0
      for addedNode in mutation.addedNodes
        if addedNode?.innerHTML?.search('glggotnames-flyout-control') < 0
          results = getNodes(addedNode)
          nodes = nodes.concat(results.nodes)
          nodeMetadata = nodeMetadata.concat(results.nodeMetadata)
  if nodes.length > 0
    processData(nodes,nodeMetadata)
 
target = document
config = { subtree: true, childList: true, characterData: true }
observer.observe(target, config)

start = () ->
  if document.readyState == 'complete'
    getStorageSyncPromise('enabled').then ((result) ->
      enabled = result.enabled ? true
      toggleExtension enabled
    ), (result) ->
      toggleExtension true

#listen for pageload
document.onreadystatechange = start
