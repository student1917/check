# SoundHub Laptop Check V3 Compact
# Windows PowerShell 5.1+ / PowerShell 7+
# Compact output for used-laptop intake.

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

function SafeText($v, $fallback = "N/A") {
    if ($null -eq $v) { return $fallback }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return $fallback }
    return $s.Trim()
}

function Decode-WmiChars($arr) {
    if (-not $arr) { return "N/A" }
    $chars = @($arr | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
    if ($chars.Count -eq 0) { return "N/A" }
    return (-join $chars).Trim()
}


function Get-ResolutionLabel($modeText) {
    if (-not $modeText) { return "N/A" }

    $m = [regex]::Match($modeText, '(\d{3,4})\s*x\s*(\d{3,4})')
    if (-not $m.Success) { return "N/A" }

    $w = [int]$m.Groups[1].Value
    $h = [int]$m.Groups[2].Value
    $key = "$w`x$h"

    switch ($key) {
        "1366x768"  { return "HD" }
        "1600x900"  { return "HD+" }
        "1920x1080" { return "Full HD (FHD)" }
        "1920x1200" { return "WUXGA / FHD+" }
        "2160x1350" { return "2K+" }
        "2240x1400" { return "2.2K" }
        "2256x1504" { return "2K+ / 2.2K" }
        "2496x1664" { return "2.5K-class" }
        "2560x1440" { return "QHD / 2K" }
        "2560x1600" { return "QHD+ / 2.5K" }
        "2880x1800" { return "2.8K" }
        "2880x1920" { return "3K" }
        "3000x2000" { return "3K" }
        "3072x1920" { return "3K" }
        "3200x2000" { return "3.2K" }
        "3456x2160" { return "3.5K-class" }
        "3456x2234" { return "3.5K-class" }
        "3840x2160" { return "4K UHD" }
        "3840x2400" { return "4K UHD+ / WQUXGA" }
        default {
            if ($w -ge 3800 -and $h -ge 2100) { return "4K-class" }
            if ($w -ge 2880 -and $h -ge 1800) { return "3K-class" }
            if ($w -ge 2500 -and $h -ge 1400) { return "2.5K / QHD-class" }
            if ($w -ge 2000 -and $h -ge 1300) { return "2K-class" }
            return "$w x $h"
        }
    }
}

function Get-MemoryTypeName($code) {
    switch ([int]$code) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        27 { "LPDDR" }
        28 { "LPDDR2" }
        29 { "LPDDR3" }
        30 { "LPDDR4" }
        34 { "DDR5" }
        35 { "LPDDR5" }
        default { "N/A" }
    }
}

$cs      = Get-CimInstance Win32_ComputerSystem
$bios    = Get-CimInstance Win32_BIOS
$os      = Get-CimInstance Win32_OperatingSystem
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramList = @(Get-CimInstance Win32_PhysicalMemory)
$gpuList = @(Get-CimInstance Win32_VideoController)
$disks   = @(Get-PhysicalDisk)
$pnps    = @(Get-PnpDevice -PresentOnly)

# RAM summary
$ramGB = [math]::Round([double]$cs.TotalPhysicalMemory / 1GB)
$ramType = "N/A"
$ramSpeed = "N/A"
if ($ramList.Count -gt 0) {
    $ramType = Get-MemoryTypeName $ramList[0].SMBIOSMemoryType
    if ($ramList[0].ConfiguredClockSpeed) {
        $ramSpeed = "$($ramList[0].ConfiguredClockSpeed) MT/s"
    } elseif ($ramList[0].Speed) {
        $ramSpeed = "$($ramList[0].Speed) MT/s"
    }
}

# Storage summary
$diskLines = @()
foreach ($d in $disks) {
    $sizeGB = [math]::Round([double]$d.Size / 1GB)
    $sizeLabel = if ($sizeGB -ge 1800) { "2TB" }
                 elseif ($sizeGB -ge 900) { "1TB" }
                 elseif ($sizeGB -ge 450) { "512GB" }
                 elseif ($sizeGB -ge 220) { "256GB" }
                 elseif ($sizeGB -ge 110) { "128GB" }
                 else { "$sizeGB GB" }

    $bus = SafeText $d.BusType
    if ($bus -eq "RAID" -and $d.FriendlyName -match "NVMe") {
        $bus = "NVMe"
    }

    $diskLines += "$(SafeText $d.FriendlyName) | $sizeLabel | $bus | Health: $(SafeText $d.HealthStatus)"
}

# GPU summary
$gpuNames = @($gpuList | Select-Object -ExpandProperty Name -Unique)

# Display from DxDiag
$dxPath = Join-Path $env:TEMP "SoundHub_dxdiag.txt"
Remove-Item $dxPath -Force -ErrorAction SilentlyContinue
Start-Process -FilePath "dxdiag.exe" -ArgumentList "/dontskip /t `"$dxPath`"" -WindowStyle Hidden -Wait

$dxText = ""
if (Test-Path $dxPath) {
    $dxText = Get-Content $dxPath -Raw
}

$currentMode = "N/A"
$nativeMode = "N/A"
$hdrSupport = "N/A"
$maxLuminance = "N/A"

if ($dxText) {
    $m = [regex]::Match($dxText, '(?im)^\s*Current Mode:\s*(.+)$')
    if ($m.Success) { $currentMode = $m.Groups[1].Value.Trim() }

    $m = [regex]::Match($dxText, '(?im)^\s*Native Mode:\s*(.+)$')
    if ($m.Success) { $nativeMode = $m.Groups[1].Value.Trim() }

    $m = [regex]::Match($dxText, '(?im)^\s*HDR Support:\s*(.+)$')
    if ($m.Success) { $hdrSupport = $m.Groups[1].Value.Trim() }

    $m = [regex]::Match($dxText, '(?im)Max Luminance\s*=\s*([0-9.]+)')
    if ($m.Success) {
        $lum = [math]::Round([double]$m.Groups[1].Value)
        $maxLuminance = "$lum nits (DxDiag)"
    }
}

$resolutionLabel = Get-ResolutionLabel $nativeMode

# EDID panel info
$monID = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | Select-Object -First 1
$monParam = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | Select-Object -First 1

$panelMaker = "N/A"
$panelID = "N/A"
$screenSize = "N/A"

if ($monID) {
    $panelMaker = Decode-WmiChars $monID.ManufacturerName
    $panelID = Decode-WmiChars $monID.ProductCodeID
}

if ($monParam) {
    $wcm = [double]$monParam.MaxHorizontalImageSize
    $hcm = [double]$monParam.MaxVerticalImageSize
    if ($wcm -gt 0 -and $hcm -gt 0) {
        $inch = [math]::Sqrt(($wcm*$wcm)+($hcm*$hcm))/2.54
        $screenSize = ("{0:N1} inch" -f $inch)
    }
}

# Touch
$touch = @($pnps | Where-Object {
    $_.FriendlyName -match 'HID-compliant touch screen|touchscreen|touch screen'
})
$touchText = if ($touch.Count -gt 0) { "Yes" } else { "No / Not detected" }

# Battery
$battStatic = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData | Select-Object -First 1
$battFull   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object -First 1
$battCycle  = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount | Select-Object -First 1
$battWin32  = Get-CimInstance Win32_Battery | Select-Object -First 1

$designCap = $battStatic.DesignedCapacity
$fullCap = $battFull.FullChargedCapacity
$cycleCount = $battCycle.CycleCount
$currentPct = $battWin32.EstimatedChargeRemaining

$battHealth = "N/A"
if ($designCap -and $fullCap -and [double]$designCap -gt 0) {
    $battHealth = ("{0:N1}%" -f (([double]$fullCap / [double]$designCap) * 100))
}

# NPU - stricter matching only
$npuDevices = @($pnps | Where-Object {
    $_.FriendlyName -match 'Intel\(R\) AI Boost|AMD Ryzen AI|Ryzen AI|Qualcomm.*Hexagon|Neural Processing Unit|\bNPU\b'
})
$npuText = if ($npuDevices.Count -gt 0) {
    ($npuDevices | Select-Object -ExpandProperty FriendlyName -Unique) -join "; "
} else {
    "Not detected"
}

# Wi-Fi / Bluetooth compact
$wifi = Get-CimInstance Win32_NetworkAdapter | Where-Object {
    $_.PhysicalAdapter -eq $true -and $_.Name -match 'Wi-?Fi|Wireless|802\.11'
} | Select-Object -First 1

$bt = $pnps | Where-Object {
    $_.Class -eq 'Bluetooth' -and $_.FriendlyName -match 'Intel|Realtek|MediaTek|Qualcomm|Broadcom'
} | Select-Object -First 1

$wifiText = if ($wifi) { $wifi.Name } else { "Not detected" }
$btText = if ($bt) { $bt.FriendlyName } else { "Not detected" }

# Output
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("SOUNDHUB LAPTOP CHECK")
$lines.Add("")
$lines.Add("Model: $(SafeText $cs.Manufacturer) $(SafeText $cs.Model)")
$lines.Add("Serial: $(SafeText $bios.SerialNumber)")
$lines.Add("CPU: $(SafeText $cpu.Name)")
$lines.Add("Core/Thread: $($cpu.NumberOfCores)/$($cpu.NumberOfLogicalProcessors)")
$lines.Add("RAM: ${ramGB}GB $ramType $ramSpeed")
$lines.Add("")

$lines.Add("STORAGE:")
foreach ($x in $diskLines) { $lines.Add($x) }
$lines.Add("")

$lines.Add("GPU:")
foreach ($g in $gpuNames) { $lines.Add($g) }
$lines.Add("")

$lines.Add("DISPLAY:")
$lines.Add("Current: $currentMode")
$lines.Add("Native: $nativeMode")
$lines.Add("Resolution Class: $resolutionLabel")
$lines.Add("Panel: $panelMaker $panelID")
$lines.Add("Size: $screenSize")
$lines.Add("Touch: $touchText")
$lines.Add("HDR: $hdrSupport")
$lines.Add("Luminance: $maxLuminance")
$lines.Add("")

$lines.Add("BATTERY:")
$lines.Add("Design: $(if($designCap){$designCap}else{'N/A'}) mWh")
$lines.Add("Full Charge: $(if($fullCap){$fullCap}else{'N/A'}) mWh")
$lines.Add("Health: $battHealth")
$lines.Add("Cycle: $(if($null -ne $cycleCount){$cycleCount}else{'N/A'})")
$lines.Add("Charge: $(if($null -ne $currentPct){"$currentPct%"}else{'N/A'})")
$lines.Add("")

$lines.Add("NPU: $npuText")
$lines.Add("Wi-Fi: $wifiText")
$lines.Add("Bluetooth: $btText")
$lines.Add("Windows: $(SafeText $os.Caption) | Build $(SafeText $os.BuildNumber)")

$result = $lines -join "`r`n"

try {
    Set-Clipboard -Value $result
} catch {}

try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $result | Set-Content -Path (Join-Path $desktop "SoundHub_Laptop_Check.txt") -Encoding UTF8
} catch {}

Clear-Host
Write-Host $result
Write-Host ""
Write-Host "Copied to Clipboard."

Remove-Item $dxPath -Force -ErrorAction SilentlyContinue
