'use strict'
toggleText = (isDisabled) ->
  blockSettingsIcon = document.body.querySelector '#blockSettingsIcon'
  blockSettingsText = document.body.querySelector '#blockSettingsText'
  if isDisabled
    blockSettingsIcon.innerHTML = ''
    blockSettingsText.innerHTML = 'Disabled'
  else
    blockSettingsIcon.innerHTML = ''
    blockSettingsText.innerHTML = 'Enabled'

toggleDisabledSites = () ->
  isDisabledSite().then (results) ->
    # Toggle
    isDisabled = !results.isDisabled
    disabledSites = results.disabledSites
    disabledSites[results.currentUrl] = isDisabled
    
    # Update Sync Store
    setStorageSyncPromise({'disabledSites':JSON.stringify(disabledSites)}).then (result) ->
      setIcon isDisabled
      toggleText isDisabled
      _gaq.push(['_trackEvent', event.target.id, 'clicked', 'enabled', enabled])

enabledListener = () ->

  # Remove the listener so this event is fired only once
  document.removeEventListener "DOMContentLoaded", enabledListener, false

  # Set the popup text appropriately
  isDisabledSite().then (results) ->
    toggleText results.isDisabled
    
    # Listen for a click on the blockSettings link
    blockSettingsLink = document.body.querySelector '#blockSettings'
    blockSettingsLink.addEventListener 'click', (event) ->
      toggleDisabledSites()
      
# Wait to run all code until the browserAction page has loaded
document.addEventListener "DOMContentLoaded", (enabledListener), false