function Backup-GptPolicy
{
<#
	.SYNOPSIS
		Creates a full backup of all specified GPOs.
	
	.DESCRIPTION
		Creates a full backup of all specified GPOs.
		This includes permissions, settings, GPO Links and WMI Filter.
	
	.PARAMETER Path
		The path to the folder to export into.
		Folder must exist.
	
	.PARAMETER Name
		Filter Policy Objects by policy name.
		By default, ALL policies are targeted.
	
	.PARAMETER GpoObject
		Specify explicitly which GPOs to export.
		Accepts output of Get-GPO
	
	.PARAMETER Domain
		The source domain to export from.
	
	.PARAMETER Identity
		Additional identities to export.
		Identites are names of groups that are used for matching groups when importing policies.
	
	.EXAMPLE
		PS C:\> Backup-GptPolicy -Path .
	
		Export all policies to file.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string]
		$Name = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[string]
		$Domain = $env:USERDNSDOMAIN,
		
		[string[]]
		$Identity
	)
	
	begin
	{
		$resolvedPath = (Resolve-Path -Path $Path).ProviderPath
		$policyFolder = New-Item -Path $resolvedPath -Name GPO -ItemType Directory -Force
		Write-Verbose "Resolved output path to: $resolvedPath"
	}
	process
	{
		Write-Verbose "Resolving GPOs to process"
		$gpoObjects = $GpoObject
		if (-not $GpoObject)
		{
			$gpoObjects = Get-GPO -All -Domain $Domain | Where-Object DisplayName -Like $Name
		}
		Write-Verbose "Exporting GPO Objects"
		$gpoObjects | Export-GptObject -Path $policyFolder.FullName -Domain $Domain
		Write-Verbose "Exporting GP Links"
		Export-GptLink -Path $resolvedPath -Domain $Domain
		Write-Verbose "Exporting GP Permissions"
		$gpoObjects | Export-GptPermission -Path $resolvedPath -Domain $Domain
		Write-Verbose "Exporting WMI Filters"
		$gpoObjects | Export-GptWmiFilter -Path $resolvedPath -Domain $Domain
		Write-Verbose "Exporting Identities"
		Export-GptIdentity -Path $resolvedPath -Domain $Domain -Name $Identity -GpoObject $gpoObjects
		Write-Verbose "Exporting Domain Information"
		Export-GptDomainData -Path $resolvedPath -Domain $Domain
	}
}
