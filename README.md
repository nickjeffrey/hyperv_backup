# hyperv_backup
Powershell script to create cold backups of Hyper-V virtual machines

# Usage

For a one-time backup:
`
powershell.exe x:\path\to\hyperv_backup.ps1 
`

For recurring weekly backups:
```   
schtasks.exe /create /RU SYSTEM /TN hyperv_backup /TR "powershell.exe x:\path\to\hyperv_backup.ps1" /SC weekly /D FRI /ST 23:00
```


To exclude a particular VM from backups, please refer to section of the script that defines VMs to skip

To send an email report showing the backup status, please edit the following section:
```
$hostname   = $env:computername                #figure out the local hostname
$to         = "recipient@example.com"          #sysadmin that receives email report
$from       = "sender@example.com"             #from address
$subject    = "backup report from $hostname"   #subject of email message
$smtpserver = "MySmtpServer.example.com"       #SMTP smart host used for relaying the email
$port       = "25"                             #SMTP TCP port
$destdir    = "x:\path\to\vmbackups"           #location of backups
```
