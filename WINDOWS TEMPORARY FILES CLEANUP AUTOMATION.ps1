<#
.SYNOPSIS
Windows Temporary Files Cleanup Automation

.DESCRIPTION
Cleans contents of selected Windows temporary/cache folders.

Cleanup locations:
  1. C:\Users\XXX\AppData\Local\Temp
  2. C:\Windows\Temp
  3. C:\Windows\Prefetch
  4. C:\Users\XXX\AppData\Local\Microsoft\Windows\INetCache

Features:
  - Administrator check
  - Pre-flight PowerShell syntax validation
  - Detects accidental Markdown formatting
  - Deletes files first
  - Deletes directories afterward
  - Skips locked/in-use/protected items
  - Records skipped items and errors
  - Folder-wise cleanup summary
  - Accurate execution duration including seconds
  - Colorful HTML email report
  - Gmail SMTP support
  - Does NOT delete root cleanup folders

.NOTES
Windows Temp Folder Cleanup Automation
Developed by Ashadeep Parida
Generated automatically by PowerShell
#>

# ============================================================
# CONFIGURATION
# ============================================================

$CleanupFolders = @(
    "C:\Users\XXX\AppData\Local\Temp",
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "C:\Users\XXXX\AppData\Local\Microsoft\Windows\INetCache"
)

# ============================================================
# EMAIL CONFIGURATION
# ============================================================

$SmtpServer = "smtp.gmail.com"
$SmtpPort   = 587

$FromEmail = "email ID"
$ToEmail   = "email ID"
$EmailUser = "email ID"

# IMPORTANT: enter a NEW Gmail App Password here.
$EmailPassword = "password"

$Subject = "Windows Temporary Files Cleanup Report - $env:COMPUTERNAME"

# ============================================================
# START TIME
# ============================================================

$StartTime = Get-Date

# ============================================================
# FUNCTION - WRITE LOG
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$TimeStamp] $Message" -ForegroundColor $Color
}

# ============================================================
# ADMINISTRATOR CHECK
# ============================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
$IsAdministrator = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdministrator) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "ERROR: Administrator privileges are required." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ============================================================
# PRE-FLIGHT VALIDATION
# ============================================================

$ScriptPath = $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    Write-Host "ERROR: Unable to determine the PowerShell script path." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    Write-Host "ERROR: Script file was not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "PRE-FLIGHT SCRIPT VALIDATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$ValidationFailed = $false
$ThreeBackticks = ('`' * 3)

try {
    $ScriptLines = Get-Content -LiteralPath $ScriptPath -ErrorAction Stop
    $LineNumber = 0

    foreach ($Line in $ScriptLines) {
        $LineNumber++
        if ($Line.Contains($ThreeBackticks)) {
            Write-Host "ERROR: Markdown formatting detected on line $LineNumber." -ForegroundColor Red
            Write-Host $Line -ForegroundColor Yellow
            $ValidationFailed = $true
        }
    }
}
catch {
    Write-Host "ERROR: Unable to read script for validation." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

if ($ValidationFailed) {
    Write-Host "Cleanup has NOT started." -ForegroundColor Red
    exit 1
}

$ParseErrors = @()
try {
    [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath,
        [ref]$null,
        [ref]$ParseErrors
    ) | Out-Null
}
catch {
    Write-Host "ERROR: PowerShell parser failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

if ($ParseErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "POWERSHELL SYNTAX ERRORS DETECTED" -ForegroundColor Red
    Write-Host ""
    foreach ($ParseError in $ParseErrors) {
        Write-Host ("Line {0}: {1}" -f $ParseError.Extent.StartLineNumber, $ParseError.Message) -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Cleanup has NOT started." -ForegroundColor Red
    exit 1
}

Write-Host "Markdown formatting check: PASSED" -ForegroundColor Green
Write-Host "PowerShell syntax check: PASSED" -ForegroundColor Green
Write-Host ""

# ============================================================
# INITIALIZE COUNTERS
# ============================================================

$TotalFilesFound     = 0
$TotalFilesDeleted   = 0
$TotalFilesSkipped   = 0
$TotalFoldersFound   = 0
$TotalFoldersDeleted = 0
$TotalFoldersSkipped = 0
$TotalErrors         = 0

$SkippedItems = New-Object System.Collections.Generic.List[object]
$FolderSummary = New-Object System.Collections.Generic.List[object]

# ============================================================
# START CLEANUP
# ============================================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "WINDOWS TEMPORARY FILES CLEANUP AUTOMATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Computer Name : $env:COMPUTERNAME" "Cyan"
Write-Log "User          : $env:USERNAME" "Cyan"
Write-Log "Start Time    : $StartTime" "Cyan"
Write-Host ""

foreach ($CleanupFolder in $CleanupFolders) {

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "Cleanup Location: $CleanupFolder" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    $FolderFilesFound = 0
    $FolderFilesDeleted = 0
    $FolderFilesSkipped = 0
    $FolderDirsFound = 0
    $FolderDirsDeleted = 0
    $FolderDirsSkipped = 0

    if (-not (Test-Path -LiteralPath $CleanupFolder -PathType Container)) {
        Write-Log "Folder does not exist. Skipping." "Yellow"
        $FolderSummary.Add([PSCustomObject]@{
            Folder = $CleanupFolder
            FilesFound = 0
            FilesDeleted = 0
            FilesSkipped = 0
            FoldersFound = 0
            FoldersDeleted = 0
            FoldersSkipped = 0
            Status = "Folder Not Found"
        })
        continue
    }

    try {
        $Files = @(Get-ChildItem -LiteralPath $CleanupFolder -File -Force -Recurse -ErrorAction SilentlyContinue)
    }
    catch {
        $Files = @()
    }

    $FolderFilesFound = $Files.Count
    $TotalFilesFound += $FolderFilesFound
    Write-Log "Files found: $FolderFilesFound" "White"

    foreach ($File in $Files) {
        try {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
            $FolderFilesDeleted++
            $TotalFilesDeleted++
        }
        catch {
            $FolderFilesSkipped++
            $TotalFilesSkipped++
            $TotalErrors++
            $SkippedItems.Add([PSCustomObject]@{
                Type = "File"
                Folder = $CleanupFolder
                Path = $File.FullName
                Reason = $_.Exception.Message
            })
        }
    }

    Write-Log "Files deleted: $FolderFilesDeleted" "Green"
    Write-Log "Files skipped: $FolderFilesSkipped" "Yellow"

    try {
        $Directories = @(Get-ChildItem -LiteralPath $CleanupFolder -Directory -Force -Recurse -ErrorAction SilentlyContinue)
    }
    catch {
        $Directories = @()
    }

    $FolderDirsFound = $Directories.Count
    $TotalFoldersFound += $FolderDirsFound

    $DirectoriesSorted = @($Directories | Sort-Object { $_.FullName.Length } -Descending)

    foreach ($Directory in $DirectoriesSorted) {
        try {
            Remove-Item -LiteralPath $Directory.FullName -Force -Recurse -ErrorAction Stop
            $FolderDirsDeleted++
            $TotalFoldersDeleted++
        }
        catch {
            $FolderDirsSkipped++
            $TotalFoldersSkipped++
            $TotalErrors++
            $SkippedItems.Add([PSCustomObject]@{
                Type = "Folder"
                Folder = $CleanupFolder
                Path = $Directory.FullName
                Reason = $_.Exception.Message
            })
        }
    }

    Write-Log "Folders found: $FolderDirsFound" "White"
    Write-Log "Folders deleted: $FolderDirsDeleted" "Green"
    Write-Log "Folders skipped: $FolderDirsSkipped" "Yellow"

    $FolderStatus = if (($FolderFilesSkipped -gt 0) -or ($FolderDirsSkipped -gt 0)) {
        "Completed with Skips"
    }
    else {
        "Completed"
    }

    $FolderSummary.Add([PSCustomObject]@{
        Folder = $CleanupFolder
        FilesFound = $FolderFilesFound
        FilesDeleted = $FolderFilesDeleted
        FilesSkipped = $FolderFilesSkipped
        FoldersFound = $FolderDirsFound
        FoldersDeleted = $FolderDirsDeleted
        FoldersSkipped = $FolderDirsSkipped
        Status = $FolderStatus
    })
}

# ============================================================
# END TIME / DURATION
# ============================================================

$EndTime = Get-Date
$Duration = $EndTime - $StartTime
$DurationHours = [int]$Duration.TotalHours
$DurationMinutes = $Duration.Minutes
$DurationSeconds = $Duration.Seconds
$DurationText = "$DurationHours hour(s) $DurationMinutes minute(s) $DurationSeconds second(s)"

# ============================================================
# OVERALL STATUS
# ============================================================

if ($TotalErrors -eq 0) {
    $OverallStatus = "SUCCESS"
    $StatusColor = "#198754"
    $StatusText = "Cleanup completed successfully."
}
elseif (($TotalFilesDeleted -gt 0) -or ($TotalFoldersDeleted -gt 0)) {
    $OverallStatus = "COMPLETED WITH SKIPS"
    $StatusColor = "#fd7e14"
    $StatusText = "Cleanup completed, but some items could not be deleted."
}
else {
    $OverallStatus = "COMPLETED WITH ERRORS"
    $StatusColor = "#dc3545"
    $StatusText = "Cleanup completed, but errors prevented deletion."
}

# ============================================================
# CONSOLE SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "CLEANUP SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Overall Status      : $OverallStatus" -ForegroundColor White
Write-Host "Files Found         : $TotalFilesFound" -ForegroundColor White
Write-Host "Files Deleted       : $TotalFilesDeleted" -ForegroundColor Green
Write-Host "Files Skipped       : $TotalFilesSkipped" -ForegroundColor Yellow
Write-Host "Folders Found       : $TotalFoldersFound" -ForegroundColor White
Write-Host "Folders Deleted     : $TotalFoldersDeleted" -ForegroundColor Green
Write-Host "Folders Skipped     : $TotalFoldersSkipped" -ForegroundColor Yellow
Write-Host "Errors              : $TotalErrors" -ForegroundColor Red
Write-Host "Duration            : $DurationText" -ForegroundColor Cyan
Write-Host "Start Time          : $StartTime" -ForegroundColor White
Write-Host "End Time            : $EndTime" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Cyan

# ============================================================
# HTML ENCODING FUNCTION
# ============================================================

function ConvertTo-HtmlSafe {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

# ============================================================
# BUILD FOLDER SUMMARY HTML
# ============================================================

$FolderSummaryHtml = ""

foreach ($Summary in $FolderSummary) {
    $RowColor = "#ffffff"
    if ($Summary.Status -eq "Completed with Skips") { $RowColor = "#fff3cd" }
    if ($Summary.Status -eq "Folder Not Found") { $RowColor = "#f8d7da" }

    $SafeFolder = ConvertTo-HtmlSafe $Summary.Folder
    $SafeStatus = ConvertTo-HtmlSafe $Summary.Status

    $FolderSummaryHtml += @"
<tr style="background-color:$RowColor;">
    <td style="padding:10px;border:1px solid #dee2e6;word-break:break-all;">$SafeFolder</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;">$($Summary.FilesFound)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;color:#198754;font-weight:bold;">$($Summary.FilesDeleted)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;color:#dc3545;font-weight:bold;">$($Summary.FilesSkipped)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;">$($Summary.FoldersFound)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;color:#198754;font-weight:bold;">$($Summary.FoldersDeleted)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;color:#dc3545;font-weight:bold;">$($Summary.FoldersSkipped)</td>
    <td style="padding:10px;border:1px solid #dee2e6;text-align:center;font-weight:bold;">$SafeStatus</td>
</tr>
"@
}

# ============================================================
# BUILD SKIPPED ITEMS HTML
# ============================================================

$SkippedHtml = ""

if ($SkippedItems.Count -eq 0) {
    $SkippedHtml = @"
<tr>
    <td colspan="4" style="padding:15px;text-align:center;color:#198754;font-weight:bold;">No files or folders were skipped.</td>
</tr>
"@
}
else {
    foreach ($Skipped in $SkippedItems) {
        $SafeType = ConvertTo-HtmlSafe $Skipped.Type
        $SafeFolder = ConvertTo-HtmlSafe $Skipped.Folder
        $SafePath = ConvertTo-HtmlSafe $Skipped.Path
        $SafeReason = ConvertTo-HtmlSafe $Skipped.Reason

        $SkippedHtml += @"
<tr>
    <td style="padding:9px;border:1px solid #dee2e6;">$SafeType</td>
    <td style="padding:9px;border:1px solid #dee2e6;word-break:break-all;">$SafeFolder</td>
    <td style="padding:9px;border:1px solid #dee2e6;word-break:break-all;">$SafePath</td>
    <td style="padding:9px;border:1px solid #dee2e6;word-break:break-word;">$SafeReason</td>
</tr>
"@
    }
}

# ============================================================
# HTML EMAIL
# ============================================================

$EmailBody = @"
<html>
<head>
<meta charset="UTF-8">
<style>
body { margin:0; padding:0; background:#f4f7fb; font-family:Segoe UI,Arial,Helvetica,sans-serif; color:#212529; }
.container { width:94%; max-width:1250px; margin:25px auto; background:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 4px 18px rgba(0,0,0,0.12); }
.header { background:linear-gradient(135deg,#0d6efd,#6610f2); color:#ffffff; padding:30px; text-align:center; }
.header h1 { margin:0; font-size:28px; }
.header p { margin:8px 0 0 0; font-size:14px; opacity:0.92; }
.status { margin:25px; padding:20px; border-radius:10px; background:$StatusColor; color:#ffffff; text-align:center; }
.status h2 { margin:0; font-size:24px; }
.status p { margin:8px 0 0 0; }
.metrics { display:flex; flex-wrap:wrap; gap:12px; padding:0 25px 20px 25px; }
.metric { flex:1; min-width:145px; background:#f8f9fa; border-radius:10px; padding:18px; text-align:center; border:1px solid #e9ecef; }
.metric .number { font-size:25px; font-weight:bold; color:#0d6efd; }
.metric .label { margin-top:5px; font-size:13px; color:#6c757d; }
.section { padding:10px 25px 25px 25px; }
.section h2 { color:#343a40; border-left:5px solid #0d6efd; padding-left:10px; }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { background:#212529; color:#ffffff; padding:11px; border:1px solid #343a40; text-align:center; }
td { vertical-align:top; }
.info-table td { padding:10px; border-bottom:1px solid #eeeeee; }
.info-label { font-weight:bold; width:180px; color:#495057; }
.footer { background:#212529; color:#ffffff; text-align:center; padding:22px; font-size:13px; }
.footer strong { color:#ffffff; }
.small { color:#adb5bd; font-size:12px; margin-top:6px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Windows Temporary Files Cleanup</h1>
<p>Automated Windows Temp Folder Cleanup Report</p>
</div>
<div class="status">
<h2>$OverallStatus</h2>
<p>$StatusText</p>
</div>
<div class="metrics">
<div class="metric"><div class="number">$TotalFilesFound</div><div class="label">Files Found</div></div>
<div class="metric"><div class="number">$TotalFilesDeleted</div><div class="label">Files Deleted</div></div>
<div class="metric"><div class="number">$TotalFilesSkipped</div><div class="label">Files Skipped</div></div>
<div class="metric"><div class="number">$TotalFoldersFound</div><div class="label">Folders Found</div></div>
<div class="metric"><div class="number">$TotalFoldersDeleted</div><div class="label">Folders Deleted</div></div>
<div class="metric"><div class="number">$TotalFoldersSkipped</div><div class="label">Folders Skipped</div></div>
<div class="metric"><div class="number">$TotalErrors</div><div class="label">Errors</div></div>
</div>
<div class="section">
<h2>Execution Details</h2>
<table class="info-table">
<tr><td class="info-label">Computer Name</td><td>$env:COMPUTERNAME</td></tr>
<tr><td class="info-label">User</td><td>$env:USERNAME</td></tr>
<tr><td class="info-label">Start Time</td><td>$StartTime</td></tr>
<tr><td class="info-label">End Time</td><td>$EndTime</td></tr>
<tr><td class="info-label">Duration</td><td><strong>$DurationText</strong></td></tr>
</table>
</div>
<div class="section">
<h2>Cleanup Location Summary</h2>
<table>
<tr><th>Cleanup Folder</th><th>Files Found</th><th>Files Deleted</th><th>Files Skipped</th><th>Folders Found</th><th>Folders Deleted</th><th>Folders Skipped</th><th>Status</th></tr>
$FolderSummaryHtml
</table>
</div>
<div class="section">
<h2>Skipped / Failed Items</h2>
<table>
<tr><th>Type</th><th>Cleanup Folder</th><th>Path</th><th>Reason</th></tr>
$SkippedHtml
</table>
</div>
<div class="section">
<h2>Cleanup Locations</h2>
<ul>
<li>C:\Users\ashad\AppData\Local\Temp</li>
<li>C:\Windows\Temp</li>
<li>C:\Windows\Prefetch</li>
<li>C:\Users\ashad\AppData\Local\Microsoft\Windows\INetCache</li>
</ul>
<p>Locked, in-use, protected, or permission-restricted items are automatically skipped and reported above.</p>
</div>
<div class="footer">
<strong>Windows Temp Folder Cleanup Automation</strong>
<div class="small">Developed by Ashadeep Parida</div>
<div class="small">Generated automatically by PowerShell</div>
</div>
</div>
</body>
</html>
"@

# ============================================================
# SEND EMAIL
# ============================================================

Write-Host ""
Write-Host "Preparing email notification..." -ForegroundColor Cyan

if ($EmailPassword -eq "YOUR_NEW_GMAIL_APP_PASSWORD") {
    Write-Host "Email was not sent because the Gmail App Password has not been configured." -ForegroundColor Yellow
}
else {
    try {
        $SecurePassword = ConvertTo-SecureString $EmailPassword -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($EmailUser, $SecurePassword)

        Send-MailMessage `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -UseSsl `
            -Credential $Credential `
            -From $FromEmail `
            -To $ToEmail `
            -Subject $Subject `
            -Body $EmailBody `
            -BodyAsHtml `
            -ErrorAction Stop

        Write-Host "EMAIL SENT SUCCESSFULLY" -ForegroundColor Green
    }
    catch {
        Write-Host "EMAIL SEND FAILED" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}

# ============================================================
# FINAL SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "WINDOWS TEMP CLEANUP COMPLETED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Status              : $OverallStatus" -ForegroundColor White
Write-Host "Files Found         : $TotalFilesFound" -ForegroundColor White
Write-Host "Files Deleted       : $TotalFilesDeleted" -ForegroundColor Green
Write-Host "Files Skipped       : $TotalFilesSkipped" -ForegroundColor Yellow
Write-Host "Folders Found       : $TotalFoldersFound" -ForegroundColor White
Write-Host "Folders Deleted     : $TotalFoldersDeleted" -ForegroundColor Green
Write-Host "Folders Skipped     : $TotalFoldersSkipped" -ForegroundColor Yellow
Write-Host "Errors              : $TotalErrors" -ForegroundColor Red
Write-Host "Duration            : $DurationText" -ForegroundColor Cyan
Write-Host ""
Write-Host "Developed by Ashadeep Parida" -ForegroundColor Cyan
Write-Host "Generated automatically by PowerShell" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan