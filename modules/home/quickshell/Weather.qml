pragma Singleton
import QtQuick
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
  property string iconCode: "01d"
  property bool loading: false
  property bool hasError: false
  property string errorText: ""
  property var hourly: []
  property var daily: []
  property var alerts: []

  readonly property bool useFahrenheit: Config.tempUnitFahrenheit
  readonly property string tempSuffix: weatherRoot.useFahrenheit ? "°F" : "°C"
  readonly property string windUnit: weatherRoot.useFahrenheit ? "mph" : "m/s"

  // Cached geocoded coordinates so we don't re-geocode every refresh
  property real cachedLat: 0
  property real cachedLon: 0
  property string cachedForLocation: ""

  // Maps WMO weather codes (Open-Meteo) to glyphs. isDay lets us pick a
  // day/night variant where it matters (clear/cloudy).
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

  function formatHour(dt) {
    let h = dt.getHours()
    let suffix = h >= 12 ? "PM" : "AM"
    let h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + " " + suffix
  }

  function fetchWeather() {
    if (!Config.weatherLocation || !Config.weatherLocation.trim()) {
      weatherRoot.hasError = true
      weatherRoot.errorText = "No location set"
      return
    }

    let loc = Config.weatherLocation.trim()

    // Reuse cached coordinates if the location string hasn't changed,
    // otherwise geocode it first via Open-Meteo's geocoding API.
    if (weatherRoot.cachedForLocation === loc && weatherRoot.cachedLat !== 0) {
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

  function fetchForecast(lat, lon, locLabel) {
    let tempUnit = weatherRoot.useFahrenheit ? "fahrenheit" : "celsius"
    let windUnitParam = weatherRoot.useFahrenheit ? "mph" : "ms"

    let url = "https://api.open-meteo.com/v1/forecast" +
      "?latitude=" + lat + "&longitude=" + lon +
      "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day" +
      "&hourly=temperature_2m,weather_code,precipitation_probability" +
      "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
      "&temperature_unit=" + tempUnit +
      "&wind_speed_unit=" + windUnitParam +
      "&timezone=auto" +
      "&forecast_days=7"

    let xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      weatherRoot.loading = false
      if (xhr.status !== 200) {
        weatherRoot.hasError = true
        weatherRoot.errorText = "Forecast unavailable"
        return
      }
      try {
        let data = JSON.parse(xhr.responseText)
        weatherRoot.hasError = false
        if (!weatherRoot.locationName || weatherRoot.locationName === "--") {
          weatherRoot.locationName = locLabel
        }

        let cur = data.current
        weatherRoot.currentTemp = Math.round(cur.temperature_2m)
        weatherRoot.feelsLike = Math.round(cur.apparent_temperature)
        weatherRoot.humidity = Math.round(cur.relative_humidity_2m)
        weatherRoot.windSpeed = Math.round(cur.wind_speed_10m)
        weatherRoot.condition = weatherRoot.wmoDescription(cur.weather_code)
        weatherRoot.iconCode = weatherRoot.wmoIconToGlyph(cur.weather_code, cur.is_day === 1)

        // Hourly: next 8 entries from "now" onward
        let hTimes = data.hourly.time
        let hTemp = data.hourly.temperature_2m
        let hCode = data.hourly.weather_code
        let hPop = data.hourly.precipitation_probability
        let nowIdx = 0
        let nowMs = Date.now()
        for (let i = 0; i < hTimes.length; i++) {
          if (new Date(hTimes[i]).getTime() >= nowMs) { nowIdx = i; break }
        }
        let hourItems = []
        for (let j = nowIdx; j < Math.min(nowIdx + 8, hTimes.length); j++) {
          hourItems.push({
            time: new Date(hTimes[j]),
            temp: Math.round(hTemp[j]),
            icon: weatherRoot.wmoIconToGlyph(hCode[j], true),
            condition: weatherRoot.wmoDescription(hCode[j]),
            pop: hPop ? Math.round(hPop[j]) : 0
          })
        }
        weatherRoot.hourly = hourItems
        weatherRoot.rainChance = hourItems.length > 0 ? hourItems[0].pop : 0

        // Daily
        let dTimes = data.daily.time
        let dMax = data.daily.temperature_2m_max
        let dMin = data.daily.temperature_2m_min
        let dCode = data.daily.weather_code
        let dayItems = []
        for (let k = 0; k < dTimes.length; k++) {
          let d = new Date(dTimes[k] + "T00:00:00")
          dayItems.push({
            date: d,
            hi: Math.round(dMax[k]),
            lo: Math.round(dMin[k]),
            icon: weatherRoot.wmoIconToGlyph(dCode[k], true),
            label: weatherRoot.dayLabel(d, k)
          })
        }
        weatherRoot.daily = dayItems
        weatherRoot.highTemp = dayItems.length > 0 ? dayItems[0].hi : weatherRoot.currentTemp
        weatherRoot.lowTemp = dayItems.length > 0 ? dayItems[0].lo : weatherRoot.currentTemp

        // Open-Meteo free tier has no alerts endpoint; keep the array empty.
        weatherRoot.alerts = []
      } catch (e) {
        weatherRoot.hasError = true
        weatherRoot.errorText = "Bad response"
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  Timer {
    id: refreshTimer
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: weatherRoot.fetchWeather()
  }

  Connections {
    target: Config
    function onWeatherLocationChanged() { weatherRoot.fetchWeather() }
    function onTempUnitFahrenheitChanged() { weatherRoot.fetchWeather() }
  }

  Component.onCompleted: weatherRoot.fetchWeather()
}
