#Description:
#This script will fetch details of servers where Windows license are activated or not. And could run in any of the servers.
##########################################################################################################################

Param
(
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [String[]]$ComputerName = $env:COMPUTERNAME
)

#defined initial data
$LicenseStatus = @("Unlicensed","Activated","OOB Grace",
"OOT Grace","Non-Genuine Grace","Notification","Extended Grace")

#Provide the list of servers in input file

$computerName= GC -path "C:\script\servers.txt"
Foreach($CN in $ComputerName)
{
    Get-CimInstance -ClassName SoftwareLicensingProduct -ComputerName $CN |`
    Where{$_.PartialProductKey -and $_.Name -like "*Windows*"} | select `
    @{Expression={$_.PSComputerName};Name="ComputerName"},
    @{Expression={$LicenseStatus[$($_.LicenseStatus)]};Name="LicenseStatus"} | export-csv "C:\script\result.csv" -NoTypeInformation
}  