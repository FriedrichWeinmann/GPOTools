function Import-GptDomainData
{
<#
	.SYNOPSIS
		Imports domain information of the source domain.
	
	.DESCRIPTION
		Imports domain information of the source domain.
	
	.PARAMETER Path
		The path to the file or the folder it resides in.
	
	.EXAMPLE
		PS C:\> Import-GptDomainData -Path '.'
	
		Import the domain information file from the current folder.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
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
		$script:sourceDomainData = Import-Clixml $resolvedPath
	}
}