pragma Singleton
import QtQuick
import "../Singletons"
import Quickshell
import Quickshell.Io

Item {
  id: weatherRoot

  property string locationName: "--"
  property real currentTemp: 0
  property real highTemp: 0
  property real lowTemp: 0
  property real feelsLike: 0
  property real humidity: 0
  property real windSpeed: 0
  property real rainChance: 0
  property string condition: "--"
  property string iconGlyph: ""
  readonly property string iconCode: iconGlyph
  readonly property var hourly: hoursForDay(0)
  property bool loading: false
  property bool hasError: false
  property string errorText: ""
  property bool ready: false
  property bool stale: false
  property double lastUpdated: 0
  property int requestId: 0
  property var activeXhr: null
  property var hourlyAll: []
  property int nowIndex: 0
  property real rangeMin: 0
  property real rangeMax: 1
  property var daily: []
  property var alerts: []

  readonly property bool useFahrenheit: Config.tempUnitFahrenheit
  readonly property string tempSuffix: weatherRoot.useFahrenheit ? "°F" : "°C"
  readonly property string windUnit: weatherRoot.useFahrenheit ? "mph" : "m/s"

  property real cachedLat: 0
  property real cachedLon: 0
  property string cachedForLocation: ""
  property string cachedName: ""
  property bool ipLookupBusy: false
  property bool pendingAuto: false
  readonly property int pollMinutes: Math.max(1, Config.weatherPollMinutes)

  // Maps WMO weather codes (Open-Meteo) to glyphs.
  function wmoIconToGlyph(code, isDay) {
    let dayMap = {
      0: "", 1: "", 2: "", 3: "",
      45: "󰖑", 48: "󰖑",
      51: "󰖗", 53: "󰖗", 55: "󰖗",
      56: "󰖗", 57: "󰖗",
      61: "󰖗", 63: "󰖗", 65: "󰖗",
      66: "󰖗", 67: "󰖗",
      71: "", 73: "", 75: "", 77: "",
      80: "", 81: "", 82: "",
      85: "", 86: "",
      95: "", 96: "", 99: ""
    }
    let nightMap = {
      0: "", 1: "", 2: "", 3: ""
    }
    if (!isDay && nightMap[code] !== undefined) return nightMap[code]
    return dayMap[code] || ""
  }

  // Human-readable label for a WMO code, used where OWM gave us "main".
  function wmoDescription(code) {
    const map = {
      0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
      45: "Fog", 48: "Fog",
      51: "Light Drizzle", 53: "Drizzle", 55: "Heavy Drizzle",
      56: "Freezing Drizzle", 57: "Freezing Drizzle",
      61: "Light Rain", 63: "Rain", 65: "Heavy Rain",
      66: "Freezing Rain", 67: "Freezing Rain",
      71: "Light Snow", 73: "Snow", 75: "Heavy Snow", 77: "Snow Grains",
      80: "Rain Showers", 81: "Rain Showers", 82: "Violent Showers",
      85: "Snow Showers", 86: "Snow Showers",
      95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
    }
    return map[code] || "--"
  }

  function dayLabel(dt, index) {
    if (index === 0) return "Today"
    const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return names[dt.getDay()]
  }

  function formatHour(h) {
    let h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + (h >= 12 ? " PM" : " AM")
  }

  function formatClock(iso) {
    if (!iso) return "--"
    let h = parseInt(iso.slice(11, 13))
    let h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + ":" + iso.slice(14, 16) + (h >= 12 ? " PM" : " AM")
  }

  // IP result and manual coords live in separate slots of the same Config string
  function readGeo(source) {
    try {
      let all = JSON.parse(Config.weatherGeoCache || "{}")
      let c = all[source]
      if (c && typeof c.lat === "number" && typeof c.lon === "number") return c
    } catch (e) {}
    return null
  }

  function writeGeo(source, entry) {
    let all = {}
    try { all = JSON.parse(Config.weatherGeoCache || "{}") } catch (e) {}
    all[source] = entry
    Config.weatherGeoCache = JSON.stringify(all)
  }

  // Pull lat/lon/name out of either ipapi.co or ipwho.is style responses.
  function parseIpResponse(text) {
    let d = JSON.parse(text)
    if (d.success === false || d.error) return null
    let lat = Number(d.latitude)
    let lon = Number(d.longitude)
    if (!isFinite(lat) || !isFinite(lon) || (lat === 0 && lon === 0)) return null
    let name = d.city || d.region || "Unknown"
    let cc = d.country_code || d.countryCode || ""
    if (d.region && cc === "US" && d.city) name += ", " + d.region
    else if (d.country_name || d.country) name += ", " + (d.country_name || d.country)
    return { lat: lat, lon: lon, name: name }
  }

  function fetchIpLocation(force) {
    if (weatherRoot.ipLookupBusy) return
    if (!force) {
      let c = weatherRoot.readGeo("ip")
      if (c) {
        weatherRoot.locationName = c.name
        weatherRoot.fetchForecast(c.lat, c.lon, c.name)
        return
      }
    }
    weatherRoot.ipLookupBusy = true
    weatherRoot.loading = true
    weatherRoot.hasError = false
    weatherRoot.tryIpProvider(0)
  }

  function tryIpProvider(i) {
    const providers = ["https://ipapi.co/json/", "https://ipwho.is/"]
    if (i >= providers.length) {
      weatherRoot.ipLookupBusy = false
      weatherRoot.pendingAuto = false
      weatherRoot.loading = false
      weatherRoot.hasError = true
      weatherRoot.errorText = "Couldn't detect location"
      return
    }
    let xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      let res = null
      if (xhr.status === 200) {
        try { res = weatherRoot.parseIpResponse(xhr.responseText) } catch (e) { res = null }
      }
      if (!res) { weatherRoot.tryIpProvider(i + 1); return }
      weatherRoot.ipLookupBusy = false
      weatherRoot.writeGeo("ip", res)
      weatherRoot.locationName = res.name
      if (weatherRoot.pendingAuto && Config.weatherLocationMode !== "auto") {
        // Mode change triggers fetchWeather(), which reads the fresh cache
        weatherRoot.pendingAuto = false
        Config.weatherLocationMode = "auto"
      } else {
        weatherRoot.pendingAuto = false
        weatherRoot.fetchForecast(res.lat, res.lon, res.name)
      }
    }
    xhr.open("GET", providers[i])
    xhr.send()
  }

  // Auto-detect button: always re-fetch from IP, then switch to auto mode
  function autoDetect() {
    if (weatherRoot.ipLookupBusy) return
    weatherRoot.pendingAuto = true
    weatherRoot.fetchIpLocation(true)
  }

  // Manual coordinates: reverse-geocode for a display name, then use them
  function setCoords(lat, lon) {
    weatherRoot.loading = true
    weatherRoot.hasError = false
    let xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      let name = lat.toFixed(2) + ", " + lon.toFixed(2)
      if (xhr.status === 200) {
        try {
          let d = JSON.parse(xhr.responseText)
          let city = d.city || d.locality || d.principalSubdivision || ""
          if (city) name = city + (d.countryName ? ", " + d.countryName : "")
        } catch (e) {}
      }
      weatherRoot.writeGeo("coords", { lat: lat, lon: lon, name: name })
      weatherRoot.locationName = name
      if (Config.weatherLocationMode !== "coords") Config.weatherLocationMode = "coords"
      else weatherRoot.fetchForecast(lat, lon, name)
    }
    xhr.open("GET", "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=" +
             lat + "&longitude=" + lon + "&localityLanguage=en")
    xhr.send()
  }

  function fetchWeather() {
    const mode = Config.weatherLocationMode
    if (mode === "auto") {
      weatherRoot.fetchIpLocation(false)
      return
    }
    if (mode === "coords") {
      let c = weatherRoot.readGeo("coords")
      if (c) {
        weatherRoot.locationName = c.name
        weatherRoot.fetchForecast(c.lat, c.lon, c.name)
      } else {
        weatherRoot.hasError = true
        weatherRoot.errorText = "No coordinates set"
      }
      return
    }
    if (!Config.weatherLocation || !Config.weatherLocation.trim()) {
      weatherRoot.hasError = true
      weatherRoot.errorText = "No location set"
      return
    }

    let loc = Config.weatherLocation.trim()

    // Reuse cached coordinates if the location string hasn't changed,
    // otherwise geocode it first via Open-Meteo's geocoding API.
    if (weatherRoot.cachedForLocation === loc && weatherRoot.cachedLat !== 0) {
      weatherRoot.locationName = weatherRoot.cachedName
      weatherRoot.fetchForecast(weatherRoot.cachedLat, weatherRoot.cachedLon, loc)
      return
    }

    weatherRoot.loading = true
    weatherRoot.hasError = false

    let geoUrl = "https://geocoding-api.open-meteo.com/v1/search?name=" +
                 encodeURIComponent(loc) + "&count=1&language=en&format=json"

    let xhrGeo = new XMLHttpRequest()
    xhrGeo.onreadystatechange = function() {
      if (xhrGeo.readyState !== XMLHttpRequest.DONE) return
      if (xhrGeo.status !== 200) {
        weatherRoot.loading = false
        weatherRoot.hasError = true
        weatherRoot.errorText = "Location lookup failed"
        return
      }
      try {
        let data = JSON.parse(xhrGeo.responseText)
        if (!data.results || data.results.length === 0) {
          weatherRoot.loading = false
          weatherRoot.hasError = true
          weatherRoot.errorText = "Location not found"
          return
        }
        let r = data.results[0]
        weatherRoot.cachedLat = r.latitude
        weatherRoot.cachedLon = r.longitude
        weatherRoot.cachedForLocation = loc
        let name = r.name
        if (r.admin1 && r.country_code === "US") name += ", " + r.admin1
        else if (r.country) name += ", " + r.country
        weatherRoot.locationName = name
        weatherRoot.cachedName = name

        weatherRoot.fetchForecast(r.latitude, r.longitude, loc)
      } catch (e) {
        weatherRoot.loading = false
        weatherRoot.hasError = true
        weatherRoot.errorText = "Bad response"
      }
    }
    xhrGeo.open("GET", geoUrl)
    xhrGeo.send()
  }

  function failForecast(msg) {
    weatherRoot.loading = false
    if (weatherRoot.ready) { weatherRoot.stale = true; return }
    weatherRoot.hasError = true
    weatherRoot.errorText = msg
  }

  function fetchForecast(lat, lon, locLabel) {
    let myId = ++weatherRoot.requestId
    weatherRoot.loading = true
    let url = "https://api.open-meteo.com/v1/forecast" +
      "?latitude=" + lat + "&longitude=" + lon +
      "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day" +
      "&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,precipitation_probability,is_day" +
      "&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max,sunrise,sunset" +
      "&temperature_unit=" + (weatherRoot.useFahrenheit ? "fahrenheit" : "celsius") +
      "&wind_speed_unit=" + (weatherRoot.useFahrenheit ? "mph" : "ms") +
      "&timezone=auto&forecast_days=7"

    let xhr = new XMLHttpRequest()
    weatherRoot.activeXhr = xhr
    watchdog.restart()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (myId !== weatherRoot.requestId) return
      watchdog.stop()
      if (xhr.status !== 200) { weatherRoot.failForecast("Forecast unavailable"); return }
      try {
        let data = JSON.parse(xhr.responseText)
        weatherRoot.applyForecast(data, locLabel, 0)
        weatherRoot.saveCache(data)
      } catch (e) {
        weatherRoot.failForecast("Bad response")
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  function applyForecast(data, locLabel, stamp) {
    if (!weatherRoot.locationName || weatherRoot.locationName === "--")
      weatherRoot.locationName = locLabel

    let cur = data.current
    weatherRoot.currentTemp = Math.round(cur.temperature_2m)
    weatherRoot.feelsLike = Math.round(cur.apparent_temperature)
    weatherRoot.humidity = Math.round(cur.relative_humidity_2m)
    weatherRoot.windSpeed = Math.round(cur.wind_speed_10m)
    weatherRoot.condition = weatherRoot.wmoDescription(cur.weather_code)
    weatherRoot.iconGlyph = weatherRoot.wmoIconToGlyph(cur.weather_code, cur.is_day === 1)

    // Hourly stays as strings in the location's own timezone, no Date parsing
    let h = data.hourly
    let all = []
    for (let i = 0; i < h.time.length; i++) {
      all.push({
        hour: parseInt(h.time[i].slice(11, 13)),
        dayIndex: data.daily.time.indexOf(h.time[i].slice(0, 10)),
        temp: Math.round(h.temperature_2m[i]),
        feels: Math.round(h.apparent_temperature[i]),
        humidity: Math.round(h.relative_humidity_2m[i]),
        wind: Math.round(h.wind_speed_10m[i]),
        pop: h.precipitation_probability ? Math.round(h.precipitation_probability[i]) : 0,
        icon: weatherRoot.wmoIconToGlyph(h.weather_code[i], h.is_day[i] === 1),
        condition: weatherRoot.wmoDescription(h.weather_code[i])
      })
    }
    let ni = h.time.indexOf(cur.time.slice(0, 13) + ":00")
    weatherRoot.nowIndex = ni < 0 ? 0 : ni
    weatherRoot.hourlyAll = all
    weatherRoot.rainChance = all.length > 0 ? all[weatherRoot.nowIndex].pop : 0

    let d = data.daily
    let days = []
    for (let k = 0; k < d.time.length; k++) {
      let dayHours = all.filter(x => x.dayIndex === k)
      let hum = dayHours.length > 0
        ? Math.round(dayHours.reduce((a, x) => a + x.humidity, 0) / dayHours.length) : 0
      let dt = new Date(d.time[k] + "T00:00:00")
      days.push({
        date: dt,
        label: weatherRoot.dayLabel(dt, k),
        hi: Math.round(d.temperature_2m_max[k]),
        lo: Math.round(d.temperature_2m_min[k]),
        feels: Math.round(d.apparent_temperature_max[k]),
        pop: Math.round(d.precipitation_probability_max[k] || 0),
        wind: Math.round(d.wind_speed_10m_max[k]),
        humidity: hum,
        sunrise: weatherRoot.formatClock(d.sunrise[k]),
        sunset: weatherRoot.formatClock(d.sunset[k]),
        icon: weatherRoot.wmoIconToGlyph(d.weather_code[k], true),
        condition: weatherRoot.wmoDescription(d.weather_code[k])
      })
    }
    weatherRoot.rangeMin = Math.min.apply(null, days.map(x => x.lo))
    weatherRoot.rangeMax = Math.max.apply(null, days.map(x => x.hi))
    weatherRoot.daily = days
    weatherRoot.highTemp = days[0].hi
    weatherRoot.lowTemp = days[0].lo

    // Open-Meteo free tier has no alerts endpoint; keep the array empty.
    weatherRoot.alerts = []

    weatherRoot.hasError = false
    weatherRoot.stale = false
    weatherRoot.loading = false
    weatherRoot.ready = true
    weatherRoot.lastUpdated = stamp > 0 ? stamp : Date.now()
  }

  // Today starts at the current hour, other days show every 3 hours
  function hoursForDay(d) {
    let all = weatherRoot.hourlyAll
    if (d === 0) return all.slice(weatherRoot.nowIndex, weatherRoot.nowIndex + 8)
    return all.filter(x => x.dayIndex === d && x.hour % 3 === 0)
  }

  function refreshIfStale(maxAgeMs) {
    if (Date.now() > weatherRoot.lastUpdated + (maxAgeMs || 300000)) weatherRoot.fetchWeather()
  }

  function saveCache(data) {
    cacheFile.setText(JSON.stringify({
      stamp: Date.now(),
      name: weatherRoot.locationName,
      fahrenheit: weatherRoot.useFahrenheit,
      data: data
    }))
  }

  // Aborts a request that never completes
  Timer {
    id: watchdog
    interval: 15000
    onTriggered: {
      weatherRoot.requestId++
      if (weatherRoot.activeXhr) weatherRoot.activeXhr.abort()
      weatherRoot.failForecast("Forecast timed out")
    }
  }

  // Last good forecast on disk, shown right away after a restart or while offline
  FileView {
    id: cacheFile
    path: Quickshell.cachePath("weather.json")
    onLoaded: {
      try {
        let c = JSON.parse(cacheFile.text())
        if (weatherRoot.ready || c.fahrenheit !== weatherRoot.useFahrenheit) return
        weatherRoot.locationName = c.name
        weatherRoot.applyForecast(c.data, c.name, c.stamp)
        weatherRoot.stale = true
      } catch (e) {}
    }
  }

  Timer {
    id: refreshTimer
    interval: weatherRoot.pollMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: weatherRoot.fetchWeather()
  }

  Connections {
    target: Config
    function onWeatherLocationChanged() { if (Config.weatherLocationMode === "city") weatherRoot.fetchWeather() }
    function onWeatherLocationModeChanged() { weatherRoot.fetchWeather() }
    function onTempUnitFahrenheitChanged() { weatherRoot.fetchWeather() }
  }
}
