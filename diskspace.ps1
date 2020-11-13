#################################################################################  
##                                                                              ##
## Server disk utilization monitoring and email the report in HTML format       ##
## Created by Ashadeep Parida                                                   ##
## Date : 22/MAY/2020                                                           ##
## Email: ashadeep.parida1@wipro.com                                            ##
## This script will check the local and remote servers disk utilization         ##  
## disk utilization and sends an email to the receipents included in the script ##
##################################################################################


#########################################################
# List of computers to be monitored
#########################################################
param (
      $serverList =  "C:\Script\Machine.txt"
)
$computers = Get-Content $serverList
#########################################################
# Configuration of alarmists
#########################################################
[decimal]$warningThresholdSpace =  15 # Percentage of free disk space - Warning (orange).
[decimal]$criticalThresholdSpace = 10 # Percentage of free disk space - critical (red)
#########################################################
# List of users who will receive the report
#########################################################
$mailto = "00000@gmail.com"

 
#########################################################
# SMTP properties
#########################################################
$emailFrom = "alert@xsaas.com"
$smtpServer = "smtp.sendgrid.net", "587" #SMTP Server.
$smtpUsername = "xxxxxxxxxxxxxx@azure.com"
$smtpPassword = "xxxxxxxxxxxxxxxx"
#########################################################
# Monitoring Process
#########################################################
[System.Array]$results = foreach ($cmp in $computers) {
 Get-WMIObject  -ComputerName $cmp Win32_LogicalDisk |
where{($_.DriveType -eq 3) -and (($_.freespace/$_.size*100) -lt $warningThresholdSpace) }|
select @{n='Server Name' ;e={"{0:n0}" -f ($cmp)}},
@{n='Volume Name' ;e={"{0:n0}" -f ($_.volumename)}},
@{n='Drive' ;e={"{0:n0}" -f ($_.name)}},
@{n='Capacity (Gb)' ;e={"{0:n2}" -f ($_.size/1gb)}},
@{n='Free Space (Gb)';e={"{0:n2}" -f ($_.freespace/1gb)}},
@{n='Percentage Free';e={"{0:n2}%" -f ($_.freespace/$_.size*100)}}
}
#########################################################
# Formating result
#########################################################
$tableStart="<table style='boder:0px 0px 0px 0px;'><tr><th>Server Name</th><th>Volume Name</th><th>Drive</th>
<th>Capacity (Gb)</th><th>Free Space (Gb)</th><th>Percentage Free</th></tr>"

#########################################################
# Exit if there is 0 rows
#########################################################
if ($results.Length -eq 0)
        {
            #break      # <- abort loop
            #continue  # <- skip just this iteration, but continue loop
            #return    # <- abort code, and continue in caller scope
            exit      # <- abort code at caller scope 
        }
#########################################################
		
$allLines=""
for($i=0;$i -lt $results.Length;$i++){
     #get das variáveis
     $servers=($results[$i] | select -ExpandProperty "Server Name"  )
     $volumes=($results[$i] | select -ExpandProperty "Volume Name" )
     $drives=($results[$i] | select -ExpandProperty "Drive" )
     $capac=($results[$i] | select -ExpandProperty "Capacity (Gb)" )
     $freeSpace=($results[$i] | select -ExpandProperty "Free Space (Gb)" )
     $percentage=($results[$i] | select -ExpandProperty "Percentage Free" )
     
     #alterna cores das linhas
     if(($i % 2) -ne 0){
         $beginning="<tr style='background-color:white;'>"
     }else{
         $beginning="<tr style='background-color:rgb(245,245,245);'>"
     }
     #controi o body
     $bodyEl ="<td> " + $servers+ " </td>" 
     $bodyEl+="<td> " + $volumes + " </td>"
     $bodyEl+="<td style='text-align:center;'> " + $drives + " </td>"
     $bodyEl+="<td style='text-align:center;'> " + $capac + " </td>"
     $bodyEl+="<td style='text-align:center;'> " + $freeSpace + " </td>"
     $fr=[System.Double]::Parse($freeSpace)
     $cap=[System.Double]::Parse($capac)
     if((($fr/$cap)*100) -lt [System.Int32]::Parse($criticalThresholdSpace)){
         $bodyEl+= "<td style='color:red;font-weight:bold;text-align:center;'>"+$percentage +"</td>"
     }
     else{
         $bodyEl+="<td style='color:orange;text-align:center;'>"+$percentage +"</td>"
     }    
     $end="</tr>"
     $allLines+=$beginning+$bodyEl+$end
}
$tableBody=$allLines
$tableEnd="</table>"
$tableHtml=$tableStart+$tableBody+$tableEnd

# HTML Format for Output 
$HTMLmessage = @"
<font color=""black"" face=""Arial"" size=""3"">
<h1 style='font-family:arial;'><b>Disk Space Storage Report</b></h1>
<p style='font: .8em ""Lucida Grande"", Tahoma, Arial, Helvetica, sans-serif;'>This report was generated because the drive(s) listed below have less than $warningThresholdSpace % free space. Drives above this threshold will not be listed.</p>
<br><br>
<style type=""text/css"">body{font: .8em ""Lucida Grande"", Tahoma, Arial, Helvetica, sans-serif;}
ol{margin:0;}
table{width:80%;}
thead{}
thead th{font-size:120%;text-align:left;}
th{border-bottom:2px solid rgb(79,129,189);border-top:2px solid rgb(79,129,189);padding-bottom:10px;padding-top:10px;}
tr{padding:10px 10px 10px 10px;border:none;}
#middle{background-color:#900;}
</style>
<body BGCOLOR=""white"">
$tableHtml
</body>
"@


#########################################################
# Validation and sending email
#########################################################
# Regular expression to get what's inside of's
$regexsubject = $HTMLmessage
$regex = [regex] '(?im)
'

# If you have data between's then you need to send the email
if ($regex.IsMatch($regexsubject)) {
     $smtp = New-Object Net.Mail.SmtpClient -ArgumentList $smtpServer
      $smtp.credentials = New-Object System.Net.NetworkCredential($smtpUsername, $smtpPassword);
      $msg = New-Object Net.Mail.MailMessage
     $msg.From = $emailFrom
     $msg.To.Add($mailto)
     $msg.Subject = "Disk Space Alert"
     $msg.IsBodyHTML = $true
     $msg.Body = $HTMLmessage
     $smtp.EnableSSL = $true
     $smtp.Send($msg)
    }