$file_content = Get-Content "./arguments.properties"
$file_content = ($file_content -replace '\\', '\\') -join [Environment]::NewLine
#$file_content = ($file_content -replace '\\', '\\') -join [Environment]::NewLine
$properties = ConvertFrom-StringData($file_content)
$spaceRequired = $properties.spaceRequired
$hosts = $properties.host
#$Installer = $properties.installer
$Installer = "D:\GS\Idera_Team_Server_18.3.0-202003261622-x64.exe"
$path = Split-Path -Path $Installer
$exeFile = Split-Path -Leaf $Installer
#$installerExe = ""
$destination = [Environment]::GetFolderPath("Desktop")
Write-Output $destination
Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    function Get-Timestamp {Get-Date -Format 'MM/dd/yy hh:mm:ss'}
    $line = $(Get-Timestamp)+": $msg"
    Add-Content $env:TEMP\log.txt $line
}

$Disk = Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = 'C:'"

Log "checking Disk space"
if($Disk.FreeSpace -ge $spaceRequired) {
	Log "space is sufficient, ready to start operation"
	#Write-Output "space exists"
	#Write-Output $hosts, "	", $spaceRequired
	Write-Output "testing installer Path"
	if(-Not (Test-Path $installer -PathType leaf) ) {
		return
	}
	
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
		
		#Log "Uninstalling previous version if exists"
		#Start-Process -NoNewWindow ./uninstallpreviousversion.bat
		
		foreach($obj in Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") {
			$dname = $obj.GetValue("DisplayName")
			if ($dname -match "IDERA Team Server*") {
				Log "Uninstalling"
				$uninstExe = $obj.GetValue("BundleCachePath")
				Write-Output $uninstExe
				Start-Process $uninstExe -ArgumentList "/uninstall /quiet" -Verb runas -Wait
				Write-Output "Uninstallation completed"
				break
			}
		}
	}
	
	
	if(Test-Path $env:TEMP\TeamserverDataBackup) {
		Log "Backup exists"
		Remove-Item -path $env:TEMP\TeamServerDataBackup -recurse -Force
		Log "Backup Deleted"
	}
	
	if(Test-Path $installer -PathType leaf) {
	
		Log ("copying Installer from " + $Installer)
		Write-Output $Installer
        Write-Output $destination+$exeFile
		Copy-Item $installer -Destination $Destination
		Write-Output "copied"
        If (!($destination.LastIndexOf("\")+1 -eq $destination.Length)) {
            $destination = $destination + "\"
        }
		$installation = $destination+$exeFile
        Write-Output $installation
		Log "Teamserver Installation Started"
		
		Start-Process $destination$exeFile -ArgumentList "/quiet /install" -Verb runas -Wait
		Log "Teamserver Installation Completed"
		
	}
	
}
else {
	Log "Disk space is not sufficient"
}


