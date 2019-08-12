#Address SQL Server
[String] $Server = 'localhost\sqlexpress'
#Paths
[String] $RootPath = 'E:\Backup1C'
[String] $BackupPath = 'E:\Backup1C\Backup\'

#Генерация пароля
#"My5tr0ngPa55w0rd" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "E:\Backup1C\password_"
#Задача должна запускаться от пользователя, который сгенерировал пароль. Иначе ошибка ConvertTo-SecureString : Ключ не может быть использован в указанном состоянии.

#SQL user
[String] $User = 'SQLUserName'
#SQL password file
[String] $PasswordSQL = "$rootPath\password"
#E-mail password file
[String] $PasswordEMail = "$rootPath\passwordEMail"
#E-mail from
[String] $EmailFrom = "test@domain.com"
# Через запятую указать получателей в массиве
[String[]] $EmailToList = @(
    "test2@domain.com"
    )
[String] $SMTPServer = "smtp.domain.com"


#SQL db name
[String[]] $DB = @(
    'TestBD1',
    'TestBD2')

#7z archive password
[String[]] $Passwd = @(
    "Pa55w0rd1", 
    "Pa55w0rd2"
    )

#Save days for backups
[byte] $DaysBackup = 30;
#Save days for logs
[byte] $DaysLogs = 30;

#Timeout for 1c kill
[byte] $TimeoutKill = 15;

#Minimal archive size for test in bytes
[int] $ArchiveSize = 1000;
