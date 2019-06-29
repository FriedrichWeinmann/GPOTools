function ConvertFrom-ImportedIdentity
{
	[CmdletBinding()]
	param (
		$Permission,
		
		$DomainObject
	)
	
	process
	{
		switch ($Permission.PrincipalType)
		{
			'Local BuiltIn' { return [System.Security.Principal.SecurityIdentifier]$Permission.SID }
			'foreignSecurityPrincipal' { return [System.Security.Principal.SecurityIdentifier]$Permission.SID }
			'group'
			{
				if ($Permission.IsBuiltIn -like 'true')
				{
					return [System.Security.Principal.SecurityIdentifier]('{0}-{1}' -f $DomainObject.DomainSID, $Permission.RID)
				}
				else
				{
					$identity = $script:identityMapping | Where-Object SID -EQ $Permission.SID
					if (-not $identity) { throw "Cannot resolve $($Permission.IdentityReference) ($($Permission.SID))" }
					return [System.Security.Principal.NTAccount]('{0}\{1}' -f $DomainObject.NetBIOSName, $identity.Target)
				}
			}
		}
	}
}