'use strict'

# Change Icon
setIcon = (enabled) ->
  iconName = 'icon-' + if enabled then '' else 'bw-'
  iconDict =
    '16': "images/#{iconName}16.png"
    '19': "images/#{iconName}19.png"
    '38': "images/#{iconName}38.png"
    '128': "images/#{iconName}128.png"
  chrome.browserAction.setIcon path:"images/#{iconName}38.png"

updateWindows = (message) ->
  chrome.windows.getAll {}, (windows) ->
    for win of windows
      chrome.tabs.getAllInWindow win.id, (tabs) ->
        for i of tabs
          chrome.tabs.sendMessage tabs[i].id, message

enabledListener = () ->
  document.removeEventListener "DOMContentLoaded", enabledListener, false
  enabledCheckbox = document.body.querySelector '#got-names-enabled'
  
  # Find Out of Extension is Enabled
  ###getStorageSyncPromise('enabled').then(undefined,(result) -> setStorageSyncPromise({'enabled':true})).then (result) ->
    enabledCheckbox.checked = result.enabled
    setIcon result.enabled
  ###
  chrome.storage.sync.get 'enabled', (result)->
    enabled = result.enabled ? true
    if not result.enabled?
      chrome.storage.sync.set {'enabled': enabled}
    enabledCheckbox.checked = enabled
    setIcon enabled
  
  # Update the Enabled Status of the Extension
  enabledCheckbox.addEventListener 'click', (event) ->
    enabled = event.target.checked
    _gaq.push(['_trackEvent', event.target.id, 'clicked', 'enabled', enabled])
    setStorageSyncPromise({'enabled':enabled}).then (result) ->
      setIcon result.enabled
      #updateWindows {'enabled':result.enabled}

document.addEventListener "DOMContentLoaded", (enabledListener), false
