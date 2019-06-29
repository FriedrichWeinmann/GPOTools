function Export-GptLink
{
<#
	.SYNOPSIS
		Generates a full dump of all GPO links.
	
	.DESCRIPTION
		Generates a full dump of all GPO links.
		This command will enumerate all OUs and create an export file of them.
		This is used to restore links of exported GPOs when restoring them.
	
	.PARAMETER Path
		The path in which to export the data.
		Specify an existing folder.
	
	.PARAMETER Domain
		The domain to retrieve the data from.
	
	.EXAMPLE
		PS C:\> Export-GptLink -Path .
	
		Exports all GPO links into the current folder.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$gpoObjects = Get-GPO -All -Domain $Domain
	}
	process
	{
		Get-ADOrganizationalUnit -Server $Domain -LdapFilter '(gpLink=*)' -Properties gpLink, CanonicalName | ForEach-Object {
			$indexCount = 0
			$links = $_.gpLink -replace '\]\[', ']_[' -split '_'
			foreach ($link in $links)
			{
				$path, $state = $link -replace '\[LDAP://' -replace '\]$' -split ';'
				[PSCustomObject]@{
					Path    = $Path
					State   = $state # 0: Normal, 1: Disabled, 2: Enforced
					GpoName = ($gpoObjects | Where-Object Path -EQ $path).DisplayName
					Domain  = $Domain
					OUDN    = $_.DistinguishedName
					OUName  = $_.Name
					OUCanonical = $_.CanonicalName
					Index   = $indexCount++
					TotalCount = $links.Count
				}
			}
		} | Export-Csv -Path (Join-Path -Path $Path -ChildPath "gp_Links_$($Domain).csv") -Encoding UTF8 -NoTypeInformation
	}
}
