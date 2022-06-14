#Backup MSSQL database with help powershell and archive backup with help 7-zip. Autoremove old backup. Logging all events.
#PowerShell 5
Param (
    [string] $debug,
    [boolean] $help
)


#Bugfix for windows 7.
if ([System.Environment]::OSVersion.Version.Major -eq 6) {
    Set-Location -Path $PSScriptRoot
}

#Initial variables
$global:ErrorStatus = $False
. .\currvar.ps1
$CurDate = Get-Date -Format yyyy-MM-dd-HH-mm
$LogPath = Join-Path -Path $rootPath -ChildPath "Logs" | Join-Path -ChildPath "$CurDate.log"


Import-Module sqlps -DisableNameChecking

#Get List Old Files
function Get-ListFiles($path, [byte] $days) {
    Write-Host "path = " $path
    [array]$ListFiles = @()
    For ($i = 0; $i -le($DB.Length-1); $i+=1) {
                $ListFiles += @(Get-ChildItem -Path $path"$($DB[$i])\*" -Attributes !Directory | Where-Object {$_.creationtime -lt $(Get-Date).adddays($days*-1)});
                $ListFiles += @(Get-ChildItem -Path $path"$($DB[$i])\old\*" | Where-Object {$_.creationtime -lt $(Get-Date).adddays(-367)});
                $ListFiles | Select-Object Name, Creationtime, Length | Out-Host;
            }
    return $ListFiles
}

#Kill working instances
function Stop-1C {
    C:\Windows\System32\taskkill.exe /F /IM 1cv7s.exe /T
    C:\Windows\System32\taskkill.exe /F /IM 1cv8c.exe /T
    C:\Windows\System32\taskkill.exe /F /IM 1cv8s.exe /T
    Wait-Event -Timeout $TimeoutKill
}

function Remove-OldFiles($type) {
    $ListLogFiles = Get-ChildItem -Path $RootPath\Logs"\*" -include *.log | Where-Object {$_.creationtime -lt $(Get-Date).adddays($DaysLogs*-1)};
    $ListLogFiles | Select-Object Name, Creationtime, Length | Out-Host;

    if ($type -eq "full") {
        Write-Host "Full Remove Logs"
        $ListLogFiles | Remove-Item -Force;  
    }
    elseif ($type -eq "debug") {
        Write-Host "Only Test without remove Log Files"

        if ($BackupRemotePath.Length -gt 1 ) {
            #$ListFilesRemote = Get-ListFiles -path $BackupRemotePath -days $DaysRemoteBackup
            #ListFileRemote  Remove-Item -Force;
            Get-ListFiles -path $BackupRemotePath -days $DaysRemoteBackup
        }
        #$ListFiles = Get-ListFiles -path $BackupPath -days $DaysBackup
        #$ListFiles | Remove-Item -Force;
        Get-ListFiles -path $BackupPath -days $DaysBackup
    }
}

#Backup and test archive
function Backup-1C {
    #Start logging
    Start-Transcript -Path $LogPath

    #Add temp disk to remote storage
    if ($BackupRemotePath.Length -gt 1 ) {
        New-PSDrive -Name "B" -Root $BackupRemotePath -PSProvider FileSystem
    }

    For ($i = 0; $i -le($DB.Length-1); $i+=1) {
        $FullBackUpPath = Join-Path -Path $BackupPath -ChildPath $DB[$i] | Join-Path -ChildPath "$($DB[$i])_db_$($CurDate)"
        $CurPass = $Passwd[$i]

        #Load SQL password from file
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $SQLUser, (Get-Content $PasswordSQL | ConvertTo-SecureString)

        #Backup SQL DB and archive
        Backup-SqlDatabase -ServerInstance $Server -Database $DB[$i] -BackupFile $FullBackUpPath".bak" -Credential $Cred
        & "c:\Program Files\7-Zip\7z.exe" a -t7z -p"$CurPass" $FullBackUpPath".7z" $FullBackUpPath".bak" -sdel

        #Test Backup
        $OutputText = & "c:\Program Files\7-Zip\7z.exe" t $FullBackUpPath".7z" *.bak -r -p"$CurPass" | Out-String
        $OutputText
        $global:ErrorStatus = -not($outputText -match 'Everything is Ok')

        $BackupSize = (Get-Item $FullBackUpPath".7z").length
        Write-Host "File Size: " $BackupSize " Bytes"

        if ($BackupSize -lt $ArchiveSize) {
            $global:ErrorStatus = $True
        }

        #CreateMonthlyBackup
        if ([datetime]::ParseExact($CurDate, 'yyyy-MM-dd-HH-mm', $mull).Day -eq 7) {
            if ($BackupRemotePath.Length -gt 1 ) {
                $DestPath = Join-Path -Path "B:\" -ChildPath $DB[$i] | Join-Path -ChildPath "old\$($DB[$i])_db_$($CurDate).7z"
            } else {
                $DestPath = Join-Path -Path $BackupPath -ChildPath $DB[$i] | Join-Path -ChildPath "old\$($DB[$i])_db_$($CurDate).7z"
            }
            #Выделяем только полный путь без имени файла
            $DestDir = Split-Path -Path $DestPath
            #Проверяем существование пути
            if (Test-Path -Path $DestDir) {
                #Создаём папку old, если нет
                New-Item -Path $DestDir -ItemType "directory" -Force
            }
            New-Item -Path $DestPath -ItemType "file" -Force
            Copy-Item -Path $FullBackUpPath".7z" -Destination $DestPath
        }

        #Copy to remote storage
        if ($BackupRemotePath.Length -gt 1 ) {
            Copy-Item -Path $FullBackUpPath".7z" -Destination "B:\$($DB[$i])\"
        }
    }

    #Remove old backup
    if ($BackupRemotePath.Length -gt 1 ) {
        $ListFilesRemote = Get-ListFiles -path $BackupRemotePath -days $DaysRemoteBackup
        $ListFilesRemote | Remove-Item -Force;
    }
    $ListFiles = Get-ListFiles -path $BackupPath -days $DaysBackup
    $ListFiles | Remove-Item -Force;

    #Remove old logs
    Remove-OldFiles -type full

    #End logging
    Stop-Transcript
}

#Send E-mail log
function Send-Log {
    if ($global:ErrorStatus) {
        $Subject = "WARNING Backup 1c"
    }
    else {
        $Subject = "Backup 1c"
    }
    $text = ""
    try {
        foreach ($line in (Get-Content $LogPath -ErrorAction Stop)) {
            $text += $line
            $text += "<br />"
            }
    }
    catch  [System.Management.Automation.ItemNotFoundException] {
        $Subject = "WARNING Backup 1c"
        $text += "Log File not found<br />"
    }
    finally {
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
}


if ($debug -eq "email") {
    # Write-Host "email"
    Send-Log
}
elseif ($debug -eq "removeold") {
    #(Get-Item "E:\Backup1C\Temp\Logs\2022-04-13-09-45.log").CreationTime=("08/03/2019 17:10:00")
    #(Get-Item "E:\Backup1C\Temp\Logs\2022-04-13-09-45.log").LastWriteTime=("08/03/2019 17:10:00")
    Write-Host "Test remove"
    Remove-OldFiles -type debug
}
elseif ($help) {
    Write-host ".\sql1c.ps1 -debug email"
    Write-host ".\sql1c.ps1 -debug removeold"
}
else {
    Stop-1C
    Backup-1C
    Send-Log
}
