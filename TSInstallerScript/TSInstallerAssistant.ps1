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

#Properties Reading
$file_content = Get-Content "$PSScriptRoot\arguments.properties"
$file_content = ($file_content -replace '\.', '\.') -join [Environment]::NewLine
$properties = ConvertFrom-StringData($file_content)
$spaceRequired = $properties.spaceRequired
$hosts = $properties.host
$Version = $properties.TSVersion

#Installer Path Initialization
IF([string]::IsNullOrEmpty($Installer)) {
	$Path = "\\etnafile02.embarcadero.com\ERStudio\Builds\ERTS\$Version\"
	$filter="*.exe"
	if(Test-Path $Path -PathType leaf) {
		$latest = Get-ChildItem -Path $Path -Filter $filter | Sort-Object LastAccessTime -Descending | Select-Object -First 1
		$latest = $latest.name
		If (!($Path.LastIndexOf("\")+1 -eq $Path.Length)) {
			$Path = $Path + "\"
		}
		$Installer = "$Path$latest"
	}
	
}

IF((Get-Item $Installer) -is [System.IO.DirectoryInfo]) {
	$Path = $Installer
	$filter="*.exe"
	if(Test-Path $Path -PathType leaf) {
		$latest = Get-ChildItem -Path $Path -Filter $filter | Sort-Object LastAccessTime -Descending | Select-Object -First 1
		$latest = $latest.name
		If (!($Path.LastIndexOf("\")+1 -eq $Path.Length)) {
			$Path = $Path + "\"
		}
		$Installer = "$Path$latest"
	}
}

$path = Split-Path -Path $Installer
$exeFile = Split-Path -Leaf $Installer
$destination = "$PSScriptRoot\Installers\"
$logFile = "$PSScriptRoot\TSInstallerAssistant_log.txt"

$Disk = Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = 'C:'"

Log "checking Disk space"
if($Disk.FreeSpace -ge $spaceRequired) {
	Log "space is sufficient, ready to start operation"
	Log "Checking Installer Path"
	if(-Not (Test-Path $installer -PathType leaf) ) {
		return
	}
	
    if(Test-Path $installer -PathType leaf) {
	
		Remove-Item $PSScriptRoot\Installers\*.exe -Force
		Log ("copying Installer from " + $Installer)
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
				$p = Start-Process $uninstExe -ArgumentList "/uninstall /quiet" -Verb runas -Wait
				If($p.ExitCode -ne 0) {
					Log "Uninstallation Failed  with error code $($p.ExitCode)."
					return
				}
				break
			}
		}
	}
	
	Log "Checking for Backup Folder"
	if(Test-Path $env:TEMP\TeamserverDataBackup) {
		Log "Backup folder exists, Deleting it"
		Remove-Item -path $env:TEMP\TeamServerDataBackup -recurse -Force
		Log "Backup folder Deleted"
	}
	
    if(Test-Path $destination$exeFile -PathType leaf) {
		Write-Output "$destination$exeFile"
		Log "Teamserver Installation Started"
		$p = Start-Process $destination$exeFile -ArgumentList "/quiet /install" -Verb runas -Wait
		If($p.ExitCode -ne 0) {
			Log "Installation Failed with error code $($p.ExitCode)."
			return
		}
		Log "Teamserver Installation Completed"
	}
	
}
else {
	Log "Disk space is not sufficient"
}


