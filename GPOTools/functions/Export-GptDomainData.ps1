﻿function Export-GptDomainData
{
<#
	.SYNOPSIS
		Generates a summary export of the source domain.
	
	.DESCRIPTION
		Generates a summary export of the source domain.
		This data is required or useful in several import stages.
	
	.PARAMETER Path
		The path to export to.
		Point at an existing folder.
	
	.PARAMETER Domain
		The domain to export the info of.
	
	.EXAMPLE
		PS C:\> Export-GptDomainData -Path '.'
	
		Exports the current domain's basic info into the current folder.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$resolvedPath = (Resolve-Path -Path $Path).ProviderPath
	}
	process
	{
		$domainObject = Get-ADDomain -Server $Domain
		$sourceDomain = [pscustomobject]@{
			Domain	      = $Domain
			DomainDNSName = $domainObject.DNSRoot
			NetBIOSName   = $domainObject.NetBIOSName
			BackupVersion = '1.0.0'
			Timestamp	  = (Get-Date)
			DomainSID	  = $domainObject.DomainSID.Value
		}

		$forestObject = Get-ADForest -Server $Domain
		$domains = $forestObject.Domains | Foreach-Object { Get-ADDomain -Server $_ -Identity $_ } | ForEach-Object {
			[PSCustomObject]@{
				DistinguishedName = $_.DistinguishedName
				Name			  = $_.Name
				SID			      = $_.DomainSID
				Fqdn			  = $_.DNSRoot
				ADObject		  = $_
				IsTarget          = $_.DomainSID -eq $sourceDomain.DomainSID
				IsRootDomain      = $_.DNSRoot -eq $forestObject.RootDomain
			}
		}

		[PSCustomObject]@{
			SourceDomain = $sourceDomain
			ForestDomains = $domains
		} | Export-Clixml -Path (Join-Path -Path $resolvedPath -ChildPath 'backup.clixml')
	}
}