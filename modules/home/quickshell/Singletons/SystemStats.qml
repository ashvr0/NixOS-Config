pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // static info
  property string hostname: ""
  property string osName: ""
  property string kernelVersion: ""
  property string cpuModel: ""
  property int cpuCores: 0
  property real totalRamGb: 0.0
  property string gpuModel: ""
  property string diskModel: ""
  property real diskTotalGb: 0.0
  property string shellName: Quickshell.env("SHELL") ? Quickshell.env("SHELL").split("/").pop() : "Unknown"

  // uptime (static-ish, refreshed periodically)
  property string uptime: ""
  property int uptimeSeconds: 0

  // live polled stats
  property real cpuPercent: 0
  property real ramPercent: 0
  property real tempC: 0
  property real diskPercent: 0
  property string diskUsedStr: ""
  property string diskTotalStr: ""
  property real netRxBps: 0
  property real netTxBps: 0
  property string netRxText: "0 B/s"
  property string netTxText: "0 B/s"

  // battery 
  property bool hasBattery: false
  property real batteryPercent: 0
  property string batteryStatus: ""
  property bool batteryCharging: batteryStatus === "Charging" || batteryStatus === "Full"

  property real _prevIdle: 0
  property real _prevTotal: 0
  property real _prevRxBytes: -1
  property real _prevTxBytes: -1

  function formatBytesPerSec(bytes) {
    if (bytes <= 0 || isNaN(bytes)) return "0 B/s"
    var k = 1024, sizes = ["B/s", "KB/s", "MB/s", "GB/s"]
    var i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i]
  }

  function fetch() {
    return {
      hostname: root.hostname,
      osName: root.osName,
      kernelVersion: root.kernelVersion,
      cpuModel: root.cpuModel,
      cpuCores: root.cpuCores,
      totalRamGb: root.totalRamGb,
      gpuModel: root.gpuModel,
      diskModel: root.diskModel,
      diskTotalGb: root.diskTotalGb,
      shellName: root.shellName,
      uptime: root.uptime,
      uptimeSeconds: root.uptimeSeconds,
      cpuPercent: root.cpuPercent,
      ramPercent: root.ramPercent,
      tempC: root.tempC,
      diskPercent: root.diskPercent
    }
  }

  // Static info via FileView
  FileView {
    id: osReleaseFile
    path: "/etc/os-release"
    onLoaded: {
      let txt = text()
      if (!txt) return
      let lines = txt.split("\n")
      for (let i = 0; i < lines.length; i++) {
        let line = lines[i]
        if (line.startsWith("PRETTY_NAME=")) {
          root.osName = line.split("=")[1].replace(/"/g, "").trim()
          break
        } else if (line.startsWith("NAME=") && !root.osName) {
          root.osName = line.split("=")[1].replace(/"/g, "").trim()
        }
      }
    }
  }

  FileView {
    id: kernelFile
    path: "/proc/sys/kernel/osrelease"
    onLoaded: {
      let txt = text()
      if (txt) root.kernelVersion = txt.trim()
    }
  }

  FileView {
    id: hostnameFile
    path: "/etc/hostname"
    onLoaded: {
      let txt = text()
      if (txt) root.hostname = txt.trim()
    }
  }

  FileView {
    id: cpuFile
    path: "/proc/cpuinfo"
    onLoaded: {
      let txt = text()
      if (!txt) return
      let lines = txt.split("\n")
      let count = 0
      let model = ""
      for (let i = 0; i < lines.length; i++) {
        let line = lines[i]
        if (line.startsWith("model name")) {
          count++
          if (!model) {
            let parts = line.split(":")
            if (parts.length > 1) model = parts[1].trim()
          }
        }
      }
      root.cpuModel = model
      root.cpuCores = count
    }
  }

  FileView {
    id: memTotalFile
    path: "/proc/meminfo"
    onLoaded: {
      let txt = text()
      if (!txt) return
      let lines = txt.split("\n")
      for (let i = 0; i < lines.length; i++) {
        let line = lines[i]
        if (line.startsWith("MemTotal:")) {
          let parts = line.split(/\s+/)
          if (parts.length >= 2) {
            let kb = parseInt(parts[1])
            root.totalRamGb = parseFloat((kb / 1048576).toFixed(1))
          }
          break
        }
      }
    }
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    onLoaded: {
      let txt = text()
      if (!txt) return
      let parts = txt.trim().split(/\s+/)
      if (parts.length > 0) {
        let sec = Math.floor(parseFloat(parts[0]))
        root.uptimeSeconds = sec
        let d = Math.floor(sec / 86400)
        let h = Math.floor((sec % 86400) / 3600)
        let m = Math.floor((sec % 3600) / 60)
        let res = ""
        if (d > 0) res += d + "d "
        if (h > 0 || d > 0) res += h + "h "
        res += m + "m"
        root.uptime = res.trim()
      }
    }
  }

  function cleanGpuName(raw) {
    if (!raw) return "Unknown GPU"

    let out = []
    raw.split(" / ").forEach(function(part) {
      let s = part.replace(/\(rev [0-9a-fA-F]+\)/gi, "")

      let vendor = ""
      if (/nvidia/i.test(s)) vendor = "NVIDIA"
      else if (/\b(amd|ati|advanced micro)\b/i.test(s)) vendor = "AMD"
      else if (/intel/i.test(s)) vendor = "Intel"

      s = s.replace(/NVIDIA Corporation|Intel Corporation|Advanced Micro Devices,? Inc\.?|\[AMD\/ATI\]/gi, "").trim()

      // marketing name is in the last [brackets], the chip code sits outside
      let m = s.match(/\[([^\]]+)\](?!.*\[)/)
      let name = m ? m[1] : s

      // AMD lists variants like "Radeon RX 6600/6600 XT/6600M", keep the first
      if (vendor === "AMD") name = name.split("/")[0]

      name = name.replace(/\bLite Hash Rate\b/i, "").replace(/\s+/g, " ").trim()
      if (!name) name = s

      if (vendor && !name.toLowerCase().startsWith(vendor.toLowerCase())) name = vendor + " " + name
      if (name && out.indexOf(name) === -1) out.push(name)
    })

    return out.length > 0 ? out.join(" / ") : "Unknown GPU"
  }

  // GPU / disk model via one shell call (info with no clean single-file /proc or /sys source)
  Process {
    id: hwProc
    running: false
    command: [
      "bash", "-c",
      "gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | cut -d':' -f3- | sed -e 's/^[ \\t]*//' -e 's/ (rev .*)$//' | head -n1); " +
      "[ -z \"$gpu\" ] && gpu=\"Unknown GPU\"; " +
      "disk_mod=$(lsblk -d -n -o MODEL 2>/dev/null | grep -v '^$' | head -n1); " +
      "[ -z \"$disk_mod\" ] && disk_mod=\"Generic Drive\"; " +
      "df_out=$(df -B1 / 2>/dev/null | awk 'NR==2 {print $2}'); " +
      "echo \"$gpu|$disk_mod|$df_out\""
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        let txt = this.text ? this.text.trim() : ""
        if (!txt) return
        let p = txt.split("|")
        if (p.length >= 3) {
          root.gpuModel = root.cleanGpuName(p[0])
          root.diskModel = p[1]
          root.diskTotalGb = parseFloat((parseInt(p[2]) / 1073741824).toFixed(1))
        }
      }
    }
  }

  // Live polled stats
  Process {
    id: cpuProc
    command: ["sh", "-c", "head -n1 /proc/stat"]
    stdout: SplitParser {
      onRead: function(line) {
        const parts = line.trim().split(/\s+/).slice(1).map(Number)
        const idle = parts[3] + (parts[4] || 0)
        const total = parts.reduce((a, b) => a + b, 0)
        const deltaIdle = idle - root._prevIdle
        const deltaTotal = total - root._prevTotal
        if (root._prevTotal > 0 && deltaTotal > 0) {
          root.cpuPercent = Math.max(0, Math.min(100, (1 - deltaIdle / deltaTotal) * 100))
        }
        root._prevIdle = idle
        root._prevTotal = total
      }
    }
  }

  Process {
    id: ramProc
    property real _total: 0
    property real _avail: 0
    command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
    stdout: SplitParser {
      onRead: function(line) {
        const m = line.trim().split(/\s+/)
        if (m[0] === "MemTotal:") ramProc._total = Number(m[1])
        if (m[0] === "MemAvailable:") ramProc._avail = Number(m[1])
        if (ramProc._total > 0 && ramProc._avail > 0) {
          root.ramPercent = Math.max(0, Math.min(100, ((ramProc._total - ramProc._avail) / ramProc._total) * 100))
        }
      }
    }
  }

  Process {
    id: tempProc
    command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1"]
    stdout: SplitParser {
      onRead: function(line) {
        const v = Number(line.trim())
        if (!isNaN(v) && v > 0) {
          root.tempC = v > 1000 ? v / 1000 : v
        }
      }
    }
  }

  Process {
    id: diskProc
    command: ["sh", "-c", "df -k --output=used,size,pcent / | tail -n1"]
    stdout: SplitParser {
      onRead: function(line) {
        const parts = line.trim().split(/\s+/)
        if (parts.length >= 3) {
          const usedKb = Number(parts[0])
          const totalKb = Number(parts[1])
          const pct = parseFloat(parts[2])
          if (!isNaN(pct)) root.diskPercent = pct
          if (!isNaN(usedKb)) root.diskUsedStr = (usedKb / 1048576).toFixed(1) + "G"
          if (!isNaN(totalKb)) root.diskTotalStr = (totalKb / 1048576).toFixed(1) + "G"
        }
      }
    }
  }

  Process {
    id: netProc
    command: ["sh", "-c", "cat /proc/net/dev | awk 'NR>2 && $1 !~ /lo:/ { rx+=$2; tx+=$10 } END { print rx, tx }'"]
    stdout: SplitParser {
      onRead: function(line) {
        const parts = line.trim().split(/\s+/).map(Number)
        const rx = parts[0], tx = parts[1]
        if (root._prevRxBytes >= 0) {
          root.netRxBps = Math.max(0, (rx - root._prevRxBytes) / 2)
          root.netTxBps = Math.max(0, (tx - root._prevTxBytes) / 2)
          root.netRxText = root.formatBytesPerSec(root.netRxBps)
          root.netTxText = root.formatBytesPerSec(root.netTxBps)
        }
        root._prevRxBytes = rx
        root._prevTxBytes = tx
      }
    }
  }

  Process {
    id: batteryProc
    command: ["sh", "-c",
      "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
      "if [ -z \"$bat\" ]; then echo none; else " +
      "cap=$(cat \"$bat/capacity\" 2>/dev/null); " +
      "st=$(cat \"$bat/status\" 2>/dev/null); " +
      "echo \"$cap|$st\"; fi"
    ]
    stdout: SplitParser {
      onRead: function(line) {
        const txt = line.trim()
        if (txt === "none" || txt === "") {
          root.hasBattery = false
          return
        }
        const parts = txt.split("|")
        const pct = Number(parts[0])
        if (!isNaN(pct)) {
          root.hasBattery = true
          root.batteryPercent = pct
          root.batteryStatus = parts[1] || ""
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      cpuProc.running = true
      ramProc.running = true
      tempProc.running = true
      diskProc.running = true
      netProc.running = true
      batteryProc.running = true
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: uptimeFile.reload()
  }

  Component.onCompleted: {
    osReleaseFile.reload()
    kernelFile.reload()
    hostnameFile.reload()
    cpuFile.reload()
    memTotalFile.reload()
    uptimeFile.reload()
    hwProc.running = true
  }
}
