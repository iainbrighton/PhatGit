$currentDir = Split-Path -parent $MyInvocation.MyCommand.Path;
$moduleName = "PhatGit";
$userModuleDir = "$([System.Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Modules\$moduleName";
$iseProfileFile = "$([System.Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1";

$copyToModules = Read-Host "Install $moduleName to your Modules directory [y/n]?";
if ($copyToModules -ieq 'y') {
	if (Test-Path $userModuleDir) {
		Write-Host "Removing directory '$userModuleDir'..." -NoNewline;
		Remove-Item -Path $userModuleDir -Force	-Recurse;
        Write-Host " OK";
	}
	
	Write-Host "Unblocking $moduleName files..." -NoNewLine;
	Get-ChildItem $currentDir | Unblock-File;
	Write-Host " OK";

	Write-Host "Copying $moduleName files to '$userModuleDir'..." -NoNewline;
    New-Item -Path $userModuleDir -ItemType Container -Force | Out-Null;
	Copy-Item -Path "$currentDir\*.ps?1" -Destination $userModuleDir -Force;
    Copy-Item -Path "$currentDir\LICENSE" -Destination $userModuleDir -Force;
    Copy-Item -Path "$currentDir\README.md" -Destination $userModuleDir -Force;
    Write-Host " OK";
}

Write-Host "";

$installToProfile = Read-Host "Install $moduleName to ISE Profile (will start when ISE starts) [y/n]?";

if ($installToProfile -ieq 'y') {
	if (!(Test-Path $iseProfileFile)) {
		Write-Host "Creating file '$iseProfileFile'..." -NoNewline;
		New-Item -Path $iseProfileFile -ItemType file | Out-Null;
        Write-Host " OK";
		$contents = "";
	} else {
		Write-Host "Reading file '$iseProfileFile'..." -NoNewLine;
		$contents = Get-Content -Path $iseProfileFile | Select-String -Pattern $moduleName;
        Write-Host " OK";
	}

	$importModule = "Import-Module $moduleName";

	if ($contents -inotmatch $moduleName) {
		Write-Host "Adding '$importModule'..." -NoNewLine;
		Add-Content -Path $iseProfileFile -Value $importModule | Out-Null;
        Write-Host " OK";
	} else {
		Write-Host "Import command for $moduleName already exists in Powershell ISE profile.";
	}
}
