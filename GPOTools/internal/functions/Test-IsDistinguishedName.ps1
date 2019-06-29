function Test-IsDistinguishedName
{
<#
	.SYNOPSIS
		Lightweight test to check whether a string is a distinguished name.
	
	.DESCRIPTION
		Lightweight test to check whether a string is a distinguished name.
		This check is done by checking, whether the string contains a "DC=" sequence.
	
	.PARAMETER Name
		The name to check.
	
	.EXAMPLE
		PS C:\> Test-IsDistinguishedName -Name $name
	
		returns whether $name is a distinguished name.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)
	
	process
	{
		$Name -match 'DC='
	}
}