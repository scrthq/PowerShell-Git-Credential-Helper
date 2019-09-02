#!/usr/bin/env pwsh
<#
The above should work in PowerShell Core on Windows, Mac and Linux.
To use Windows PowerShell instead, replace 'pwsh' with 'powershell' on line 1.

You MUST NOT have anything in your PowerShell profile that writes messages
to a stream other than STDOUT, e.g. with Write-Output. Messages on the
Information (e.g. with Write-Information or Write-Host), Verbose, Warning,
or Error streams will be interpreted by Git as credential values and fail
authentication.
#>
Param (
    [Parameter(Mandatory,Position = 0)]
    [string]
    $Operation,
    [Parameter(Position = 1,ValueFromRemainingArguments)]
    $Arguments,
    [Parameter()]
    [ValidateSet('CliXml','PSProfile')]
    [string]
    $Provider = 'CliXml'
)
[uri]$repo = git remote get-url origin *>&1
$repoBase = $repo.AbsoluteUri.Replace($repo.AbsolutePath,'')
switch ($Provider) {
    CliXml {
        $script:getStore = {
            $storeDir = [System.IO.Path]::Combine($HOME,'.powershell')
            $script:storeXml = [System.IO.Path]::Combine($storeDir,'gitcredentials.xml')
            if (-not (Test-Path $storeDir)) {
                New-Item $storeDir -ItemType Directory -Force | Out-Null
            }
            $script:store = if (Test-Path $script:storeXml) {
                Import-Clixml $script:storeXml
            }
            else {
                @{ }
            }
        }
        $script:getCreds = {
            if (
                $script:store.ContainsKey($repo.AbsoluteUri) -and
                $script:store[$repo.AbsoluteUri] -is [pscredential]
            ) {
                $script:creds = $script:store[$repo.AbsoluteUri]
            }
            elseif (
                $script:store.ContainsKey($repoBase) -and
                $script:store[$repoBase] -is [pscredential] -and -not (
                    $script:store.ContainsKey($repo.AbsoluteUri) -and
                    $script:store[$repo.AbsoluteUri] -eq "BASE FAILED"
                )
            ) {
                $script:creds = $script:store[$repoBase]
                $script:store[$repo.AbsoluteUri] = "USING BASE"
            }
            else {
                # SecureString is necessary to pause git for both input items, otherwise
                # it will return the prompt text immediately and not allow input.
                $userSec = Read-Host "[pwsh] Enter username for host $repoBase" -AsSecureString
                $user = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                        $userSec
                    )
                )
                $pass = Read-Host "[pwsh] Enter password for user '$user' on host $repoBase" -AsSecureString
                $script:creds = New-Object PSCredential $user,$pass
                if (
                    -not $script:store.ContainsKey($repoBase) -or (
                        $script:store.ContainsKey($repo.AbsoluteUri) -and
                        $script:store[$repo.AbsoluteUri] -eq "BASE FAILED"
                    )
                ) {
                    $script:store[$repoBase] = $script:creds
                }
                Export-Clixml -Depth 4 -InputObject $script:store -Path $script:storeXml | Out-Null
            }
        }
        $script:storeCreds = {
            if ($script:store[$repo.AbsoluteUri] -eq "USING BASE") {
                $script:store[$repo.AbsoluteUri] = $script:store[$repoBase]
            }
            Export-Clixml -Depth 4 -InputObject $script:store -Path $script:storeXml | Out-Null
        }
        $script:eraseCreds = {
            if (
                $script:store.ContainsKey($repo.AbsoluteUri) -and
                $script:store[$repo.AbsoluteUri] -eq "USING BASE"
            ) {
                $script:store[$repo.AbsoluteUri] = "BASE FAILED"
                Export-Clixml -Depth 4 -InputObject $script:store -Path $script:storeXml | Out-Null
            }
            elseif ($script:store.ContainsKey($repo.AbsoluteUri)) {
                $script:store.Remove($repo.AbsoluteUri) | Out-Null
            }
            elseif ($script:store.ContainsKey($repoBase)) {
                $script:store.Remove($repoBase) | Out-Null
            }
        }
    }
    PSProfile {
        $script:getStore = {
            Import-Module PSProfile -Verbose:$false *>&1 | Out-Null
            if (-not $Global:PSProfile.Vault._secrets.ContainsKey('GitCredentials')) {
                $Global:PSProfile.Vault._secrets['GitCredentials'] = @{}
            }
            $script:store = $Global:PSProfile.Vault._secrets['GitCredentials']
        }
        $script:getCreds = {
            if (
                $script:store.ContainsKey($repo.AbsoluteUri) -and
                $script:store[$repo.AbsoluteUri] -is [pscredential]
            ) {
                $script:creds = $script:store[$repo.AbsoluteUri]
            }
            elseif (
                $script:store.ContainsKey($repoBase) -and
                $script:store[$repoBase] -is [pscredential] -and -not (
                    $script:store.ContainsKey($repo.AbsoluteUri) -and
                    $script:store[$repo.AbsoluteUri] -eq "BASE FAILED"
                )
            ) {
                $script:creds = $script:store[$repoBase]
                $script:store[$repo.AbsoluteUri] = "USING BASE"
                $Global:PSProfile.Vault._secrets['GitCredentials'] = $script:store
                Save-PSProfile -Verbose:$false *>&1 | Out-Null
            }
            else {
                # SecureString is necessary to pause git for both input items, otherwise
                # it will return the prompt text immediately and not allow input.
                $userSec = Read-Host "[pwsh] Enter username for host $repoBase" -AsSecureString
                $user = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                        $userSec
                    )
                )
                $pass = Read-Host "[pwsh] Enter password for user '$user' on host $repoBase" -AsSecureString
                $script:creds = New-Object PSCredential $user,$pass
                if (
                    -not $script:store.ContainsKey($repoBase) -or (
                        $script:store.ContainsKey($repo.AbsoluteUri) -and
                        $script:store[$repo.AbsoluteUri] -eq "BASE FAILED"
                    )
                ) {
                    $script:store[$repoBase] = $script:creds
                }
                $Global:PSProfile.Vault._secrets['GitCredentials'] = $script:store
                Save-PSProfile -Verbose:$false *>&1 | Out-Null
            }
        }
        $script:storeCreds = {
            if ($script:store[$repo.AbsoluteUri] -eq "USING BASE") {
                $script:store[$repo.AbsoluteUri] = $script:store[$repoBase]
            }
            $Global:PSProfile.Vault._secrets['GitCredentials'] = $script:store
            Save-PSProfile -Verbose:$false *>&1 | Out-Null
        }
        $script:eraseCreds = {
            if (
                $script:store.ContainsKey($repo.AbsoluteUri) -and
                $script:store[$repo.AbsoluteUri] -eq "USING BASE"
            ) {
                $script:store[$repo.AbsoluteUri] = "BASE FAILED"
                $Global:PSProfile.Vault._secrets['GitCredentials'] = $script:store
                Save-PSProfile -Verbose:$false *>&1 | Out-Null
            }
            elseif ($script:store.ContainsKey($repo.AbsoluteUri)) {
                $script:store.Remove($repo.AbsoluteUri) | Out-Null
            }
            elseif ($script:store.ContainsKey($repoBase)) {
                $script:store.Remove($repoBase) | Out-Null
            }
        }
    }
}

.$script:getStore

switch ($Operation) {
    get {
        .$script:getCreds
        # Write-Host is needed as it appears git-credential is receiving input from the information
        # stream for PowerShell/pwsh. Write-Output does not return values as expected and
        # authentication will fail.
        Write-Host "username=$($script:creds.UserName)"
        Write-Host "password=$($script:creds.GetNetworkCredential().Password)"
    }
    store {
        .$script:storeCreds
    }
    erase {
        .$script:eraseCreds
    }
}
