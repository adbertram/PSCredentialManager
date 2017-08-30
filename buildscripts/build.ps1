$ErrorActionPreference = 'Stop'

try {

	$manifestFilePath = "$env:APPVEYOR_BUILD_FOLDER\PSCredentialManager.psd1"
	$manifestContent = Get-Content -Path $manifestFilePath -Raw

	## Update the module version based on the build version and limit exported functions
	$replacements = @{
		"ModuleVersion = '.*'"     = "ModuleVersion = '$env:APPVEYOR_BUILD_VERSION'"
		"FunctionsToExport = '\*'" = "FunctionsToExport = 'Get-CachedCredential','Removed-CachedCredential','New-CachedCredential'"
	}		

	$replacements.GetEnumerator() | foreach {
		$manifestContent = $manifestContent -replace $_.Key, $_.Value
	}

	$manifestContent | Set-Content -Path $manifestFilePath

} catch {
	Write-Error -Message $_.Exception.Message
	$host.SetShouldExit($LastExitCode)
}