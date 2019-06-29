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
		if (-not $script:principals[$Domain]) { $script:principals[$Domain] = @{ } }
		
		$domainFQDN = (Get-ADDomain -Server $Domain).DNSRoot
		$domainName = (Get-ADDomain -Server $Domain).Name
	}
	process
	{
		foreach ($identity in $Name)
		{
			# Return form Cache if available
			if ($script:principals[$Domain][$identity])
			{
				return $script:principals[$Domain][$identity]
			}
			
			#region Resolve User in AD
			if ($identity -as [System.Security.Principal.SecurityIdentifier])
			{
				$adObject = Get-ADObject -Server $Domain -LDAPFilter "(objectSID=$identity)" -Properties ObjectSID
			}
			elseif (Test-IsDistinguishedName -Name $identity)
			{
				$adObject = Get-ADObject -Server ($identity | ConvertTo-DnsDomainName) -Identity $identity -Properties ObjectSID
			}
			elseif ($identity -like "*\*")
			{
				try { $sidName = ([System.Security.Principal.NTAccount]$identity).Translate([System.Security.Principal.SecurityIdentifier]) }
				catch { continue }
				$adObject = Get-ADObject -Server $Domain -LDAPFilter "(objectSID=$sidName)" -Properties ObjectSID
				if (-not $adObject)
				{
					$script:principals[$Domain][$identity] = [pscustomobject]@{
						DistinguishedName = $null
						Name			  = $identity
						SID			      = $sidName.Value
						RID			      = $sidName.Value.ToString().Split("-")[-1]
						Type			  = 'Local BuiltIn'
						IsBuiltin		  = $true
						DomainName	      = $domainName
						DomainFqdn	      = $domainFQDN
					}
					$script:principals[$Domain][$identity]
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
						$script:principals[$Domain][$identity] = [pscustomobject]@{
							DistinguishedName = $null
							Name			  = $identity
							SID			      = $sidName.Value
							RID			      = $sidName.Value.ToString().Split("-")[-1]
							Type			  = 'Local BuiltIn'
							IsBuiltin		  = $true
							DomainName	      = $domainName
							DomainFqdn	      = $domainFQDN
						}
						$script:principals[$Domain][$identity]
						continue
					}
					$adObject = Get-ADObject -Server $Domain -LDAPFilter "(objectSID=$sidName)" -Properties ObjectSID
				}
				catch
				{
					$adObject = Get-ADObject -Server $Domain -LDAPFilter "(Name=$identity)" -Properties ObjectSID
				}
			}
			if (-not $adObject -or -not $adObject.ObjectSID) { continue }
			#endregion Resolve User in AD
			
			$script:principals[$Domain][$identity] = [pscustomobject]@{
				DistinguishedName = $adObject.DistinguishedName
				Name			  = $adObject.Name
				SID			      = $adObject.ObjectSID.Value
				RID			      = $adObject.ObjectSID.Value.ToString().Split("-")[-1]
				Type			  = $adObject.ObjectClass
				IsBuiltin		  = ((($adObject.ObjectSID.Value.Split("-")[-1] -as [int]) -lt 1000) -or ($adObject.ObjectSID.Value -like 'S-1-5-32-*'))
				DomainName	      = $domainName
				DomainFqdn	      = $domainFQDN
			}
			$script:principals[$Domain][$identity]
		}
	}
}