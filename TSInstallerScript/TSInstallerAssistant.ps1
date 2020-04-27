param([String]$Installer)

#Log function
Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    function Get-Timestamp {Get-Date -Format 'MM/dd/yy hh:mm:ss'}
    $line = $(Get-Timestamp)+": $msg"
    $line | Out-File $LogFile -Append -Force
}

#Properties Initialization
$properties = (ConvertFrom-StringData([Regex]::Escape((Get-Content "$PSScriptRoot/arguments.properties" -raw)) -replace "(\\r)?\\n", [Environment]::NewLine))
$spaceRequired = $properties.spaceRequired
$hosts = $properties.host
$Version = $properties.TSVersion
$destination = "$PSScriptRoot\Installers\"
$logFile = "$PSScriptRoot\TSInstallerAssistant_log.txt"

IF([string]::IsNullOrEmpty($Installer)) {
	$Installer = $properties.installer
}

#Disk Space Checking
Log "checking Disk space"
$Disk = Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = 'C:'"
if($Disk.FreeSpace -le $spaceRequired) {
	Log "Disk Space Insufficient"
	return
}
Log "space is sufficient, ready to start operation"

#Installer Path Initialization
IF([string]::IsNullOrEmpty($Installer)) {
	$Path = "\\etnafile02.embarcadero.com\ERStudio\Builds\ERTS\$Version\"
	$filter="*.exe"
	if(Test-Path $Path) {
		$latest = Get-ChildItem -Path $Path -Filter $filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		$latest = $latest.name
		If (!($Path.LastIndexOf("\")+1 -eq $Path.Length)) {
			$Path = $Path + "\"
		}
		$Installer = "$Path$latest"
	}
	else {
		Log "Default path is not found"
	}
	
}
IF($Installer) {
	IF((Get-Item $Installer) -is [System.IO.DirectoryInfo]) {
		$Path = $Installer
		$filter="*.exe"
		if(Test-Path $Path) {
			$latest = Get-ChildItem -Path $Path -Filter $filter | Sort-Object LastAccessTime -Descending | Select-Object -First 1
			$latest = $latest.name
			If (!($Path.LastIndexOf("\")+1 -eq $Path.Length)) {
				$Path = $Path + "\"
			}
			$Installer = "$Path$latest"
		}
		else {
			Log "given installer path is not found"
		}
	}
}

IF([string]::IsNullOrEmpty($Installer)) {
	Log "Installer is not valid"
	return
}

Log "Checking Installer Path"
if(-Not (Test-Path $installer -PathType leaf) ) {
	Log "Installer Not Found"
	return
}

if(-Not (Test-Path $destination) ) {
	Log "Creating Installers Folder"
	New-Item -Path "$PSScriptRoot" -Name "installers" -ItemType "directory"
}

$path = Split-Path -Path $Installer
$exeFile = Split-Path -Leaf $Installer

#Copying New Installer
if(Test-Path $installer -PathType leaf) {

	#Removing Exe files in Installers folder
	Log "Cleaning Installers folder"
	Remove-Item $PSScriptRoot\Installers\*.exe -Force
	#Copying new Installer
	Log ("copying Installer " + $Installer)
	Copy-Item $installer -Destination $Destination
	
}

Log "Uninstalling previous version if exists"
If (Get-Service EmbarcaderoTeamServer -ErrorAction SilentlyContinue) {
	If ((Get-Service EmbarcaderoTeamServer).Status -eq 'Running') {
		Stop-Service EmbarcaderoTeamServer
		Log "stopping teamserver service"
	}
	If (Get-Service RepoSrvComm -ErrorAction SilentlyContinue) {
		If ((Get-Service RepoSrvComm).Status -eq 'Running') {
			Stop-Service RepoSrvComm
			Log "stopping repo server communication service"
		}
	}
	If (Get-Service RepoSrvDb -ErrorAction SilentlyContinue) {
		If ((Get-Service RepoSrvDb).Status -eq 'Running') {
			Stop-Service RepoSrvDb
			Log "stopping repo server DB service"
		}
	}
	
	If (Get-Service RepoSrvEvents -ErrorAction SilentlyContinue) {
		If ((Get-Service RepoSrvEvents).Status -eq 'Running') {
			Stop-Service RepoSrvEvents
			Log "stopping Repo server Events service"
		}
	}
			
	foreach($obj in Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") {
		$dname = $obj.GetValue("DisplayName")
		if ($dname -match "IDERA Team Server*") {
			Log "Uninstalling TS Version:$($obj.GetValue('BundleVersion'))"
			$uninstExe = $obj.GetValue("BundleCachePath")
			Write-Output $uninstExe
			Start-Process $uninstExe -ArgumentList "/uninstall /quiet" -Verb runas -Wait
			break
		}
	}
}

#Deleting Backup Folder if exists
Log "Checking for Backup Folder"
if(Test-Path $env:TEMP\TeamserverDataBackup) {
	Log "Backup folder exists, Deleting it"
	Remove-Item -path $env:TEMP\TeamServerDataBackup -recurse -Force
	Log "Backup folder Deleted"
}

#Installation of new Installer
if(Test-Path $destination$exeFile -PathType leaf) {
	Log "Teamserver Installation Started"
	Start-Process $destination$exeFile -ArgumentList "/quiet /install" -Verb runas -Wait
	Log "Teamserver Installation Completed"
}

