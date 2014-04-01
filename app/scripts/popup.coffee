'use strict'
toggleText = (enabled) ->
  blockSettingsIcon = document.body.querySelector '#blockSettingsIcon'
  blockSettingsText = document.body.querySelector '#blockSettingsText'
  if enabled
    blockSettingsIcon.innerHTML = ''
    blockSettingsText.innerHTML = 'Enabled'
  else
    blockSettingsIcon.innerHTML = ''
    blockSettingsText.innerHTML = 'Disabled'

enabledListener = () ->

  # Remove the listener so this event is fired only once
  document.removeEventListener "DOMContentLoaded", enabledListener, false

  # Set the popup text appropriately
  Promise.all([getDisabledSites,getCurrentUrl]).then (results) ->
    disabledSites = results[0]
    currentUrl = results[1]
    toggleText disabledSites[currentUrl]
      
    # Listen for a click on the blockSettings link
    blockSettingsLink = document.body.querySelector '#blockSettings'
    blockSettingsLink.addEventListener 'click', (event) ->
      toggleDisabledSites disabledSites, currentUrl
      
# Wait to run all code until the browserAction page has loaded
document.addEventListener "DOMContentLoaded", (enabledListener), false