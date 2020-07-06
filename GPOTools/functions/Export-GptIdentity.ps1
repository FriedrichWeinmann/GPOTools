﻿function Export-GptIdentity
{
<#
	.SYNOPSIS
		Exports identity data used for Group Policy imports.
	
	.DESCRIPTION
		Generates an export dump of identity information.
		This is later used during import of group policy objects:
		- To map between identities for permissions and policy content.
		- To translate localized builtin account names.
		- To correctly target renamed builtin acconts.
	
	.PARAMETER Path
		The path where the exprot should be stored in.
		Specify an existing folder.
	
	.PARAMETER Name
		Names of groups to include in addition to the builtin accounts.
	
	.PARAMETER Domain
		The domain to generate the dump from.

	.PARAMETER GpoName
		The name filter pattern of the GPOs to parse for relevant identities export.
		
	.PARAMETER GpoObject
		Specific GPO object to parse for relevant identities to export.
	
	.EXAMPLE
		PS C:\> Export-GptIdentity -Path '.'
	
		Export the builtin accounts into the current folder.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string[]]
		$Name,

		[string[]]
		$GpoName = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$pdcEmulator = (Get-ADDomain -Server $Domain).PDCEmulator
		$rootDomain = Get-ADDomain (Get-ADForest -Server $Domain).RootDomain
		
		[System.Collections.ArrayList]$identities = @()
		
		#region Process Builtin Accounts
		$builtInSID = 'S-1-5-32-544', 'S-1-5-32-545', 'S-1-5-32-546', 'S-1-5-32-548', 'S-1-5-32-549', 'S-1-5-32-550', 'S-1-5-32-551', 'S-1-5-32-552', 'S-1-5-32-554', 'S-1-5-32-555', 'S-1-5-32-556', 'S-1-5-32-557', 'S-1-5-32-558', 'S-1-5-32-559', 'S-1-5-32-560', 'S-1-5-32-561', 'S-1-5-32-562', 'S-1-5-32-568', 'S-1-5-32-569', 'S-1-5-32-573', 'S-1-5-32-574', 'S-1-5-32-575', 'S-1-5-32-576', 'S-1-5-32-577', 'S-1-5-32-578', 'S-1-5-32-579', 'S-1-5-32-580', 'S-1-5-32-582'
		$builtInRID = '500', '501', '502', '512', '513', '514', '515', '516', '517','520', '521', '522', '525', '526', '553', '571', '572'
		$builtInForestRID = @(
			'498' # Enterprise Read-only Domain Controllers
			'518' # Schema Admins
			'519' # Enterprise Admins
			'527' # Enterprise Key Admins
		)
		$domainSID = (Get-ADDomain -Server $pdcEmulator).DomainSID.Value
		$rootDomainSID = $rootDomain.DomainSID.Value
		$identities.AddRange(($builtInSID | Resolve-ADPrincipal -Domain $Domain))
		$identities.AddRange(($builtInRID | Resolve-ADPrincipal -Domain $Domain -Name { '{0}-{1}' -f $domainSID, $_ }))
		$identities.AddRange(($builtInForestRID | Resolve-ADPrincipal -Domain $rootDomain.DNSRoot -Name { '{0}-{1}' -f $rootDomainSID, $_ }))
		#endregion Process Builtin Accounts

		#region Process Additional Requested Accounts
		foreach ($adEntity in $Name)
		{
			#region Handle Wildcard Filters
			if ($adEntity.Contains("*"))
			{
				$identities.AddRange((Get-ADGroup -Server $pdcEmulator -LDAPFilter "(name=$adEntity)" | Resolve-ADPrincipal -Domain $Domain))
				continue
			}
			#endregion Handle Wildcard Filters
			try
			{
				$principal = Resolve-ADPrincipal -Name $adEntity -Domain $Domain -ErrorAction Stop
				$null = $identities.Add($principal)
			}
			catch { Write-Error -Message "Failed to resolve Identity: $adEntity | $_" -Exception $_.Exception }
		}
		#endregion Process Additional Requested Accounts
	}
	process
	{
		#region Process GPO-Required Accounts
		foreach ($gpoItem in $GpoObject) {
			foreach ($principal in (Get-GptPrincipal -Name $GpoName -GpoObject $GpoObject -Domain $Domain)) {
				$null = $identities.Add($principal)
			}
		}
		#endregion Process GPO-Required Accounts
	}
	end
	{
		$identities | Group-Object SID | ForEach-Object {
			$_.Group | Select-Object -First 1
		} | Export-Csv -Path (Join-Path -Path $Path -ChildPath "gp_Identities_$($Domain).csv") -Encoding UTF8 -NoTypeInformation
	}
}