trackingenabled = false unless trackingenabled?

_gaq = _gaq or []
_gaq.push ["_setAccount", "UA-46919569-1"]
_gaq.push ["_trackPageview"]

if trackingenabled
  analyticsListener = ->
    document.removeEventListener "DOMContentLoaded", analyticsListener, false
    (->
      ga = document.createElement("script")
      ga.type = "text/javascript"
      ga.async = true
      ga.src = "https://ssl.google-analytics.com/ga.js"
      s = document.getElementsByTagName("script")[0]
      s.parentNode.insertBefore ga, s
    )()

  document.addEventListener "DOMContentLoaded", (analyticsListener), false
