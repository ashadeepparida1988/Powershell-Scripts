Login-AzureRmAccount
$subs= Get-AzureRmSubscription
foreach ($s in $subs){
Set-AzureRmContext -Subscription $s.name
$vmlist=(Get-AzureRmVM).Name
$allvault=Get-AzureRmRecoveryServicesVault
foreach ( $val in $allvault){
$val| Set-AzureRmRecoveryServicesVaultContext 
$jobs = Get-AzureRmRecoveryServicesBackupJob 
$backupvms=Get-AzureRmRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM

foreach ($v in $backupvms){
  $vm=$v.Name.Split(';')[3]
  
           foreach($job in $jobs){
            if($vm -eq $job.WorkloadName){
               $jobDetail = Get-AzureRmRecoveryServicesBackupJobDetails -Job $job
               $time = $job.Duration.Days.ToString() + " Days " + $job.Duration.Hours.ToString() + " Hours " + $job.Duration.Minutes.ToString() + " Minutes " + $job.Duration.Seconds.ToString() + " Seconds"
               } }
           $backupitems=Get-AzureRmRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -Name $vm
           $vrg=$backupitems.ContainerName.Split(';')[1]
           $os=Get-AzureRmVM -ResourceGroupName $vrg -Name $VM -ErrorAction SilentlyContinue
           if (!$os){
           $ostype="No VM Found"
           }else{
           $ostype=$os.StorageProfile.OsDisk.OsType
           }
           $backupitems | select @{n='VM Name';e={$vm}},@{n='VM OS';e={$ostype}},@{n='Vault Resource Group';e={$backupitems.containername.Split(';')[1]}},@{n='Recovery Vault';e={$val.Name}},@{n='Recovery Points';e={$backupitems.ExtendedInfo.RecoveryPointCount}},@{n='Oldest Recovery Point';e={$backupitems.ExtendedInfo.OldestRecoveryPoint}},@{n='Last Backup Status';e={$backupitems.LastBackupStatus}},@{n='Last Restore Point';e={$backupitems.LatestRecoveryPoint}},@{n='Backup Size';e={$jobDetail.Properties.'Backup Size'}},@{n='Backup Policy Name';e={$backupitems.ProtectionPolicyName}},@{n='Backup Duration';e={$time}} |Export-csv 'C:\Temp\BackupReport.csv' -Append -NoTypeInformation 
            } }
            $result=foreach ( $val in $allvault){
$val| Set-AzureRmRecoveryServicesVaultContext
Get-AzureRmRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
}
$bckname=foreach ($r in $result){$r.Name.Split(';')[3]}
        
  foreach ($vml in $vmlist){ 

          if ($bckname -notcontains $vml){          
            
  $vml |select @{n='VM Name';e={$vml}}| Export-csv 'C:\Temp\NoBackupEnabled.csv' -Append -NoTypeInformation 
 
 } } }