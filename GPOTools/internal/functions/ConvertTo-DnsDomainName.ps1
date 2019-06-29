function ConvertTo-DnsDomainName
{
<#
	.SYNOPSIS
		Converts a distinguished name in the DNS domain name.
	
	.DESCRIPTION
		This extracts the domain portion of a distinguished name and processes it as dns name.
	
	.PARAMETER DistinguishedName
		The name to parse / convert.
	
	.EXAMPLE
		PS C:\> Get-ADDomain | ConvertTo-DnsDomainName
	
		Returns the dns name of the current domain.
#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[Alias('Name')]
		[string[]]
		$DistinguishedName
	)
	
	process
	{
		foreach ($distName in $DistinguishedName)
		{
			($distName -split "," | Where-Object { $_ -like "DC=*" } | ForEach-Object {
				$_ -replace '^DC='
			}) -join "."
		}
	}
}