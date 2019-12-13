function Import-GptDomainData
{
<#
	.SYNOPSIS
		Imports domain information of the source domain.
	
	.DESCRIPTION
		Imports domain information of the source domain.
		Also responsible for mapping domains from the source forest to the destination forest.
	
	.PARAMETER Path
		The path to the file or the folder it resides in.

	.PARAMETER Domain
		The domain into which to import.
		Used for automatically calculating domain mappings.
	
	.EXAMPLE
		PS C:\> Import-GptDomainData -Path '.'
	
		Import the domain information file from the current folder.
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
		$pathItem = Get-Item -Path $Path
		if ($pathItem.Extension -eq '.clixml') { $resolvedPath = $pathItem.FullName }
		else { $resolvedPath = (Get-ChildItem -Path $pathItem.FullName -Filter 'backup.clixml' | Select-Object -First 1).FullName }
		if (-not $resolvedPath) { throw "Could not find a domain data file in $($pathItem.FullName)" }
	}
	process
	{
		$domainImport = Import-Clixml $resolvedPath
		$script:sourceDomainData = $domainImport.SourceDomain

		$forestObject = Get-ADForest -Server $Domain
		$targetDomain = Get-ADDomain -Server $Domain
		$domains = $forestObject.Domains | Foreach-Object { Get-ADDomain -Server $_ -Identity $_ } | ForEach-Object {
			[PSCustomObject]@{
				DistinguishedName = $_.DistinguishedName
				Name			  = $_.Name
				SID			      = $_.DomainSID
				Fqdn			  = $_.DNSRoot
				ADObject		  = $_
				IsTarget          = $_.DomainSID -eq $targetDomain.DomainSID
				IsRootDomain      = $_.DNSRoot -eq $forestObject.RootDomain
			}
		}

		foreach ($domain in $domains) {
			foreach ($sourceDomainEntry in $domainImport.ForestDomains) {
				if ($sourceDomainEntry.Name -eq $domain.Name) {
					Register-GptDomainMapping -SourceName $sourceDomainEntry.Name -SourceFQDN $sourceDomainEntry.Fqdn -SourceSID $sourceDomainEntry.SID -Destination $domain.ADObject
				}
			}
		}
		foreach ($domain in $domains) {
			foreach ($sourceDomainEntry in $domainImport.ForestDomains) {
				if ($sourceDomainEntry.Fqdn -eq $domain.Fqdn) {
					Register-GptDomainMapping -SourceName $sourceDomainEntry.Name -SourceFQDN $sourceDomainEntry.Fqdn -SourceSID $sourceDomainEntry.SID -Destination $domain.ADObject
				}
			}
		}
		foreach ($domain in $domains) {
			foreach ($sourceDomainEntry in $domainImport.ForestDomains) {
				if ($sourceDomainEntry.SID -eq $domain.SID) {
					Register-GptDomainMapping -SourceName $sourceDomainEntry.Name -SourceFQDN $sourceDomainEntry.Fqdn -SourceSID $sourceDomainEntry.SID -Destination $domain.ADObject
				}
			}
		}
		$sourceDomain = $domainImport.ForestDomains | Where-Object IsTarget
		$sourceForestRootDomain = $domainImport.ForestDomains | Where-Object IsRootDomain
		foreach ($domain in $domains) {
			if ($domain.IsRootDomain) {
				Register-GptDomainMapping -SourceName $sourceForestRootDomain.Name -SourceFQDN $sourceForestRootDomain.Fqdn -SourceSID $sourceForestRootDomain.SID -Destination $domain.ADObject
			}
			if ($domain.IsTarget) {
				Register-GptDomainMapping -SourceName $sourceDomain.Name -SourceFQDN $sourceDomain.Fqdn -SourceSID $sourceDomain.SID -Destination $domain.ADObject
			}
		}
	}
}