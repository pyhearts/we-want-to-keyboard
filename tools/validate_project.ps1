param(
    [string]$Project = "window/window-gun"
)

$ErrorCount = 0
$WarningCount = 0
$ValidNoteTypes = @("normal", "moving", "hold")
$ValidEventTypes = @(
    "window",
    "window_moving_linear",
    "window_moving_smooth",
    "image",
    "image_moving_linear",
    "image_moving_smooth"
)

function Add-Error([string]$Message) {
    $script:ErrorCount += 1
    Write-Host "ERROR: $Message"
}

function Add-Warning([string]$Message) {
    $script:WarningCount += 1
    Write-Host "WARNING: $Message"
}

function Test-Number($Value) {
    return $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [int32] -or
        $Value -is [int64] -or
        $Value -is [single] -or
        $Value -is [double] -or
        $Value -is [decimal]
}

function Test-FieldNumber($Data, [string]$Where, [string]$Key, [bool]$Required, [Nullable[double]]$Minimum) {
    $Property = $Data.PSObject.Properties[$Key]
    if ($null -eq $Property) {
        if ($Required) {
            Add-Error "$Where`: missing required field '$Key'"
        }
        return
    }
    if (-not (Test-Number $Property.Value)) {
        Add-Error "$Where`: field '$Key' must be a number"
        return
    }
    if ($null -ne $Minimum -and [double]$Property.Value -lt $Minimum) {
        Add-Error "$Where`: field '$Key' must be >= $Minimum"
    }
}

function Test-Note($Note, [string]$SongName, [int]$Index) {
    $Where = "$SongName chart note[$Index]"
    if ($null -eq $Note -or $Note -isnot [pscustomobject]) {
        Add-Error "$Where`: note must be an object"
        return
    }

    $TypeProperty = $Note.PSObject.Properties["type"]
    $NoteType = if ($null -eq $TypeProperty) { "normal" } else { [string]$TypeProperty.Value }
    if ($ValidNoteTypes -notcontains $NoteType) {
        Add-Error "$Where`: unknown type '$NoteType'"
    }

    Test-FieldNumber $Note $Where "time" $true 0.0
    if ($NoteType -eq "normal" -or $NoteType -eq "moving") {
        Test-FieldNumber $Note $Where "x" $true $null
        Test-FieldNumber $Note $Where "y" $true $null
    }
    if ($NoteType -eq "moving") {
        Test-FieldNumber $Note $Where "move_duration" $false 0.01
        if ($null -ne $Note.PSObject.Properties["start_x"] -or $null -ne $Note.PSObject.Properties["start_y"]) {
            Test-FieldNumber $Note $Where "start_x" $true $null
            Test-FieldNumber $Note $Where "start_y" $true $null
        }
        if ($null -ne $Note.PSObject.Properties["curve_control_x"] -or $null -ne $Note.PSObject.Properties["curve_control_y"]) {
            Test-FieldNumber $Note $Where "curve_control_x" $true $null
            Test-FieldNumber $Note $Where "curve_control_y" $true $null
        }
    }
    if ($NoteType -eq "hold") {
        Test-FieldNumber $Note $Where "duration" $false 0.01
        Test-FieldNumber $Note $Where "beat_division" $false 1.0
    }
}

function Test-Event($Event, [string]$SongName, [int]$Index) {
    $Where = "$SongName chart event[$Index]"
    if ($null -eq $Event -or $Event -isnot [pscustomobject]) {
        Add-Error "$Where`: event must be an object"
        return
    }

    $TypeProperty = $Event.PSObject.Properties["type"]
    $EventType = if ($null -eq $TypeProperty) { "" } else { [string]$TypeProperty.Value }
    if ($ValidEventTypes -notcontains $EventType) {
        Add-Error "$Where`: unknown type '$EventType'"
    }

    Test-FieldNumber $Event $Where "time" $true 0.0
    Test-FieldNumber $Event $Where "x" $true $null
    Test-FieldNumber $Event $Where "y" $true $null
    Test-FieldNumber $Event $Where "width" $false 0.01
    Test-FieldNumber $Event $Where "height" $false 0.01
    Test-FieldNumber $Event $Where "duration" $false 0.01
    Test-FieldNumber $Event $Where "opacity" $false 0.0
}

$ProjectPath = Resolve-Path -LiteralPath $Project -ErrorAction SilentlyContinue
if ($null -eq $ProjectPath) {
    Add-Error "Project directory not found: $Project"
} else {
    $MusicPath = Join-Path $ProjectPath "assets/musics"
    if (-not (Test-Path -LiteralPath $MusicPath -PathType Container)) {
        Add-Error "Music directory not found: $MusicPath"
    } else {
        $SongDirs = Get-ChildItem -LiteralPath $MusicPath -Directory
        if ($SongDirs.Count -eq 0) {
            Add-Warning "No song folders found in $MusicPath"
        }

        foreach ($SongDir in $SongDirs) {
            $SongName = $SongDir.Name
            foreach ($FileName in @("chart.json", "Res.tres", "img.png", "$SongName.mp3")) {
                $Path = Join-Path $SongDir.FullName $FileName
                if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                    Add-Error "$SongName`: missing $FileName"
                }
            }

            $ChartPath = Join-Path $SongDir.FullName "chart.json"
            if (-not (Test-Path -LiteralPath $ChartPath -PathType Leaf)) {
                continue
            }

            try {
                $Chart = Get-Content -LiteralPath $ChartPath -Raw -Encoding UTF8 | ConvertFrom-Json
            } catch {
                Add-Error "$SongName`: chart.json parse failed: $($_.Exception.Message)"
                continue
            }

            if ($null -eq $Chart -or $Chart -isnot [pscustomobject]) {
                Add-Error "$SongName`: chart root must be an object"
                continue
            }

            $Notes = $Chart.PSObject.Properties["notes"].Value
            $Events = $Chart.PSObject.Properties["events"].Value
            if ($null -eq $Notes) { $Notes = @() }
            if ($null -eq $Events) { $Events = @() }
            if ($Notes -isnot [array]) {
                Add-Error "$SongName`: 'notes' must be an array"
                $Notes = @()
            }
            if ($Events -isnot [array]) {
                Add-Error "$SongName`: 'events' must be an array"
                $Events = @()
            }

            for ($i = 0; $i -lt $Notes.Count; $i++) {
                Test-Note $Notes[$i] $SongName $i
            }
            for ($i = 0; $i -lt $Events.Count; $i++) {
                Test-Event $Events[$i] $SongName $i
            }
        }
    }
}

if ($ErrorCount -gt 0) {
    Write-Host "Validation failed: $ErrorCount error(s), $WarningCount warning(s)."
    exit 1
}

Write-Host "Validation passed: $WarningCount warning(s)."
