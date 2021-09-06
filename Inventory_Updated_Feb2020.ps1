# -------------------------------------------------------------------------------------------------------------- 
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,  
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED  
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
# 
#  Title         : AzureARMVMDetailedInventorywithTags 
#  Programmed by : Denis Rougeau 
#  Date          : May, 2017 
# 
# -------------------------------------------------------------------------------------------------------------- 
#  GET THE LATEST VERSION HERE: https://gallery.technet.microsoft.com/Azure-ARM-VM-Inventory-57ba01b7
# -------------------------------------------------------------------------------------------------------------- 
# 
# Demo Script to create Azure ARM VM List into a CSV files with VM Tags as header (One file per subscription) 
#
# NOTE: Support for multiple NIC, IP, Public IP, Data Disks per VMs
#       Multiple values within the same field are separated by " Carriage Return "
#       Added support for Managed Disks and Premium disks
#
# Headers:
# - Az_Location
# - Az_ResourceGroup
# - Az_Name
# - Az_Status                     -> Running/Stopped/Deallocated
# - Az_Statuscode                 -> OK/Failed... VM in Error status
# - Az_AvailabilitySet
# - Az_Size                       -> VM Size (ex. Standard_A1_V2)
# - Az_Cores                      -> # Cores
# - Az_Memory                     -> Memory size
# - Az_OSType                     -> Windows/Linux
# - Az_VNicNames                  -> Display all VNics name attached to the VM
# - Az_VNicProvisioningState      -> Succeeded/Failed.  NIC Provisionning Status
# - Az_VNicPrivateIPs
# - Az_vNicPrivateIPAllocMethods  -> Static/Dynamic
# - Az_VirtualNetworks
# - Az_Subnets
# - Az_VNicPublicIP
# - Az_VNicPublicIPAllocMethod    -> Static/Dynamic
# - Az_VM_Instance_SLA            -> If all VM disks are Premium and VM is a xS_ series, Azure offer 99.9 percent service-level agreement(SLA) (https://azure.microsoft.com/en-us/support/legal/sla/virtual-machines/)
# - Az_OSDisk
# - Az_OSDiskSize
# - Az_OSDiskTier                 -> Standard/Managed Disks...  
# - Az_OSDiskRepl                 -> Standard/Premium LRS/GRS/GRS-RA/...   
# - Az_DataDisks                  -> Display all data disks name attached to the VM
# - Az_DataDisksSize
# - Az_DataDisksTier              -> Standard/Managed Disks...  
# - Az_DataDisksRepl              -> Standard/Premium LRS/GRS/GRS-RA/...   
# - Az_VMTags                     -> List all VM tags in one field
# - Az_VMTag [0-14]               -> Make each VM tags it's own header in the Output
# -------------------------------------------------------------------------------------------------------------- 



# TO BE MODIFIED AS APPROPRIATE.  Currently start the file name with datetime stamp.  1 file per subscription
$OutputCSVPath = "c:\temp\" 
$OutputCSVFile = "{0:yyyyMMddHHmm}-AzureARMVMList" -f (Get-Date)
$outputCSVExt  = ".csv" 
 

# Login to Azure Reaource Manager
Login-AzureRMAccount 
 
Function GetDiskSize ($DiskURI) 
{ 
  # User running the script must have Read access to the VM Storage Accounts for these values to be retreive
  $error.clear() 
  $DiskContainer = ($DiskURI.Split('/'))[3]  
  $DiskBlobName  = ($DiskURI.Split('/'))[4]  
 
  # Create Return PS object
  $BlobObject = @{'Name'=$DiskURI;'SkuName'=" ";'SkuTier'=" ";'DiskSize'=0}

  # Avoid connecting to Storage if last disk in same Storage Account (Save significant time!) 
  if ($global:DiskSA -ne ((($DiskURI).Split('/')[2]).Split('.'))[0]) 
  { 
    $global:DiskSA = ((($DiskURI).Split('/')[2]).Split('.'))[0] 
    $global:SAobj = $AllARMSAs | where-object {$_.StorageAccountName -eq $DiskSA} 
    $SARG  = $global:SAobj.ResourceGroupName 
    $SAKeys     = Get-AzureRMStorageAccountKey -ResourceGroupName $SARG -Name $DiskSA 
    $global:SAContext  = New-AzureStorageContext -StorageAccountName $DiskSA  -StorageAccountKey $SAKeys[0].value  
  } 

  $DiskObj = get-azurestorageblob -Context $SAContext -Container $DiskContainer -Blob $DiskBlobName 
  if($Error) 
    {   
       $BlobObject.DiskSize = -1  
       $error.Clear() 
    } 
  else 
    { 
      [int] $DiskSize = $Diskobj.Length/1024/1024/1024 # GB
      $BlobObject.DiskSize = $DiskSize
      $BlobObject.SkuName = $global:SAobj.Sku.Name
      $BlobObject.SkuTier = $global:SAobj.Sku.Tier 
    }  
 
  Return $BlobObject  

  trap { 
      Return $BlobObject 
    } 
} 
 
# Get Start Time 
$startDTM = (Get-Date) 
"Starting Script: {0:yyyy-MM-dd HH:mm}..." -f $startDTM 
 
# Get a list of all subscriptions (or a single subscription) 
"Retrieving all Subscriptions..." 
$Subscriptions = Get-AzureRmSubscription | Sort SubscriptionName    
# ***  NOTE: Uncomment the following line if you want to limit the query to a specific subscription 
#$Subscriptions = Get-AzureRmSubscription | ? {$_.Name -eq "My Subscription"} 
"Found: " + $Subscriptions.Count 
 
# Retrieve all available Virtual Machine Sizes 
" " 
"Retrieving all available Virtual Machines Sizes..." 
$AllVMsSize = Get-AzureRmVMSize -Location "West US"  #  Using West US and South Central US and East US 2 as those 2 locations are usually the ones with all and newer VM sizes 
$AllVMsSizeSCU = Get-AzureRmVMSize -Location "South Central US" 
foreach ($VMsSizeSCU in $AllVMsSizeSCU) 
{ 
    if ($AllVMsSize.Name -notcontains $VMsSizeSCU.Name) { $AllVMsSize += $VMsSizeSCU } 
} 
$AllVMsSizeEU2s = Get-AzureRmVMSize -Location "East US 2" 
foreach ($VMsSizeEU2 in $AllVMsSizeEU2s) 
{ 
    if ($AllVMsSize.Name -notcontains $VMsSizeEU2.Name) { $AllVMsSize += $VMsSizeEU2 } 
} 
"Found: " + $AllVMsSize.Count 
 
# Loop thru all subscriptions 
$AzureVMs = @() 
foreach($subscription in $Subscriptions)  
{ 
    " " 
    "Querying subscription:" 
    $SubscriptionID = $Subscription.Id  
    $SubscriptionName = $Subscription.Name 
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID 
 
    # Retrieve all Public IPs 
    "1- Retrieving all Public IPs..." 
    $AllPublicIPs = get-azurermpublicipaddress 
    "   Found: " + $AllPublicIPs.Count 
 
    # Retrieve all Virtual Networks 
    "2- Retrieving all Virtual Networks..." 
    $AllVirtualNetworks = get-azurermvirtualnetwork 
    "   Found: " + $AllVirtualNetworks.Count 
 
    # Retrieve all Network Interfaces 
    "3- Retrieving all Network Interfaces..." 
    $AllNetworkInterfaces = Get-AzureRmNetworkInterface 
    "   Found: " + $AllNetworkInterfaces.Count 
  
    # Retrieve all ARM Virtual Machines 
    "4- Retrieving all ARM Virtual Machines..." 
    $AllARMVirtualMachines = get-azurermvm | Sort location,resourcegroupname,name 
    "   Found: " + $AllARMVirtualMachines.Count 
 
    # Skip further steps if no ARM VM found 
    if($AllARMVirtualMachines.Count -gt 0) 
    { 
 
        # Intitialize Storage Account Context variable 
        $global:DiskSA = "" 
 
        # Retrieve all ARM Storage Accounts 
        "5- Retrieving all ARM Storage Accounts..." 
        $AllARMSAs = Get-AzureRmStorageAccount 
        "   Found: " + $AllARMSAs.Count 
 
        # Retrieve all Managed Disks 
        "6- Retrieving all Managed Disks..." 
        $AllMAnagedDisks = Get-AzureRmDisk 
        "   Found: " + $AllManagedDisks.Count 

        # Retrieve all ARM Virtual Machine tags 
        "7- Capturing all ARM Virtual Machines Tags..." 
        $AllVMTags = @() 
        foreach ($virtualmachine in $AllARMVirtualMachines) 
        { 
            $tags = $virtualmachine.Tags 
            $tKeys = $tags | select -ExpandProperty keys 
            foreach ($tkey in $tkeys) 
            { 
              
              if ($AllVMTags -notcontains $tkey.ToUpper()) { $AllVMTags += $tkey.ToUpper() } 
            } 
        } 
        "   Found: " + $AllVMTags.Count 
  
        # This script support up to 15 VM Tags, Increasing $ALLVMTags array to support up to 15 if less then 15 found 
        for($i=$($AllVMTags.Count);$i -lt 100; $i++) { $AllVMTags += "Az_VMTag$i"  } #Default Header value  
 
        # Capturing all ARM VM Configurations details 
        "8- Capturing all ARM VM Configuration Details...     (This may take a few minutes)" 
        $AzureVMs = foreach ($virtualmachine in $AllARMVirtualMachines) 
        { 
            $location = $virtualmachine.Location 
            $rgname = $virtualmachine.ResourceGroupName 
            $vmname = $virtualmachine.Name 
 
            # Format Tags, sample: "key : Value <CarriageReturn> key : value "   TAGS keys are converted to UpperCase 
            $taglist = ' ' 
            $ThisVMTags = @(' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ')  # Array of VMTags matching the $AllVMTags (Header) 
            $tags = $virtualmachine.Tags 
            $tKeys = $tags | select -ExpandProperty keys 
            $tvalues = $tags | select -ExpandProperty values 
            if($tags.Count -eq 1)  
            { 
                  $taglist = $tkeys+":"+$tvalues 
                  $ndx = [array]::IndexOf($AllVMTags,$tKeys.ToUpper())  # Find position of header matching the Tag key 
                  $ThisVMTags[$ndx] = $tvalues 
            } 
            else 
            { 
              For ($i=0; $i -lt $tags.count; $i++)  
              { 
                  $tkey = $tkeys[$i] 
                  $tvalue = $tvalues[$i] 
                  $taglist = $taglist+$tkey+":"+$tvalue+"`n" 
                  $ndx = [array]::IndexOf($AllVMTags,$tKey.ToUpper())   # Find position of header matching the Tag key 
                  $ThisVMTags[$ndx] = $tvalue 
               } 
            } 
 
            # Get VM Status 
            $Status = get-azurermvm -Status -ResourceGroupName "$rgname" -Name "$vmname" 
            $vmstatus =  $Status.Statuses[1].DisplayStatus 
 
            # Get Availability Set 
            $AllRGASets = get-azurermavailabilityset -ResourceGroupName $rgname 
            $VMASet = $AllRGASets | Where-Object {$_.id -eq $virtualmachine.AvailabilitySetReference.Id} 
            $ASet = $VMASet.Name 
 
            # Get Number of Cores and Memory 
            $VMSize = $AllVMsSize | Where-object {$_.Name -eq $virtualmachine.HardwareProfile.VmSize}  
            $VMCores = $VMSize.NumberOfCores 
            $VMMem = $VMSize.MemoryInMB/1024 
 
            # Get VM Network Interface(s) and properties 
            $MatchingNic = "" 
            $NICName = @()
            $NICProvState = @() 
            $NICPrivateIP = @() 
            $NICPrivateAllocationMethod = @() 
            $NICVNet = @() 
            $NICSubnet = @() 
            foreach($vnic in $VirtualMachine.NetworkProfile.NetworkInterfaces) 
            { 
                $MatchingNic = $AllNetworkInterfaces | where-object {$_.id -eq $vnic.id} 
                $NICName += $MatchingNic.Name 
                $NICProvState += $MatchingNic.ProvisioningState
                $NICPrivateIP += $MatchingNic.IpConfigurations.PrivateIpAddress 
                $NICPrivateAllocationMethod += $MatchingNic.IpConfigurations.PrivateIpAllocationMethod 
                $NICSubnetID = $MatchingNic.IpConfigurations.Subnet.Id 
         
                # Identifying the VM Vnet 
                $VMVNet = $AllVirtualNetworks | where-object {$_.Subnets.id -eq $NICSubnetID } 
                $NICVnet += $VMVNet.Name 
 
                # Identifying the VM subnet 
                $AllVNetSubnets = $VMVNet.Subnets   
                $vmSubnet = $AllVNetSubnets | where-object {$_.id -eq $NICSubnetID }  
                $NICSubnet += $vmSubnet.Name 
 
                # Identifying Public IP Address assigned 
                $VMPublicIPID = $MatchingNic.IpConfigurations.PublicIpAddress.Id 
                $VMPublicIP = $AllPublicIPs | where-object {$_.id -eq $VMPublicIPID } 
                $NICPublicIP = $VMPublicIP.IPAddress 
                $NICPublicAllocationMethod = $VMPublicIP.PublicIpAllocationMethod 
 
            } 

            # Get VM OS Disk properties 
            $OSDiskName = '' 
            $OSDiskSize = 0
            $OSDiskRepl = '' 
            $OSDiskTier = ''
            # Check if OSDisk uses Storage Account
            if($virtualmachine.StorageProfile.OsDisk.ManagedDisk -eq $null)
            {
                # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
                $VMOSDiskObj = GetDiskSize $virtualmachine.StorageProfile.OsDisk.Vhd.uri
                $OSDiskName = $VMOSDiskObj.Name 
                $OSDiskSize = $VMOSDiskObj.DiskSize
                $OSDiskRepl = $VMOSDiskObj.SkuName 
                $OSDiskTier = $VMOSDiskObj.SkuTier
            }
            else
            {
                $OSDiskID = $virtualmachine.StorageProfile.OsDisk.ManagedDisk.Id
                $VMOSDiskObj = $AllMAnagedDisks | where-object {$_.id -eq $OSDiskID }
                $OSDiskName = $VMOSDiskObj.Name 
                $OSDiskSize = $VMOSDiskObj.DiskSizeGB
                $OSDiskRepl = $VMOSDiskObj.AccountType
                $OSDiskTier = "Managed Disks"
            }

            $AllVMDisksPremium = $true 
            if($OSDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 

            # Get VM Data Disks and their properties 
            $DataDiskObj = @()
            $VMDataDisksObj = @() 
            foreach($DataDisk in $virtualmachine.StorageProfile.DataDisks) 
            { 

              # Initialize variable before each iteration
              $VMDataDiskName = ''
              $VMDataDiskSize = 0
              $VMDataDiskRepl = ''
              $VMDataDiskTier = ''

              # Check if this DataDisk uses Storage Account
              if($DataDisk.ManagedDisk -eq $null)
              {
                # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
                $VMDataDiskObj = GetDiskSize $DataDisk.vhd.uri 
                $VMDataDiskName = $VMDataDiskObj.Name
                $VMDataDiskSize = $VMDataDiskObj.DiskSize
                $VMDataDiskRepl = $VMDataDiskObj.SkuName
                $VMDataDiskTier = $VMDataDiskObj.SkuTier
              }
              else
              {
                $DataDiskID = $DataDisk.ManagedDisk.Id
                $VMDataDiskObj = $AllMAnagedDisks | where-object {$_.id -eq $DataDiskID }
                $VMDataDiskName = $VMDataDiskObj.Name
                $VMDataDiskSize = $VMDataDiskObj.DiskSizeGB
                $VMDataDiskRepl = $VMDataDiskObj.AccountType
                $VMDataDiskTier = "Managed Disks"
              }

              # Add Data Disk properties to arrray of Data disks object
              $DataDiskObj += @([pscustomobject]@{'Name'=$VMDataDiskName;'Size'=$VMDataDiskSize;'Repl'=$VMDataDiskRepl;'Tier'=$VMDataDiskTier})

              # Check if this datadisk is a premium disk.  If not, set the all Premium disks to false (No SLA)
              if($VMDataDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 
            } 
 
            # Create custom PS objects and return all these properties for this VM 
            [pscustomobject]@{ 
                            Az_Location = $virtualmachine.Location 
                            Az_ResourceGroup = $virtualmachine.ResourceGroupName 
                            Az_Name = $virtualmachine.Name 
                            Az_Status = $vmstatus 
                            Az_Statuscode = $virtualmachine.StatusCode 
                            Az_AvailabilitySet = $ASet 
                            Az_Size = $virtualmachine.HardwareProfile.VmSize 
                            Az_Cores = $VMCores 
                            Az_Memory = $VMMem 
                            Az_OSType = $virtualmachine.StorageProfile.OsDisk.OsType 
                            Az_VNicNames = $NICName -join "`n" 
                            Az_VNicProvisioningState = $NICProvState -join "`n" 
                            Az_VNicPrivateIPs = $NICPrivateIP -join "`n" 
                            Az_vNicPrivateIPAllocMethods = $NICPrivateAllocationMethod -join "`n" 
                            Az_VirtualNetworks = $NICVnet -join "`n" 
                            Az_Subnets = $NICSubnet -join "`n" 
                            Az_VNicPublicIP = $NICPublicIP 
                            Az_VNicPublicIPAllocMethod = $NICPublicAllocationMethod 
                            Az_VM_Instance_SLA = $AllVMDisksPremium
                            Az_OSDisk = $OSDiskName 
                            Az_OSDiskSize = $OSDiskSize
                            Az_OSDiskTier = $OSDiskTier  
                            Az_OSDiskRepl = $OSDiskRepl 
                            Az_DataDisks = $DataDiskObj.Name -join "`n" 
                            Az_DataDisksSize = $DataDiskObj.Size -join "`n" 
                            Az_DataDisksTier = $DataDiskObj.Tier -join "`n"
                            Az_DataDisksRepl = $DataDiskObj.Repl -join "`n"
                            Az_VMTags = $taglist 
                            $AllVMTags[0] = $ThisVMTags[0] 
                            $AllVMTags[1] = $ThisVMTags[1] 
                            $AllVMTags[2] = $ThisVMTags[2] 
                            $AllVMTags[3] = $ThisVMTags[3] 
                            $AllVMTags[4] = $ThisVMTags[4] 
                            $AllVMTags[5] = $ThisVMTags[5] 
                            $AllVMTags[6] = $ThisVMTags[6] 
                            $AllVMTags[7] = $ThisVMTags[7] 
                            $AllVMTags[8] = $ThisVMTags[8] 
                            $AllVMTags[9] = $ThisVMTags[9] 
                            $AllVMTags[10] = $ThisVMTags[10] 
                            $AllVMTags[11] = $ThisVMTags[11] 
                            $AllVMTags[12] = $ThisVMTags[12] 
                            $AllVMTags[13] = $ThisVMTags[13] 
                            $AllVMTags[14] = $ThisVMTags[14] 
			    $AllVMTags[15] = $ThisVMTags[15] 
                            $AllVMTags[16] = $ThisVMTags[16] 
                            $AllVMTags[17] = $ThisVMTags[17] 
                            $AllVMTags[18] = $ThisVMTags[18] 
                            $AllVMTags[19] = $ThisVMTags[19] 
                            $AllVMTags[20] = $ThisVMTags[20] 
                            $AllVMTags[21] = $ThisVMTags[21] 
                            $AllVMTags[22] = $ThisVMTags[22] 
                            $AllVMTags[23] = $ThisVMTags[23] 
                            $AllVMTags[24] = $ThisVMTags[24] 
                            $AllVMTags[25] = $ThisVMTags[25] 
                            $AllVMTags[26] = $ThisVMTags[26] 
                            $AllVMTags[27] = $ThisVMTags[27] 
                            $AllVMTags[28] = $ThisVMTags[28] 
                            $AllVMTags[29] = $ThisVMTags[29] 
                         } 
 
        }  #Array $AzureVMs U7%Vjt2@qf9dy38
 
        # Define CSV Output Filename, use subscription name and ID as name can be duplicate 
        $OutputCSV = "$OutputCSVPath$OutputCSVFile - $SubscriptionID$outputCSVExt"
 
        #CSV Exports Virtual Machines 
        " " 
        "Exporting Results to CSV file: $OutputCSV" 
          $CSVResult = $AzureVMs | Export-Csv $OutputCSV -NoTypeInformation 
    } 
    else 
      { "[Warning]: No ARM VMs found...  Skipping remaining steps."} 
}  # Subscriptions 
 
 
" " 
"Completed!" 
 
# Get End Time 
$endDTM = (Get-Date) 
"Stopping Script: {0:yyyy-MM-dd HH:mm}..." -f $endDTM 
 
# Echo Time elapsed 
"Elapsed Time: $(($endDTM-$startDTM).totalseconds) seconds" 
 
# Catch any unexpected error occurring while running the script 
trap { 
    Write-Host "An unexpected error occurred....  Please try again in a few minutes..."   
    Write-Host $("`Exception: " + $_.Exception.Message);  
    Exit 
 } 