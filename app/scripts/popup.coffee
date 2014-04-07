'use strict'
toggleText = (isDisabled) ->
  blockSettingsIcon = document.body.querySelector '#blockSettingsIcon'
  blockSettingsText = document.body.querySelector '#blockSettingsText'
  if isDisabled
    blockSettingsIcon.innerHTML = '\u00D7'
    blockSettingsIcon.style.color = '#ee2d19'
    blockSettingsText.innerHTML = 'Disabled'
    blockSettingsText.style.color = '#ee2d19'
  else
    blockSettingsIcon.innerHTML = '\u2713'
    blockSettingsIcon.style.color = '#269926'
    blockSettingsText.innerHTML = 'Enabled'
    blockSettingsText.style.color = '#269926'

toggleDisabledSites = () ->
  isDisabledSite().then (results) ->
    # Toggle
    isDisabled = !results.isDisabled
    userDisabledSites = results.userDisabledSites
    userDisabledSites[results.currentUrl] = isDisabled

    # Update Sync Store
    setStorageSyncPromise({'userDisabledSites':JSON.stringify(userDisabledSites)}).then (result) ->
      setIcon isDisabled
      toggleText isDisabled
      _gaq.push(['_trackEvent', event.target.id, 'clicked', 'enabled', enabled])

enabledListener = () ->

  # Populate the 'View All CMs in Mosaic' Link
  chrome.tabs.query active: true, currentWindow: true, (tabs) ->
    tabId = tabs[0].id
    chrome.tabs.sendMessage tabId, command: "getAllMatchingCms", (res) ->
      blockSettingsLink = document.body.querySelector '#allMatchingCms'
      link = "https://vega.glgroup.com/mosaic/#/pi?similarCmids="
      for cmId of res
        link += cmId + ","
      link = link.slice(0, - 1)
      blockSettingsLink.href = link

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
