# SoundHub Laptop Check V2
# Windows PowerShell 5.1+ / PowerShell 7+
# Collects hardware information useful for checking used laptops.

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

function SafeText($value, $fallback = "N/A") {
    if ($null -eq $value) { return $fallback }
    $s = [string]$value
    if ([string]::IsNullOrWhiteSpace($s)) { return $fallback }
    return $s.Trim()
}

function BytesToGB($bytes) {
    if (-not $bytes) { return "N/A" }
    return [math]::Round(([double]$bytes / 1GB), 1)
}

function Decode-WmiChars($arr) {
    if (-not $arr) { return "N/A" }
    $chars = @($arr | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
    if ($chars.Count -eq 0) { return "N/A" }
    return (-join $chars).Trim()
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
        default {
            if ($code) { "TypeCode $code" } else { "N/A" }
        }
    }
}

function Get-FormFactorName($code) {
    switch ([int]$code) {
        8  { "DIMM" }
        12 { "SODIMM" }
        16 { "Chip" }
        default {
            if ($code) { "FormFactor $code" } else { "N/A" }
        }
    }
}

$cs      = Get-CimInstance Win32_ComputerSystem
$csp     = Get-CimInstance Win32_ComputerSystemProduct
$bios    = Get-CimInstance Win32_BIOS
$board   = Get-CimInstance Win32_BaseBoard
$os      = Get-CimInstance Win32_OperatingSystem
$cpuList = @(Get-CimInstance Win32_Processor)
$ramList = @(Get-CimInstance Win32_PhysicalMemory)
$gpuList = @(Get-CimInstance Win32_VideoController)
$pnps    = @(Get-PnpDevice -PresentOnly)
$disks   = @(Get-PhysicalDisk)

# DISPLAY / EDID
$monIDs    = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID)
$monParams = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams)

$displayInfo = @()

for ($i = 0; $i -lt $monIDs.Count; $i++) {
    $m = $monIDs[$i]

    $friendly     = Decode-WmiChars $m.UserFriendlyName
    $manufacturer = Decode-WmiChars $m.ManufacturerName
    $productCode  = Decode-WmiChars $m.ProductCodeID
    $serial       = Decode-WmiChars $m.SerialNumberID

    $sizeText = "N/A"

    if ($i -lt $monParams.Count) {
        $p = $monParams[$i]
        $wcm = [double]$p.MaxHorizontalImageSize
        $hcm = [double]$p.MaxVerticalImageSize

        if ($wcm -gt 0 -and $hcm -gt 0) {
            $diag = [math]::Sqrt(($wcm * $wcm) + ($hcm * $hcm)) / 2.54
            $sizeText = ("{0:N1} inch (EDID)" -f $diag)
        }
    }

    $displayInfo += [pscustomobject]@{
        FriendlyName = $friendly
        Manufacturer = $manufacturer
        ProductCode  = $productCode
        Serial       = $serial
        Size         = $sizeText
    }
}

# DXDIAG
$dxPath = Join-Path $env:TEMP "SoundHub_dxdiag.txt"
Remove-Item $dxPath -Force -ErrorAction SilentlyContinue

Start-Process -FilePath "dxdiag.exe" -ArgumentList "/dontskip /t `"$dxPath`"" -WindowStyle Hidden -Wait

$dxText = ""

if (Test-Path $dxPath) {
    $dxText = Get-Content $dxPath -Raw -ErrorAction SilentlyContinue
}

$nativeMode     = "N/A"
$currentMode    = "N/A"
$hdrSupport     = "N/A"
$maxLuminance   = "N/A"
$monitorModelDx = "N/A"

if ($dxText) {
    $match = [regex]::Match($dxText, '(?im)^\s*Native Mode:\s*(.+)$')
    if ($match.Success) {
        $nativeMode = $match.Groups[1].Value.Trim()
    }

    $match = [regex]::Match($dxText, '(?im)^\s*Current Mode:\s*(.+)$')
    if ($match.Success) {
        $currentMode = $match.Groups[1].Value.Trim()
    }

    $match = [regex]::Match($dxText, '(?im)^\s*HDR Support:\s*(.+)$')
    if ($match.Success) {
        $hdrSupport = $match.Groups[1].Value.Trim()
    }

    $match = [regex]::Match($dxText, '(?im)^\s*Monitor Model:\s*(.+)$')
    if ($match.Success) {
        $monitorModelDx = $match.Groups[1].Value.Trim()
    }

    $match = [regex]::Match($dxText, '(?im)Max Luminance\s*=\s*([0-9.]+)')
    if ($match.Success) {
        $maxLuminance = "$($match.Groups[1].Value) nits (DxDiag reported)"
    }
}

# BATTERY
$battStatic = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData)
$battFull   = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity)
$battCycle  = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount)
$battWin32  = @(Get-CimInstance Win32_Battery)

$designCap  = $null
$fullCap    = $null
$cycleCount = $null
$currentPct = $null

if ($battStatic.Count -gt 0) {
    $designCap = $battStatic[0].DesignedCapacity
}

if ($battFull.Count -gt 0) {
    $fullCap = $battFull[0].FullChargedCapacity
}

if ($battCycle.Count -gt 0) {
    $cycleCount = $battCycle[0].CycleCount
}

if ($battWin32.Count -gt 0) {
    $currentPct = $battWin32[0].EstimatedChargeRemaining
}

$battHealth = "N/A"

if ($designCap -and $fullCap -and [double]$designCap -gt 0) {
    $battHealth = ("{0:N1}%" -f (([double]$fullCap / [double]$designCap) * 100))
}

# TOUCH / NPU / WIFI / BLUETOOTH
$touchDevices = @(
    $pnps | Where-Object {
        $_.FriendlyName -match 'HID-compliant touch screen|touchscreen|touch screen'
    }
)

$touchText = if ($touchDevices.Count -gt 0) {
    "Yes"
} else {
    "No / Not detected"
}

$npuDevices = @(
    $pnps | Where-Object {
        $_.FriendlyName -match 'NPU|Neural Processing|Intel\(R\) AI Boost|Ryzen AI|Qualcomm.*Hexagon'
    }
)

$npuText = if ($npuDevices.Count -gt 0) {
    ($npuDevices | Select-Object -ExpandProperty FriendlyName -Unique) -join "; "
} else {
    "Not detected"
}

$wifiAdapters = @(
    Get-CimInstance Win32_NetworkAdapter | Where-Object {
        $_.PhysicalAdapter -eq $true -and $_.Name -match 'Wi-?Fi|Wireless|802\.11'
    }
)

$wifiText = if ($wifiAdapters.Count -gt 0) {
    ($wifiAdapters | Select-Object -ExpandProperty Name -Unique) -join "; "
} else {
    "Not detected"
}

$btDevices = @(
    $pnps | Where-Object {
        $_.Class -eq 'Bluetooth' -and $_.FriendlyName
    }
)

$btText = if ($btDevices.Count -gt 0) {
    ($btDevices | Select-Object -ExpandProperty FriendlyName -Unique | Select-Object -First 5) -join "; "
} else {
    "Not detected"
}

# OUTPUT
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("============================================================")
$lines.Add("SOUNDHUB LAPTOP CHECK V2")
$lines.Add("============================================================")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("")

$lines.Add("[SYSTEM]")
$lines.Add("Manufacturer: $(SafeText $cs.Manufacturer)")
$lines.Add("Model: $(SafeText $cs.Model)")
$lines.Add("System SKU: $(SafeText $cs.SystemSKUNumber)")
$lines.Add("Serial / Service Tag: $(SafeText $bios.SerialNumber)")
$lines.Add("UUID: $(SafeText $csp.UUID)")
$lines.Add("Baseboard: $(SafeText $board.Manufacturer) $(SafeText $board.Product)")
$lines.Add("BIOS Version: $(SafeText $bios.SMBIOSBIOSVersion)")
$lines.Add("BIOS Date: $(SafeText $bios.ReleaseDate)")
$lines.Add("")

$lines.Add("[CPU]")

foreach ($cpu in $cpuList) {
    $lines.Add("CPU: $(SafeText $cpu.Name)")
    $lines.Add("Cores / Threads: $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)")
    $lines.Add("Max Clock: $([math]::Round([double]$cpu.MaxClockSpeed / 1000, 2)) GHz")
}

$lines.Add("")

$lines.Add("[RAM]")
$lines.Add("Total RAM: $([math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)) GB")

$slot = 1

foreach ($r in $ramList) {
    $type  = Get-MemoryTypeName $r.SMBIOSMemoryType
    $form  = Get-FormFactorName $r.FormFactor
    $speed = if ($r.ConfiguredClockSpeed) {
        "$($r.ConfiguredClockSpeed) MT/s"
    } elseif ($r.Speed) {
        "$($r.Speed) MT/s"
    } else {
        "N/A"
    }

    $part = SafeText $r.PartNumber
    $manu = SafeText $r.Manufacturer

    $lines.Add("RAM ${slot}: $(BytesToGB $r.Capacity) GB | $type | $form | $speed | $manu | $part")
    $slot++
}

$lines.Add("")

$lines.Add("[STORAGE]")

if ($disks.Count -eq 0) {
    $lines.Add("No physical disk information returned.")
} else {
    foreach ($d in $disks) {
        $lines.Add("Disk: $(SafeText $d.FriendlyName)")
        $lines.Add("  Size: $(BytesToGB $d.Size) GB")
        $lines.Add("  Media: $(SafeText $d.MediaType)")
        $lines.Add("  Bus: $(SafeText $d.BusType)")
        $lines.Add("  Health: $(SafeText $d.HealthStatus)")
        $lines.Add("  Operational: $((@($d.OperationalStatus) -join ', '))")
    }
}

$lines.Add("")

$lines.Add("[GPU]")

foreach ($g in $gpuList) {
    $vram = if ($g.AdapterRAM -gt 0) {
        "$(BytesToGB $g.AdapterRAM) GB (Windows reported)"
    } else {
        "N/A"
    }

    $lines.Add("GPU: $(SafeText $g.Name)")
    $lines.Add("  VRAM: $vram")
    $lines.Add("  Driver: $(SafeText $g.DriverVersion)")
}

$lines.Add("")

$lines.Add("[DISPLAY]")
$lines.Add("Current Mode: $currentMode")
$lines.Add("Native Mode: $nativeMode")
$lines.Add("HDR Support: $hdrSupport")
$lines.Add("DxDiag Monitor Model: $monitorModelDx")
$lines.Add("Max Luminance: $maxLuminance")

if ($displayInfo.Count -eq 0) {
    $lines.Add("EDID Monitor Info: Not available")
} else {
    $idx = 1

    foreach ($m in $displayInfo) {
        $lines.Add("Monitor ${idx}:")
        $lines.Add("  Name: $($m.FriendlyName)")
        $lines.Add("  Manufacturer ID: $($m.Manufacturer)")
        $lines.Add("  Panel/Product ID: $($m.ProductCode)")
        $lines.Add("  Panel Serial: $($m.Serial)")
        $lines.Add("  Approx Size: $($m.Size)")
        $idx++
    }
}

$lines.Add("Touch: $touchText")
$lines.Add("")

$lines.Add("[BATTERY]")

if ($battStatic.Count -eq 0 -and $battWin32.Count -eq 0) {
    $lines.Add("Battery data: Not available")
} else {
    $designText = if ($designCap) { $designCap } else { "N/A" }
    $fullText   = if ($fullCap) { $fullCap } else { "N/A" }
    $cycleText  = if ($null -ne $cycleCount) { $cycleCount } else { "N/A" }
    $chargeText = if ($null -ne $currentPct) { "$currentPct%" } else { "N/A" }

    $lines.Add("Design Capacity: $designText mWh")
    $lines.Add("Full Charge Capacity: $fullText mWh")
    $lines.Add("Battery Health: $battHealth")
    $lines.Add("Cycle Count: $cycleText")
    $lines.Add("Current Charge: $chargeText")
}

$lines.Add("")

$lines.Add("[AI / NPU]")
$lines.Add("NPU: $npuText")
$lines.Add("")

$lines.Add("[NETWORK]")
$lines.Add("Wi-Fi: $wifiText")
$lines.Add("Bluetooth: $btText")
$lines.Add("")

$lines.Add("[WINDOWS]")
$lines.Add("OS: $(SafeText $os.Caption)")
$lines.Add("Version: $(SafeText $os.Version)")
$lines.Add("Build: $(SafeText $os.BuildNumber)")
$lines.Add("Architecture: $(SafeText $os.OSArchitecture)")
$lines.Add("Install Date: $(SafeText $os.InstallDate)")
$lines.Add("")

$lines.Add("[IMPORTANT NOTES]")
$lines.Add("- Max Luminance is a DxDiag/Windows-reported value. It is not guaranteed to equal the manufacturer's official panel brightness.")
$lines.Add("- Model year should be verified from the exact model/SKU, not guessed from BIOS date.")
$lines.Add("- GPU VRAM reported by Win32_VideoController can be inaccurate on some modern GPUs/iGPUs.")
$lines.Add("- Cycle Count depends on firmware support. N/A does not mean the battery has zero cycles.")
$lines.Add("- SSD Health here is Windows Storage health status, not full SMART wear percentage.")
$lines.Add("============================================================")

$result = $lines -join "`r`n"

try {
    Set-Clipboard -Value $result
    $clipStatus = "YES"
} catch {
    $clipStatus = "NO"
}

try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $outPath = Join-Path $desktop "SoundHub_Laptop_Check.txt"
    $result | Set-Content -Path $outPath -Encoding UTF8
} catch {
    $outPath = "Could not save"
}

Clear-Host
Write-Host $result
Write-Host ""
Write-Host "============================================================"
Write-Host "COPIED TO CLIPBOARD: $clipStatus"
Write-Host "BACKUP TXT: $outPath"
Write-Host "Send the result to ChatGPT and add: Price / Warranty / Cosmetic condition / Accessories."
Write-Host "============================================================"

Remove-Item $dxPath -Force -ErrorAction SilentlyContinue
