#Define variables
$computers = Get-Content "C:\Script\Computers.txt"
#$computers = Import-CSV C:\Computers.csv | select Computer
$username = "ansadmin"
$password = "M0reC0ffee@1102"
$fullname = "Ansible Admin"
$local_security_group = "Administrators"
$description = "Description"
 
Foreach ($computer in $computers) {
$users = $null
$comp = [ADSI]"WinNT://$computer"
 
#Check if username exists
Try {
$users = $comp.psbase.children | select -expand name
if ($users -like $username) {
Write-Host "$username already exists on $computer"
 
} else {
#Create the account
$user = $comp.Create("User","$username")
$user.SetPassword("$password")
$user.Put("Description","$description")
$user.Put("Fullname","$fullname")
$user.SetInfo()
 
#Set password to never expire
#And set user cannot change password
$ADS_UF_DONT_EXPIRE_PASSWD = 0x10000
$ADS_UF_PASSWD_CANT_CHANGE = 0x40
$user.userflags = $ADS_UF_DONT_EXPIRE_PASSWD + $ADS_UF_PASSWD_CANT_CHANGE
$user.SetInfo()
 
#Add the account to the local admins group
$group = [ADSI]"WinNT://$computer/$local_security_group,group"
$group.add("WinNT://$computer/$username")
 
#Validate whether user account has been created or not
$users = $comp.psbase.children | select -expand name
if ($users -like $username) {
Write-Host "$username has been created on $computer"
} else {
Write-Host "$username has not been created on $computer"
}
}
}
 
Catch {
Write-Host "Error creating $username on $($computer.path):  $($Error[0].Exception.Message)"
}
}