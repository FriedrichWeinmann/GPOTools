function Resolve-ADPrincipal
{
<#
	.SYNOPSIS
		Resolves an AD Principal into a common format.
	
	.DESCRIPTION
		Resolves an AD Principal into a common format.
		Optimized for use with cross-domain migration procedures.
	
		Caches successful results.
		Returns empty values on unresolved users.
	
	.PARAMETER Name
		Name of the principal to resolve.
	
	.PARAMETER Domain
		Domain to resolve it for.
		Read access is required.
	
	.EXAMPLE
		PS C:\> Resolve-ADPrincipal -Name 'contoso\max' -Domain 'contoso.com'
	
		Resolves the user max from contoso.com
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string[]]
		$Name,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$Domain
	)
	
	begin
	{
		if (-not $script:principals) { $script:principals = @{ } }
		
		$principalsToIgnore = @(
			# .NET Account sids, that are shared across all domains and need no translation
			'S-1-5-82-3876422241-1344743610-1729199087-774402673-2621913236'
			'S-1-5-82-271721585-897601226-2024613209-625570482-296978595'
			
			# Everyone, as it is 100% generic and has no domain-prefix
			'S-1-1-0'
			
			# NT Authority SIDs, as SID-to-SID need no translation, localization can be an issue
			'S-1-5-18'
			'S-1-5-19'
			'S-1-5-20'
		)
		
		$defaultDomainData = Get-DomainData -Domain $Domain
		$defaultDomainFQDN = $defaultDomainData.Fqdn
		$defaultDomainName = $defaultDomainData.Name
	}
	process
	{
		foreach ($identity in $Name)
		{
			if ($identity -in $principalsToIgnore) { continue }
			
			#region Resolve Principal Domain
			$domainFQDN = $defaultDomainFQDN
			$domainName = $defaultDomainName
			if ($identity -like "*@*")
			{
				$domainObject = Get-DomainData -Domain $identity.Split("@")[1]
				if ($domainObject)
				{
					$domainFQDN = $domainObject.Fqdn
					$domainName = $domainObject.Name
				}
			}
			elseif ($identity -as [System.Security.Principal.SecurityIdentifier])
			{
				if (([System.Security.Principal.SecurityIdentifier]$identity).AccountDomainSid)
				{
					$domainObject = Get-DomainData -Domain ([System.Security.Principal.SecurityIdentifier]$identity).AccountDomainSid
					if ($domainObject)
					{
						$domainFQDN = $domainObject.Fqdn
						$domainName = $domainObject.Name
					}
				}
			}
			#endregion Resolve Principal Domain
			
			if (-not $script:principals[$domainFQDN]) { $script:principals[$domainFQDN] = @{ } }
			
			# Return form Cache if available
			if ($script:principals[$domainFQDN][$identity])
			{
				return $script:principals[$domainFQDN][$identity]
			}
			
			#region Resolve User in AD
			if ($identity -as [System.Security.Principal.SecurityIdentifier])
			{
				$adObject = Get-ADObject -Server $domainFQDN -LDAPFilter "(objectSID=$identity)" -Properties ObjectSID
			}
			elseif (Test-IsDistinguishedName -Name $identity)
			{
				$adObject = Get-ADObject -Server ($identity | ConvertTo-DnsDomainName) -Identity $identity -Properties ObjectSID
			}
			elseif ($identity -like "*\*")
			{
				try { $sidName = ([System.Security.Principal.NTAccount]$identity).Translate([System.Security.Principal.SecurityIdentifier]) }
				catch
				{
					Write-Warning "Failed to translate identity: $identity"
					continue
				}
				$adObject = Get-ADObject -Server $domainFQDN -LDAPFilter "(objectSID=$sidName)" -Properties ObjectSID
				if (-not $adObject)
				{
					$script:principals[$domainFQDN][$identity] = [pscustomobject]@{
						DistinguishedName = $null
						Name			  = $identity
						SID			      = $sidName.Value
						RID			      = $sidName.Value.ToString().Split("-")[-1]
						Type			  = 'Local BuiltIn'
						IsBuiltin		  = $true
						DomainName	      = $domainName
						DomainFqdn	      = $domainFQDN
					}
					$script:principals[$domainFQDN][$identity]
					continue
				}
			}
			else
			{
				try
				{
					$sidName = ([System.Security.Principal.NTAccount]$identity).Translate([System.Security.Principal.SecurityIdentifier])
					if ($sidName.Value -like 'S-1-3-*')
					{
						$script:principals[$domainFQDN][$identity] = [pscustomobject]@{
							DistinguishedName = $null
							Name			  = $identity
							SID			      = $sidName.Value
							RID			      = $sidName.Value.ToString().Split("-")[-1]
							Type			  = 'Local BuiltIn'
							IsBuiltin		  = $true
							DomainName	      = $domainName
							DomainFqdn	      = $domainFQDN
						}
						$script:principals[$domainFQDN][$identity]
						continue
					}
					$adObject = Get-ADObject -Server $domainFQDN -LDAPFilter "(objectSID=$sidName)" -Properties ObjectSID
				}
				catch
				{
					$adObject = Get-ADObject -Server $domainFQDN -LDAPFilter "(Name=$identity)" -Properties ObjectSID
				}
			}
			if (-not $adObject -or -not $adObject.ObjectSID)
			{
				Write-Warning "Failed to resolve principal: $identity"
				continue
			}
			#endregion Resolve User in AD
			
			$script:principals[$domainFQDN][$identity] = [pscustomobject]@{
				DistinguishedName = $adObject.DistinguishedName
				Name			  = $adObject.Name
				SID			      = $adObject.ObjectSID.Value
				RID			      = $adObject.ObjectSID.Value.ToString().Split("-")[-1]
				Type			  = $adObject.ObjectClass
				IsBuiltin		  = ((($adObject.ObjectSID.Value.Split("-")[-1] -as [int]) -lt 1000) -or ($adObject.ObjectSID.Value -like 'S-1-5-32-*'))
				DomainName	      = $domainName
				DomainFqdn	      = $domainFQDN
			}
			$script:principals[$domainFQDN][$identity]
		}
	}
}