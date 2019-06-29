function ConvertFrom-ImportedIdentity
{
<#
	.SYNOPSIS
		Converts an imported identity into a security principal.
	
	.DESCRIPTION
		Converts an imported identity into a security principal.
		This is used for granting permissions.
	
	.PARAMETER Permission
		The permission object containing the source principal.
	
	.PARAMETER DomainObject
		An object representing the destination domain (as returned by Get-ADDomain)
	
	.EXAMPLE
		PS C:\> ConvertFrom-ImportedIdentity -Permission $permission -DomainObject $domainObject
	
		Resolves the source identity into a destination security principal.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
	[OutputType([System.Security.Principal.IdentityReference])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		$Permission,
		
		[Parameter(Mandatory = $true)]
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