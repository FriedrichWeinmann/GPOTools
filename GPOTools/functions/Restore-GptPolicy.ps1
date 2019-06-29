function Restore-GptPolicy
{
<#
	.SYNOPSIS
		Performs a full restore of GPOs exported with Backup-GptPolicy.
	
	.DESCRIPTION
		Performs a full restore of GPOs exported with Backup-GptPolicy.
		This includes executing all the relevant import commands in the optimal order.
	
	.PARAMETER Path
		The root path into which the backup was exported.
	
	.PARAMETER Name
		Only restore GPOs with matching name.
	
	.PARAMETER Domain
		The domain into which to restore the policy objects.
	
	.PARAMETER IdentityMapping
		A hashtable mapping source identities to destination identities.
		Use this to map groups that do not share the same name between source and destination.
	
	.EXAMPLE
		PS C:\> Restore-GptPolicy -Path '.'
	
		Perform a full restore/import of the backup written to the current folder.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string[]]
		$Name = '*',
		
		[string]
		$Domain = $env:USERDNSDOMAIN,
		
		[hashtable]
		$IdentityMapping = @{}
	)
	
	begin
	{
		$common = @{
			Path = $Path
			Domain = $Domain
		}
		
		Write-Verbose "Importing Domain Data"
		Import-GptDomainData -Path $Path
	}
	process
	{
		Write-Verbose "Importing Identities"
		Import-GptIdentity @common -Name $Name -Mapping $IdentityMapping
		Write-Verbose "Importing WMI Filters"
		Import-GptWmiFilter @common
		Write-Verbose "Importing Objects"
		Import-GptObject @common -Name $Name
		Write-Verbose "Importing Permissions"
		Import-GptPermission @common -Name $Name
		Write-Verbose "Importing GPO Links"
		Import-GptLink @common -Name $Name
	}
}
