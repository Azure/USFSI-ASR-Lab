param (
    [string]$AdminUsername,
    [string]$AdminPassword
)

# Convert the plain text password to a secure string
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

# Set the credentials
$credential = New-Object System.Management.Automation.PSCredential($adminUsername, $SecurePassword)

# Get the disk you attached
$disk = Get-Disk -ErrorAction SilentlyContinue | Where-Object PartitionStyle -Eq 'RAW'

if ($disk) {
    # Initialize the disk
    Initialize-Disk -Number $disk.Number -ErrorAction SilentlyContinue

    # Create a new partition
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter -ErrorAction SilentlyContinue

    # Format the partition
    Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "DataDisk" -Confirm:$false -ErrorAction SilentlyContinue

    # Output the drive letter
    $driveletter = "$($partition.DriveLetter):"
}
else {
    # Get the existing partition
    $partition = Get-Partition -DriveLetter (Get-Volume -FileSystemLabel "DataDisk").DriveLetter

    # Output the drive letter
    $driveletter = "$($partition.DriveLetter):"
}

# Create DB folder on the new drive
# $dataPath = New-Item -Path "${driveletter}\SQLData" -ItemType Directory
$directoryPath = "${driveletter}\SQLData"
if (-Not (Test-Path -Path $directoryPath)) {
    $dataPath = New-Item -Path $directoryPath -ItemType Directory
}
else {
    $dataPath = $directoryPath
}

# Download the AdventureWorks database
$downloadPath = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Backup"
Invoke-WebRequest -Uri "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2019.bak" -OutFile "${downloadPath}\AdventureWorksLT2019.bak"

# Install and import the SQLSERVER PS Module
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck | Import-Module

# Restore the AdventureWorks database
$databaseName = "AdventureWorksLT2019"
$dataFile = "${dataPath}\AdventureWorksLT2019_Data.mdf"
$logFile = "${dataPath}\AdventureWorksLT2019_Log.ldf"
$backupPath = "${downloadPath}\AdventureWorksLT2019.bak"

# Define the restore query
$restoreQuery = @"
RESTORE DATABASE [$databaseName]
FROM DISK = N'$backupPath'
WITH MOVE N'AdventureWorksLT2019_Data' TO N'$dataFile',
MOVE N'AdventureWorksLT2019_Log' TO N'$logFile',
NOUNLOAD, STATS = 10
"@

# Write the restore query to a new file
$sqlFilePath = "${downloadPath}\RestoreDB.sql"
$restoreQuery | Out-File -FilePath $sqlFilePath

# Define the script block to run the SQL command
$scriptBlock = {
    param ($sqlFilePath)
    SqlServer\Invoke-Sqlcmd -ServerInstance . -InputFile $sqlFilePath -TrustServerCertificate
}

# Run the script block as the other user
Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $sqlFilePath -Credential $credential -ComputerName localhost
