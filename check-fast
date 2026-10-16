# SoundHub Laptop Check FAST
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$WEBHOOK = "https://script.google.com/macros/s/AKfycbxk6lsk_hJH4dDiIu2XgucqRdFB8paVjqo36cP6aVEPj3RAvWYMPqXbmApc5z2PSmMN/exec"

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

function Get-ResolutionLabel($w, $h) {
    if (-not $w -or -not $h) { return "N/A" }
    $key = "$w`x$h"
    switch ($key) {
        "1366x768"  { "HD" }
        "1600x900"  { "HD+" }
        "1920x1080" { "Full HD (FHD)" }
        "1920x1200" { "WUXGA / FHD+" }
        "1920x1280" { "FHD+ 3:2" }
        "2160x1350" { "2K+" }
        "2240x1400" { "2.2K" }
        "2256x1504" { "2K+ / 2.2K" }
        "2496x1664" { "2.5K-class" }
        "2560x1440" { "QHD / 2K" }
        "2560x1600" { "QHD+ / 2.5K" }
        "2880x1800" { "2.8K" }
        "2880x1920" { "3K" }
        "3000x2000" { "3K" }
        "3072x1920" { "3K" }
        "3200x2000" { "3.2K" }
        "3456x2234" { "3.5K-class" }
        "3840x2160" { "4K UHD" }
        "3840x2400" { "4K UHD+ / WQUXGA" }
        default {
            if ($w -ge 3800 -and $h -ge 2100) { "4K-class" }
            elseif ($w -ge 2880 -and $h -ge 1800) { "3K-class" }
            elseif ($w -ge 2500 -and $h -ge 1400) { "2.5K / QHD-class" }
            elseif ($w -ge 2000 -and $h -ge 1300) { "2K-class" }
            else { "$w x $h" }
        }
    }
}

function Get-GpuType($name) {
    if (-not $name) { return "Unknown" }
    if ($name -match 'NVIDIA.*(RTX|GTX|Quadro|A[0-9]{3,4}|T[0-9]{3,4})') { return "Dedicated" }
    if ($name -match 'AMD Radeon RX|Radeon Pro|FirePro') { return "Dedicated" }
    if ($name -match 'Intel.*(UHD|Iris|Xe|Arc)|AMD Radeon.*(Graphics|[0-9]{3}M|[0-9]{3}S)') { return "Integrated" }
    return "Unknown"
}

function Get-PanelTypeHint($maker, $id) {
    $s = "$maker $id"
    if ($s -match 'OLED|AMOLED|ATNA') { return "OLED / likely OLED" }
    return "Unknown"
}

$cs      = Get-CimInstance Win32_ComputerSystem
$bios    = Get-CimInstance Win32_BIOS
$os      = Get-CimInstance Win32_OperatingSystem
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramList = @(Get-CimInstance Win32_PhysicalMemory)
$gpuList = @(Get-CimInstance Win32_VideoController)
$disks   = @(Get-PhysicalDisk)
$pnps    = @(Get-PnpDevice -PresentOnly)

$ramGB = [math]::Round([double]$cs.TotalPhysicalMemory / 1GB)
$ramType = "N/A"
$ramSpeed = "N/A"
if ($ramList.Count -gt 0) {
    $ramType = Get-MemoryTypeName $ramList[0].SMBIOSMemoryType
    if ($ramList[0].ConfiguredClockSpeed) { $ramSpeed = "$($ramList[0].ConfiguredClockSpeed) MT/s" }
    elseif ($ramList[0].Speed) { $ramSpeed = "$($ramList[0].Speed) MT/s" }
}

$diskLines = @()
foreach ($d in $disks) {
    $sizeGB = [math]::Round([double]$d.Size / 1GB)
    $sizeLabel = if ($sizeGB -ge 1800) { "2TB" } elseif ($sizeGB -ge 900) { "1TB" } elseif ($sizeGB -ge 450) { "512GB" } elseif ($sizeGB -ge 220) { "256GB" } elseif ($sizeGB -ge 110) { "128GB" } else { "$sizeGB GB" }
    $bus = SafeText $d.BusType
    if ($bus -eq "RAID" -and $d.FriendlyName -match "NVMe") { $bus = "NVMe" }
    $diskLines += "$(SafeText $d.FriendlyName) | $sizeLabel | $bus | Health: $(SafeText $d.HealthStatus)"
}

$gpuLines = @()
$dedicatedGpu = "No / Not detected"
foreach ($g in $gpuList) {
    $gpuName = SafeText $g.Name
    $gpuType = Get-GpuType $gpuName
    $vramText = "N/A"
    if ($g.AdapterRAM -gt 0) {
        $vramGB = [math]::Round([double]$g.AdapterRAM / 1GB, 1)
        $vramText = "${vramGB}GB reported"
    }
    $gpuLines += "$gpuName | $gpuType | VRAM: $vramText"
    if ($gpuType -eq "Dedicated") { $dedicatedGpu = "Yes" }
}

$displayGpu = $gpuList | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution } | Select-Object -First 1
$screenW = $displayGpu.CurrentHorizontalResolution
$screenH = $displayGpu.CurrentVerticalResolution
$screenHz = $displayGpu.CurrentRefreshRate
$resolutionText = if ($screenW -and $screenH) { "$screenW x $screenH" } else { "N/A" }
$refreshText = if ($screenHz) { "$screenHz Hz" } else { "N/A" }
$resolutionClass = Get-ResolutionLabel $screenW $screenH

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
        $inch = [math]::Sqrt(($wcm * $wcm) + ($hcm * $hcm)) / 2.54
        $screenSize = ("{0:N1} inch" -f $inch)
    }
}
$panelType = Get-PanelTypeHint $panelMaker $panelID

$touch = @($pnps | Where-Object { $_.FriendlyName -match 'HID-compliant touch screen|touchscreen|touch screen' })
$touchText = if ($touch.Count -gt 0) { "Yes" } else { "No / Not detected" }

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

$npuDevices = @($pnps | Where-Object { $_.FriendlyName -match 'Intel\(R\) AI Boost|AMD Ryzen AI|Ryzen AI|Qualcomm.*Hexagon|Neural Processing Unit|\bNPU\b' })
$npuText = if ($npuDevices.Count -gt 0) { ($npuDevices | Select-Object -ExpandProperty FriendlyName -Unique) -join "; " } else { "Not detected" }

$wifi = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true -and $_.Name -match 'Wi-?Fi|Wireless|802\.11' } | Select-Object -First 1
$bt = $pnps | Where-Object { $_.Class -eq 'Bluetooth' -and $_.FriendlyName -match 'Intel|Realtek|MediaTek|Qualcomm|Broadcom' } | Select-Object -First 1
$wifiText = if ($wifi) { $wifi.Name } else { "Not detected" }
$btText = if ($bt) { $bt.FriendlyName } else { "Not detected" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("SOUNDHUB LAPTOP CHECK FAST")
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
foreach ($g in $gpuLines) { $lines.Add($g) }
$lines.Add("Dedicated GPU: $dedicatedGpu")
$lines.Add("")
$lines.Add("DISPLAY:")
$lines.Add("Resolution: $resolutionText")
$lines.Add("Refresh Rate: $refreshText")
$lines.Add("Resolution Class: $resolutionClass")
$lines.Add("Panel: $panelMaker $panelID")
$lines.Add("Panel Type: $panelType")
$lines.Add("Size: $screenSize")
$lines.Add("Touch: $touchText")
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

try { Set-Clipboard -Value $result } catch {}

$logStatus = "SKIPPED"
if ($WEBHOOK) {
    $payload = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        model     = "$(SafeText $cs.Manufacturer) $(SafeText $cs.Model)"
        serial    = "$(SafeText $bios.SerialNumber)"
        raw       = $result
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri $WEBHOOK -Method Post -ContentType "application/json" -Body $payload | Out-Null
        $logStatus = "OK"
    } catch {
        $logStatus = "FAILED"
    }
}

Clear-Host
Write-Host $result
Write-Host ""
Write-Host "Copied to Clipboard."
Write-Host "Google Sheet Log: $logStatus"
