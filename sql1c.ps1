#Backup MSSQL database with help powershell and archive backup with help 7-zip. Autoremove old backup. Logging all events.
#PowerShell 5

#Initial variables
. .\currvar.ps1
$CurDate = Get-Date -Format yyyy-MM-dd-HH-mm
$LogPath = Join-Path -Path $rootPath -ChildPath "Logs" | Join-Path -ChildPath "$CurDate.log"

Import-Module sqlps -DisableNameChecking

#Kill working instances
function Kill-1C {
    C:\Windows\System32\taskkill.exe /F /IM 1cv7s.exe /T
    C:\Windows\System32\taskkill.exe /F /IM 1cv8s.exe /T
    Wait-Event -Timeout $TimeoutKill
}
#Backup and test archive
function Backup-1C {
    #Start logging
    Start-Transcript -Path $LogPath

    For ($i = 0; $i -le($DB.Length-1); $i+=1) {
        $FullBackUpPath = Join-Path -Path $BackupPath -ChildPath $DB[$i] | Join-Path -ChildPath "$($DB[$i])_db_$($CurDate)"
        $СurPass = $Passwd[$i]

        #Load SQL password from file
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $PasswordSQL | ConvertTo-SecureString)

        #Backup SQL DB and archive
        Backup-SqlDatabase -ServerInstance $Server -Database $DB[$i] -BackupFile $FullBackUpPath".bak" -Credential $Cred
        & "c:\Program Files\7-Zip\7z.exe" a -t7z -p"$СurPass" $FullBackUpPath".7z" $FullBackUpPath".bak" -sdel

        #Test Backup
        & "c:\Program Files\7-Zip\7z.exe" t $FullBackUpPath".7z" *.bak -r -p"$СurPass"

        $BackupSize = (Get-Item $FullBackUpPath".7z").length
        Write-Host "File Size: " $BackupSize " Bytes"

        if ($BackupSize -lt $ArchiveSize) {
            Send-Log
        }

        #Remove old backup
        #Get-ChildItem -Path $BackupPath"\*" -include *.7z | ?{$_.creationtime -lt $(Get-Date).adddays($daysBackup*-1)} | Remove-Item -Force; 
        Get-ChildItem -Path $BackupPath"$($DB[$i])\*" | ?{$_.creationtime -lt $(Get-Date).adddays($DaysBackup*-1)} | Remove-Item -Force;
    }

    #Remove old logs
    Get-ChildItem -Path $RootPath\Logs"\*" -include *.log | ?{$_.creationtime -lt $(Get-Date).adddays($DaysLogs*-1)} | Remove-Item -Force;

    #End logging
    Stop-Transcript
}
#Send E-mail log
function Send-Log {
    $Subject = "backup 1c"
    $text = ""
    foreach ($line in (Get-Content $LogPath)) {
        $text += $line
        $text += "<br />"
        }
    $Body = $text
    $Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $EmailFrom, (Get-Content $PasswordEMail | ConvertTo-SecureString)
    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, 587)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($EmailFrom, $Cred.Password);
    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.From = New-Object System.Net.Mail.MailAddress($EmailFrom)
    $emailMessage.Subject = $Subject
    $emailMessage.IsBodyHtml = $true
    $emailMessage.Body = $Body
    #$emailMessage.To.Add($EmailTo)
    foreach($EmailTo in $EmailToList) {
        $emailMessage.To.Add($EmailTo)
    }
    $SMTPClient.Send($emailMessage)
}

Kill-1C
Backup-1C
