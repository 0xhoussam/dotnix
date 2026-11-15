pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Weather (wttr.in, located by IP unless ~/.config/my-shell/weather.txt holds
// a place name) and today's calendar events (the sidecar reads the secret
// iCal address in ~/.config/my-shell/calendar.url). Both refresh when the
// date panel opens and the data is stale; nothing runs in the background.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell"

    // ---- weather ----
    property var weather: null          // parsed summary or null
    property string weatherError: ""
    property double weatherAt: 0
    FileView { id: placeFile; path: root.configDir + "/weather.txt"; blockLoading: true }
    Process {
        id: wproc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const c = j.current_condition[0]
                    const area = (j.nearest_area && j.nearest_area[0] && j.nearest_area[0].areaName[0].value) || ""
                    root.weather = {
                        area: area, temp: c.temp_C, feels: c.FeelsLikeC, desc: c.weatherDesc[0].value,
                        code: parseInt(c.weatherCode), humidity: c.humidity, wind: c.windspeedKmph,
                        days: j.weather.slice(0, 3).map(d => ({
                            date: d.date, max: d.maxtempC, min: d.mintempC,
                            code: parseInt(d.hourly[Math.min(4, d.hourly.length - 1)].weatherCode),
                            desc: d.hourly[Math.min(4, d.hourly.length - 1)].weatherDesc[0].value
                        }))
                    }
                    root.weatherError = ""
                    root.weatherAt = Date.now()
                } catch (e) { root.weatherError = "Weather unavailable" }
            }
        }
        onExited: (code) => { if (code !== 0) root.weatherError = "Weather unavailable (offline?)" }
    }
    function iconFor(code) {
        if ([113].includes(code)) return "weather-clear-symbolic"
        if ([116].includes(code)) return "weather-few-clouds-symbolic"
        if ([119, 122].includes(code)) return "weather-overcast-symbolic"
        if ([143, 248, 260].includes(code)) return "weather-fog-symbolic"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 377].includes(code)) return "weather-snow-symbolic"
        if ([200, 386, 389, 392, 395].includes(code)) return "weather-storm-symbolic"
        if ([176, 263, 266, 293, 296, 353].includes(code)) return "weather-showers-scattered-symbolic"
        return "weather-showers-symbolic"
    }

    // ---- calendar ----
    property var events: []
    property string calendarState: "idle"   // idle | loading | ok | not-configured | error
    property string calendarError: ""
    property double calendarAt: 0

    function refresh() {
        const now = Date.now()
        if (now - weatherAt > 30 * 60 * 1000 && !wproc.running) {
            const place = (placeFile.text() || "").trim().replace(/[^\w ,.-]/g, "").replace(/ /g, "+")
            wproc.exec(["curl", "-s", "-m", "10", "wttr.in/" + place + "?format=j1"])
        }
        if (now - calendarAt > 10 * 60 * 1000 && calendarState !== "loading") {
            calendarState = "loading"
            Agents.calendar((ok, v) => {
                calendarAt = Date.now()
                if (ok) { events = v; calendarState = "ok" }
                else if (v === "not-configured") { events = []; calendarState = "not-configured" }
                else { calendarError = v; calendarState = "error" }
            })
        }
    }
}
