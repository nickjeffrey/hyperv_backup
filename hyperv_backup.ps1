# Windows Powershell script to backup virtual machines on a Hyper-V host
# This script will shutdown each virtual machine to make a cold backup




# OUTSTANDING TASKS
# -----------------
#   1) add error-checks that alert if there is insufficient disk space
#   2) add error-checks to confirm this script is running with admin privileges


# CHANGE LOG
# ----------
#  2014/08/14   njeffrey   Script created
#  2014/08/23	njeffrey   Add details on how to schedule this script to run automatically
#  2015/10/03	njeffrey   Add embedded echo statements to describe what the script is doing
#  2015/10/03	njeffrey   Get rid of hard-coded virtual machine names.  Just backup all running guests.
#  2015/11/14	njeffrey   Include hostname of hyperv server in email subject line
#  2019/02/13	njeffrey   Add more detail to report that gets emailed to the sysadmin


# TROUBLESHOOTING
# ---------------
#  If you try to "stop-vm $vmname" on a virtual machine that is locked or has a logged-in user, you will get the following message.
#  This script will try "stop-vm $vmname" first, and move on to "stop-vm $vname -force" if the VM is still running after 5 minutes.
#     stop-vm : The virtual machine is locked. An interactive shutdown cannot proceed while the virtual machine is locked.
#     At C:\util\backup.ps1:66 char:4
#     +    stop-vm          $vmname ; Start-Sleep -s 30
#     +    ~~~~~~~~~~~~~~~~~~~~~~~~
#         + CategoryInfo          : NotSpecified: (Microsoft.HyperV.PowerShell.ShutdownTask:ShutdownTask) [Stop-VM], VirtualizationOperationFailedException
#         + FullyQualifiedErrorId : Unspecified,Microsoft.HyperV.PowerShell.Commands.StopVMCommand




# NOTES
# ------
# It is assumed that this script is automatically run as a scheduled task on a weekly basis.
# HINT: If you have multiple Hyper-V servers, stagger the start time by a few hours on each server so all your virtual machines don't go down at once.
# EXAMPLE:  schtasks.exe /create /RU SYSTEM /TN hyperv_backup /TR "powershell.exe c:\util\hyperv_backup.ps1" /SC weekly /D FRI /ST 23:00 
#
# This script only backs up virtual machines that are running.
# Each virtual machine will be stopped, backed up, restarted.


# Declare variables
$hostname   = $env:computername                # Figure out the local hostname
$to         = "recipient@example.com"          #sysadmin that receives email report
$from       = "sender@example.com"             #from address
$subject    = "backup report from $hostname"   #subject of email message
$smtpserver = "MySmtpServer.example.com"       #SMTP smart host used for relaying the email
$port       = "25"                             #SMTP TCP port
$destdir    = "x:\path\to\vmbackups"           #location of backups


# confirm the script is running with administrator privileges
Write-Host "Confirming this script is running with administrative privileges"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
}


# get a list of the running virtual machines
# we intentionally ignore machines that are not running because they are likely Hyper-V Replicas from another host
# Get-VM | Where { $_.State –eq 'Running' } | select VMName
$guests = Get-VM | Where { $_.State –eq 'Running' }



write-host "The following virtual machines will be backed up: "
foreach ($guest in $guests) {
   write-host "   " $guest.VMName
}
write-host " "




foreach ($guest in $guests) {
   #
   # define variables
   $vmname = $guest.VMName
   #
   # define any virtual machines that you want to skip
   if ($vmname -eq "HostnameToSkip1" ) {echo "Skipping backup of excluded machine $vmname" ; continue}
   if ($vmname -eq "HostnameToSkip2" ) {echo "Skipping backup of excluded machine $vmname" ; continue}
   if ($vmname -eq "HostNametoSkip3" ) {echo "Skipping backup of excluded machine $vmname" ; continue}
   if ($vmname -eq "win10test"       ) {echo "Skipping backup of excluded machine $vmname" ; continue}
   if ($vmname -eq "win7test"        ) {echo "Skipping backup of excluded machine $vmname" ; continue}
   #
   # confirm destination folder exists
   Write-Host "Confirming $destdir directory exists"
   if (!(Test-Path -path $destdir)) { echo "Creating $destdir directory" ; New-Item $destdir -type directory | Out-Null }
   if (!(Test-Path -path $destdir)) { 
      echo "ERROR: Could not create $destdir directory"
      $subject = "ERROR in backup for $hostname"
      $body    = "ERROR: $PSCommandPath script on $env:computername could not create $destdir directory.  Please check permissions. `n"
      Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
      exit
   }
   Write-Host "Confirming $destdir\$vmname directory exists"
   if (!(Test-Path -path $destdir\$vmname)) { echo "Creating $destdir\$vmname directory" ; New-Item    $destdir\$vmname -type directory | Out-Null }
   if (!(Test-Path -path $destdir\$vmname)) { 
      Write-Host "ERROR: Could not create $destdir\$vmname directory"
      $subject = "ERROR in backup for $hostname"
      $body    = "ERROR: $PSCommandPath script on $env:computername could not create $destdir\$vmname directory.  Please check permissions. `n"
      Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
      exit
   }
   # 
   # rotate through 4 backup generations
   Write-Host "Rotating old backups for $vmname"
   if ( (Test-Path -path $destdir\$vmname\backup4)) { 
      echo "Deleting $destdir\$vmname\backup4"
      Remove-Item $destdir\$vmname\backup4 -Force -Recurse
      Start-Sleep -s 30 
      if ( (Test-Path -path $destdir\$vmname\backup4)) { 
         Write-Host "ERROR: Could not delete $destdir\$vmname\backup4 directory"   
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: $PSCommandPath script on $env:computername could not delete $destdir\$vmname\backup4 directory.  Please check permissions. `n"
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
         exit
      }
   }
   if ( (Test-Path -path $destdir\$vmname\backup3)) { 
      echo "Renaming $destdir\$vmname\backup3 to $destdir\$vmname\backup4" 
      Rename-Item $destdir\$vmname\backup3 $destdir\$vmname\backup4       
      Start-Sleep -s 10 
      if ( (Test-Path -path $destdir\$vmname\backup3)) { 
         Write-Host "ERROR: Could not rename $destdir\$vmname\backup3 directory to $destdir\$vmname\backup4"   
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: $PSCommandPath script on $env:computername could not rename $destdir\$vmname\backup3 directory to $destdir\$vmname\backup4.  Please check permissions. `n"
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
         exit
      }
   }
   if ( (Test-Path -path $destdir\$vmname\backup2)) { 
      echo "Renaming $destdir\$vmname\backup2 to $destdir\$vmname\backup3"
      Start-Sleep -s 30 
      Rename-Item $destdir\$vmname\backup2 $destdir\$vmname\backup3       
      if ( (Test-Path -path $destdir\$vmname\backup2)) { 
         Write-Host "ERROR: Could not rename $destdir\$vmname\backup2 directory to $destdir\$vmname\backup3"   
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: $PSCommandPath script on $env:computername could not rename $destdir\$vmname\backup2 directory to $destdir\$vmname\backup3.  Please check permissions. `n"
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
         exit
      }
   }
   if ( (Test-Path -path $destdir\$vmname\backup1)) { 
      echo "Renaming $destdir\$vmname\backup1 to $destdir\$vmname\backup2"
      Rename-Item $destdir\$vmname\backup1 $destdir\$vmname\backup2       
      Start-Sleep -s 30 
      if ( (Test-Path -path $destdir\$vmname\backup1)) { 
         Write-Host "ERROR: Could not rename $destdir\$vmname\backup1 directory to $destdir\$vmname\backup2"   
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: $PSCommandPath script on $env:computername could not rename $destdir\$vmname\backup1 directory to $destdir\$vmname\backup2.  Please check permissions. `n"
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
         exit
      }
   }
   if (!(Test-Path -path $destdir\$vmname\backup1)) { 
      echo "Creating $destdir\$vmname\backup1"   
      New-Item    $destdir\$vmname\backup1 -type directory | Out-Null 
      Start-Sleep -s 30 
      if (!(Test-Path -path $destdir\$vmname\backup1)) { 
         Write-Host "ERROR: Could not create $destdir\$vmname\backup1 directory"   
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: $PSCommandPath script on $env:computername could not create $destdir\$vmname\backup1 directory.  Please check permissions. `n"
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
         exit
      }
   }
   #
   #
   echo "Shutting down $vmname"
   stop-vm $vmname 
   #
   #
   # check to see if the virtual machine is still running
   # This section will only run if the "stop-vm $vmname" command fails
   $vmstate = Get-VM -VMName $vmname
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }

   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "$vmname still running after 5 minutes.  Trying -force"   ; stop-vm $vmname -force }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "Waiting 60 seconds for $vmname to shut down"             ; Start-Sleep -s 60      }
   if ($vmstate.State -ne "Off") { echo "$vmname still running after 10 minutes. Skipping backup" ; continue               }
   # add some more error checks in case state is "stopping" or has some other error
   #
   #
   # The Export-VM cmdlet exports a virtual machine to disk. 
   # This cmdlet creates a folder at a specified location having three subfolders: Snapshots, Virtual Hard Disks, and Virtual Machines. 
   # The Snapshots and Virtual Hard Disks folders contain the snapshots of and virtual hard disks of the specified virtual machine respectively. 
   # The Virtual Machines folder contains the configuration XML of the specified virtual machine.
   #
   # Confirm target folder exists
   if (!(Test-Path -path $destdir\$vmname\backup1)) { 
      Write-Host "ERROR: Could not create $destdir\$vmname\backup1 directory"   
      $subject = "ERROR in backup for $hostname"
      $body    = "ERROR: $PSCommandPath script on $env:computername could not create $destdir\$vmname\backup1 directory.  Please check permissions. `n"
      Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
      exit
   }
   #
   Write-Host "Backing up $vmname to $destdir\$vmname\backup1 (this can take a long time)"
   Export-VM -name  $vmname -path $destdir\$vmname\backup1
   #
   #
   echo "Starting   $vmname"
   start-vm         $vmname 
   echo "Waiting for 5 minutes after machine startup for disk activity to quiet down"
   Start-Sleep -s 300
}


# Put some explanatory text at the beginning of the backup report
$body = "This report is generated by the $PSCommandPath script on $env:computername `n"
$body = "This report shows the weekly full backups of the virtual machines on $env:computername `n`n"
$body = $body + "Filename`t`tSize`t`tDate `n"
$body = $body + "--------`t`t----`t`t---- `n"



# Figure out which files were backed up
foreach ($guest in $guests) {
   $vmname = $guest.VMName
   $files = get-childitem -recurse "$destdir\$vmname\backup1\$vmname\Virtual Hard Disks" | where {! $_.PSIsContainer}
   foreach ($file in $files) {
      #$file.Name                    #name of file
      #$file.Length                  #size in bytes
      $gb = $file.Length/1GB        #convert bytes to GigaBytes
      $gb =  [math]::Round($gb)     #round to zero decimal places
      #$file.LastWriteTime.toString()
      $body = $body + $file.Name + "`t`t" + $gb + " GB`t`t" + $file.LastWriteTime.toString() +" `n"
      #
      # Send an alert if any backups are more than 7 days old
      $limit = (Get-Date).AddDays(-7)
      if ($file.LastWriteTime -lt $limit ) {
         Write-Host "ERROR: backup file $file is more than 7 days old."
         $subject = "ERROR in backup for $hostname"
         $body    = "ERROR: the backup for $vmname is too old.  Please investigate `n" + $body
         Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port
      }
   }
}
Write-Host $body


# Put some explanatory text at the end of the backup report
$body = $body + "`n`n"
$body = $body + "HOW TO RESTORE `n--------------`n"
$body = $body + "1. Shutdown the problematic VM `n"
$body = $body + "2. Copy $destdir\VMname\backup1\VMname\Virtual Hard Disks\*.vhd to the folder containing the VM, overwriting the existing VHD files. `n"
$body = $body + "3. Start the problematic VM `n"
$body = $body + "4. If the VM still has problems, try restoring an earlier generation of the backup VHD files. `n`n"
$body = $body + "NOTE: This is a full image restore, so all changes since the last backup will be lost. `n"






# send email report
Write-Host "Sending backup report by email"
Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver -Port $port




# If the mail server does not allow relaying, you will get this message 
#Send-MailMessage : Mailbox unavailable. The server response was: 5.7.1 <nick@jeffrey.com>... Relaying denied
#At C:\util\backup.ps1:131 char:1
#+ Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpserver
#    + CategoryInfo          : InvalidOperation: (System.Net.Mail.SmtpClient:SmtpClient) [Send-MailMessage], SmtpFailedRecipientException
#    + FullyQualifiedErrorId : SmtpException,Microsoft.PowerShell.Commands.SendMailMessage

