# PSCredentialManager

PSCredentialManager is a PowerShell module that allows the user to manage cached credentials across the local, a remote or many remote computers at once. By it's nature, cached credentials are usually managed on local machines only. However, by using a combination of the great `psexec` tool and the `cmdkey` utility, a PowerShell module can be crafted around these tools to provide a seamless way to list, add and remove cached credentials from many computers at once!

## Example Usage

### Retrieving all credentials stored locally

`PS> Get-CachedCredential`

## Retrieing all credentials stored on a remote computer

`PS> Get-CachedCredential -ComputerName REMOTE`

## Retrieing a credential matching a certain name on a remote computer

`PS> Get-CachedCredential -ComputerName REMOTE -TargetName FOO`

## Retrieving all credentials stored on many remote computers

`PS> Get-CachedCredential -ComputerName REMOTE,REMOTE2,REMOTE3`

## Adding credentials

`PS> New-CachedCreential -TargetName 'FOO' -UserName userhere -Password passhere`

## Removing credentials

`PS> Remove-CachedCredential`
