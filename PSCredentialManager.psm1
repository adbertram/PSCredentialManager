function Get-CachedCredential
{
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$TargetName
	)

	$output = @()
	if (-not $PSBoundParameters.ContainsKey('ComputerName') -and -not ($PSBoundParameters.ContainsKey('Name')))
	{
		ConvertTo-CachedCredential -CmdKeyOutput (cmdkey /list)
	} elseif (-not $PSBoundParameters.ContainsKey('ComputerName') -and $PSBoundParameters.ContainsKey('Name')) {
		ConvertTo-CachedCredential -CmdKeyOutput (cmdkey /list:$TargetName)
	} else {
		foreach ($c in $ComputerName) {
			$cmdkeyOutput = Invoke-PsExec -ComputerName $c -Command 'cmdkey /list'
			if ($cred = ConvertTo-CachedCredential -CmdKeyOutput $cmdkeyOutput) {
				[pscustomobject]@{
					ComputerName = $c
					Credentials = $cred
				}
			}
		}
	}
}

function Install-PsExec
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Uri = 'https://download.sysinternals.com/files/PSTools.zip'
	)

	$zipPath = "$env:TEMP\PSTools.zip"
	$folder = "$env:TEMP\PSTools"
	if (-not (Test-Path -Path $zipPath -PathType Container)) {
		Invoke-WebRequest -Uri $Uri -UseBasicParsing -OutFile $zipPath
		Expand-Archive -Path $zipPath -DestinationPath $folder
	}
	$null = & "$folder\psexec.exe" -accepteula
	
}

function Invoke-PsExec
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Command,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential = (Get-Credential -Message 'Enter credential to authenticate to remote computer(s).' -UserName (whoami))
	)

	try {

		if (-not (Test-PsExecInstalled)) {
			Install-PsExec
		}

		$x = $Command -split ' '
		$cmd = $x[0]
		$cmdArgs = $x[1..($x.Length)]

		$startParams = @{
			FilePath = "$env:temp\pstools\psexec.exe"
			Wait = $true
			NoNewWindow = $true
			ArgumentList = "\\$ComputerName -user $($Credential.UserName) -pass $($Credential.GetNetworkCredential().Password) $cmd $cmdArgs"
			RedirectStandardError = "$env:TEMP\err.txt"
			RedirectStandardOutput = "$env:TEMP\out.txt"
		}
		Start-Process @startParams
		Get-Content -Path "$env:TEMP\out.txt" -Raw
	} catch {
		$PSCmdlet.ThrowTerminatingError($_)
	} finally {
		@("$env:TEMP\err.txt","$env:TEMP\out.txt").foreach({
			Remove-Item -Path $_ -ErrorAction Ignore
		})
	}
}

function Test-PsExecInstalled
{
	[OutputType('bool')]
	[CmdletBinding()]
	param
	()
	if (-not (Test-Path -Path "$env:TEMP\PSTools\psexec.exe" -PathType Leaf)) {
		$false
	} else {
		$true
	}
}

function Remove-CachedCredential
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TargetName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)

	if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
		$null = cmdkey /delete:$TargetName
	} else {
		foreach ($c in $ComputerName) {
			$invParams = @{
				ComputerName = $c
				Command = "cmdkey /delete:$TargetName"
			}
			$null = Invoke-PsExec @invParams
		}
	}
	
}

function New-CachedCredential
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TargetName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Username,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Password,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)

	if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
		$null = cmdkey /add:$TargetName /user:$Username /pass:$Password
	} else {
		foreach ($c in $ComputerName) {
			$invParams = @{
				ComputerName = $c
				Command = "cmdkey /add:$TargetName /user:$Username /pass:$Password"
			}
			$null = Invoke-PsExec @invParams
		}
	}
	
}

function ConvertTo-MatchValue
{
	[OutputType('string')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$String,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$RegularExpression
	)

	([regex]::Match($String,$RegularExpression)).Groups[1].Value
	
}

function ConvertTo-CachedCredential
{
	[OutputType('pscustomobject')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		$CmdKeyOutput
	)

	if (-not ($CmdKeyOutput.where({ $_ -match '\* NONE \*' }))) {
		if (@($CmdKeyOutput).Count -eq 1) {
			$CmdKeyOutput = $CmdKeyOutput -split "`n"
		}
		$nullsRemoved = $CmdKeyOutput.where({ $_ })
		$i = 0
		foreach ($j in $nullsRemoved) {
			if ($j -match '^\s+Target:') {
				[pscustomobject]@{
					Name = (ConvertTo-MatchValue -String $j -RegularExpression 'Target: .+:target=(.*)$').Trim()
					Category = (ConvertTo-MatchValue -String $j -RegularExpression 'Target: (.+):').Trim()
					Type = (ConvertTo-MatchValue -String $nullsRemoved[$i + 1] -RegularExpression 'Type: (.+)$').Trim()
					User = (ConvertTo-MatchValue -String $nullsRemoved[$i + 2] -RegularExpression 'User: (.+)$').Trim()
					Persistence = ($nullsRemoved[$i + 3]).Trim()
				}
			}
			$i++
		}
	}
}