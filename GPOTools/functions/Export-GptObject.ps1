function Export-GptObject
{
<#
	.SYNOPSIS
		Creates a backup of all specified GPOs.
	
	.DESCRIPTION
		Creates a backup of all specified GPOs.
	
	.PARAMETER Path
		The path in which to generate the Backup.
	
	.PARAMETER Name
		The name to filter GPOs by.
		By default, ALL GPOs are exported.
	
	.PARAMETER GpoObject
		Select the GPOs to export by specifying the explicit GPO object to export.
	
	.PARAMETER Domain
		The domain from which to export the GPOs
	
	.EXAMPLE
		PS C:\> Export-GptObject -Path .
	
		Generate a GPO export of all GPOs in the current folder.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string[]]
		$Name = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	process
	{
		$gpoObjects = $GpoObject | Where-Object {
			Test-Overlap -ReferenceObject $_.DisplayName -DifferenceObject $Name -Operator Like
		}
		if (-not $GpoObject)
		{
			$gpoObjects = Get-GPO -All -Domain $Domain | Where-Object {
				Test-Overlap -ReferenceObject $_.DisplayName -DifferenceObject $Name -Operator Like
			}
		}
		$null = $gpoObjects | Backup-GPO -Path (Resolve-Path $Path).ProviderPath
		$gpoObjects | Select-Object DisplayName, ID, Owner, CreationTime, ModificationTime, WmiFilter | Export-Csv -Path (Join-Path -Path $Path -ChildPath "gp_object_$($Domain).csv") -Encoding UTF8 -NoTypeInformation -Append
	}
}
