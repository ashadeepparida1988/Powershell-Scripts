# ============================================================
# MONTHLY EXPENSES FOLDER BACKUP + HTML EMAIL NOTIFICATION
# ============================================================

# ---------------- CONFIGURATION ----------------

$SourceFolder      = "D:\Files"
$DestinationFolder = "C:\Users\XXXXX\OneDrive\Files"

# Gmail SMTP
$SmtpServer = "smtp.gmail.com"
$SmtpPort   = 587

$FromEmail = "enter the from email ID"
$ToEmail   = "enter the To email ID"
$Username  = "enter the from email ID"

# IMPORTANT:
# Enter your NEW Gmail App Password here WITHOUT spaces.
# Do NOT use the App Password previously exposed.
$Password = "Enter the password"


# ============================================================
# START
# ============================================================

$StartTime = Get-Date

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       MONTHLY EXPENSES FOLDER BACKUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Source      : $SourceFolder"
Write-Host "Destination : $DestinationFolder"
Write-Host "Start Time  : $StartTime"
Write-Host ""


# ============================================================
# CHECK SOURCE
# ============================================================

if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {

    Write-Host "ERROR: Source folder does not exist." -ForegroundColor Red
    exit 1
}


# ============================================================
# CREATE DESTINATION
# ============================================================

if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {

    Write-Host "Creating destination folder..." -ForegroundColor Yellow

    New-Item `
        -Path $DestinationFolder `
        -ItemType Directory `
        -Force | Out-Null
}


# ============================================================
# ROBOCOPY
# ============================================================

$RobocopyLog = Join-Path $env:TEMP "MonthlyExpenses_Robocopy.log"

Write-Host ""
Write-Host "Starting Robocopy..." -ForegroundColor Cyan
Write-Host ""

& robocopy `
    $SourceFolder `
    $DestinationFolder `
    /E `
    /Z `
    /R:3 `
    /W:5 `
    /NP `
    /TEE `
    "/LOG:$RobocopyLog"

$RobocopyExitCode = $LASTEXITCODE


# ============================================================
# TIME CALCULATION
# ============================================================

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Calculate total elapsed seconds
$TotalSeconds = [math]::Round($Duration.TotalSeconds)

$Hours = [math]::Floor($TotalSeconds / 3600)

$RemainingSeconds = $TotalSeconds % 3600

$Minutes = [math]::Floor($RemainingSeconds / 60)

$Seconds = $RemainingSeconds % 60

# Create readable duration
if ($Hours -gt 0) {

    $DurationText = "$Hours hour(s) $Minutes minute(s) $Seconds second(s)"

}
elseif ($Minutes -gt 0) {

    $DurationText = "$Minutes minute(s) $Seconds second(s)"

}
else {

    $DurationText = "$Seconds second(s)"
}


# ============================================================
# RESULT
# ============================================================

if ($RobocopyExitCode -le 7) {

    $Status = "SUCCESS"
    $StatusColor = "#198754"
    $StatusIcon = "&#10004;"
    $Subject = "SUCCESS - Monthly Expenses Folder"

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "       MONTHLY EXPENSES BACKUP SUCCESSFUL" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "Robocopy Exit Code : $RobocopyExitCode" -ForegroundColor Green
}
else {

    $Status = "FAILED"
    $StatusColor = "#dc3545"
    $StatusIcon = "&#10060;"
    $Subject = "FAILED - Monthly Expenses Folder"

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "          MONTHLY EXPENSES BACKUP FAILED" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "Robocopy Exit Code : $RobocopyExitCode" -ForegroundColor Red
}


# ============================================================
# HTML EMAIL
# ============================================================

$HtmlBody = @"
<!DOCTYPE html>
<html>

<head>

<meta charset="UTF-8">

<style>

body {
    font-family: Arial, Helvetica, sans-serif;
    background-color: #f4f6f8;
    margin: 0;
    padding: 25px;
}

.container {
    max-width: 650px;
    margin: auto;
    background-color: #ffffff;
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 2px 10px rgba(0,0,0,0.10);
}

.header {
    background-color: #1f4e78;
    color: white;
    padding: 25px;
    text-align: center;
}

.header h1 {
    margin: 0;
    font-size: 24px;
}

.header p {
    margin: 8px 0 0;
    font-size: 14px;
}

.status {
    margin: 20px;
    padding: 15px;
    text-align: center;
    color: white;
    background-color: $StatusColor;
    border-radius: 7px;
    font-size: 20px;
    font-weight: bold;
}

.content {
    padding: 10px 25px 25px 25px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
}

td {
    padding: 12px;
    border-bottom: 1px solid #eeeeee;
}

.label {
    font-weight: bold;
    width: 35%;
    color: #555555;
}

.value {
    color: #222222;
    word-break: break-word;
}

.footer {
    background-color: #f1f3f5;
    padding: 18px;
    text-align: center;
    color: #777777;
    font-size: 12px;
    line-height: 1.7;
}

.footer strong {
    color: #444444;
    font-size: 13px;
}

.log {
    background-color: #f8f9fa;
    padding: 12px;
    border-radius: 5px;
    font-family: Consolas, monospace;
    font-size: 12px;
    word-break: break-all;
}

</style>

</head>

<body>

<div class="container">


    <!-- HEADER -->

    <div class="header">

        <h1>Monthly Expenses Folder</h1>

        <p>PowerShell / Robocopy Backup Report</p>

    </div>


    <!-- STATUS -->

    <div class="status">

        $StatusIcon &nbsp; $Status

    </div>


    <!-- CONTENT -->

    <div class="content">

        <table>


            <tr>

                <td class="label">
                    Source
                </td>

                <td class="value">
                    $SourceFolder
                </td>

            </tr>


            <tr>

                <td class="label">
                    Destination
                </td>

                <td class="value">
                    $DestinationFolder
                </td>

            </tr>


            <tr>

                <td class="label">
                    Start Time
                </td>

                <td class="value">
                    $StartTime
                </td>

            </tr>


            <tr>

                <td class="label">
                    End Time
                </td>

                <td class="value">
                    $EndTime
                </td>

            </tr>


            <tr>

                <td class="label">
                    Duration
                </td>

                <td class="value">
                    $DurationText
                </td>

            </tr>


            <tr>

                <td class="label">
                    Robocopy Exit Code
                </td>

                <td class="value">
                    $RobocopyExitCode
                </td>

            </tr>


            <tr>

                <td class="label">
                    Backup Status
                </td>

                <td class="value">

                    <strong>$Status</strong>

                </td>

            </tr>


        </table>


        <!-- ROBOCOPY LOG -->

        <h3>Robocopy Log</h3>

        <div class="log">

            $RobocopyLog

        </div>


    </div>


    <!-- FOOTER -->

    <div class="footer">

        <strong>
            Monthly Expenses Folder Backup Automation
        </strong>

        <br>

        Developed by Ashadeep Parida

        <br>

        Generated automatically by PowerShell

    </div>


</div>

</body>

</html>
"@


# ============================================================
# SEND EMAIL
# ============================================================

Write-Host ""
Write-Host "Sending email notification..." -ForegroundColor Cyan

$MailMessage = $null
$SmtpClient = $null

try {

    # --------------------------------------------------------
    # TLS 1.2
    # --------------------------------------------------------

    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12


    # --------------------------------------------------------
    # Convert Password
    # --------------------------------------------------------

    $SecurePassword = ConvertTo-SecureString `
        -String $Password `
        -AsPlainText `
        -Force


    # --------------------------------------------------------
    # Create Credential
    # --------------------------------------------------------

    $Credential = New-Object `
        System.Management.Automation.PSCredential(
            $Username,
            $SecurePassword
        )


    # --------------------------------------------------------
    # Create SMTP Client
    # --------------------------------------------------------

    $SmtpClient = New-Object System.Net.Mail.SmtpClient(
        $SmtpServer,
        $SmtpPort
    )

    $SmtpClient.EnableSsl = $true

    $SmtpClient.UseDefaultCredentials = $false

    $SmtpClient.Credentials =
        $Credential.GetNetworkCredential()

    $SmtpClient.Timeout = 60000


    # --------------------------------------------------------
    # Create Email
    # --------------------------------------------------------

    $MailMessage = New-Object System.Net.Mail.MailMessage

    $MailMessage.From = $FromEmail

    $MailMessage.To.Add($ToEmail)

    $MailMessage.Subject = $Subject

    $MailMessage.Body = $HtmlBody

    $MailMessage.IsBodyHtml = $true


    # --------------------------------------------------------
    # Send Email
    # --------------------------------------------------------

    $SmtpClient.Send($MailMessage)


    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "             EMAIL SENT SUCCESSFULLY" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "                EMAIL FAILED" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

}
finally {

    if ($MailMessage) {

        $MailMessage.Dispose()

    }

    if ($SmtpClient) {

        $SmtpClient.Dispose()

    }

}


# ============================================================
# FINAL OUTPUT
# ============================================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "              PROCESS COMPLETED" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copy Status        : $Status"
Write-Host "Robocopy Exit Code : $RobocopyExitCode"
Write-Host "Duration           : $DurationText"
Write-Host "End Time           : $EndTime"
Write-Host ""

Write-Host "Robocopy Log:"
Write-Host $RobocopyLog
Write-Host ""

