﻿function Get-DomainData
{
<#
	.SYNOPSIS
		Retrieves common domain data, while caching results.
	
	.DESCRIPTION
		Retrieves common domain data, while caching results.
		Reduces overhead of looking up the same object again and again.
	
	.PARAMETER Domain
		The domain to retrieve data for.
	
	.EXAMPLE
		PS C:\> Get-DomainData -Domain Contoso.com
	
		Returns domain data for the domain contoso.com
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Domain
	)
	
	begin
	{
		if (-not $script:domainData)
		{
			$script:domainData = @{ }
			
			#region Pre-Seed information for all domains in forest
			$forestObject = Get-ADForest
			$domains = $forestObject.Domains | Get-ADDomain | ForEach-Object {
				[PSCustomObject]@{
					DistinguishedName = $_.DistinguishedName
					Name			  = $_.Name
					SID			      = $_.DomainSID
					Fqdn			  = $_.DNSRoot
					ADObject		  = $_
				}
			}
			foreach ($domainObject in $domains)
			{
				$script:domainData["$($domainObject.SID)"] = $domainObject
				$script:domainData[$domainObject.Fqdn] = $domainObject
				$script:domainData[$domainObject.DistinguishedName] = $domainObject
			}
			#endregion Pre-Seed information for all domains in forest
		}
	}
	process
	{
		if ($script:domainData[$Domain])
		{
			return $script:domainData[$Domain]
		}
		
		#region Collect information for unknown domain
		$domainObject = Get-ADDomain -Server $Domain
		$domainObjectProcessed = [PSCustomObject]@{
			DistinguishedName = $domainObject.DistinguishedName
			Name			  = $domainObject.Name
			SID			      = $domainObject.DomainSID
			Fqdn			  = $domainObject.DNSRoot
			ADObject		  = $domainObject
		}
		$script:domainData["$($domainObjectProcessed.SID)"] = $domainObjectProcessed
		$script:domainData[$domainObjectProcessed.Fqdn] = $domainObjectProcessed
		$script:domainData[$domainObjectProcessed.DistinguishedName] = $domainObjectProcessed
		$script:domainData[$Domain] = $domainObjectProcessed
		$script:domainData[$Domain]
		#endregion Collect information for unknown domain
	}
}