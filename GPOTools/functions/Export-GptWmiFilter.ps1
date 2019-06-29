function Export-GptWmiFilter
{
<#
	.SYNOPSIS
		Export WMI Filters.
	
	.DESCRIPTION
		Export WMI Filters.
		WMI Filters to export are picked up by the GPÜO they are assigned to.
		Unassigned filters are ignored.
	
	.PARAMETER Path
		The path where to create the export.
		Must be an existing folder.
	
	.PARAMETER Name
		Filter GPOs to process by name.
	
	.PARAMETER GpoObject
		Specify GPOs to process by object.
	
	.PARAMETER Domain
		The domain to export from.
	
	.EXAMPLE
		PS C:\> Export-GptWmiFilter -Path '.'
	
		Export all WMI Filters of all GPOs into the current folder.
#>
	[CmdletBinding()]
	param (
		[ValidateScript({ Test-Path -Path $_ })]
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string]
		$Name = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$wmiPath = "CN=SOM,CN=WMIPolicy,$((Get-ADDomain -Server $Domain).SystemsContainer)"
		$allFilterHash = @{ }
		$foundFilterHash = @{ }
		
		Get-ADObject -Server $Domain -SearchBase $wmiPath -Filter { objectClass -eq 'msWMI-Som' } -Properties msWMI-Author, msWMI-Name, msWMI-Parm1, msWMI-Parm2 | ForEach-Object {
			$allFilterHash[$_.'msWMI-Name'] = [pscustomobject]@{
				Author = $_.'msWMI-Author'
				Name   = $_.'msWMI-Name'
				Description = $_.'msWMI-Parm1'
				Filter = $_.'msWMI-Parm2'
			}
		}
	}
	process
	{
		$gpoObjects = $GpoObject
		if (-not $GpoObject)
		{
			$gpoObjects = Get-GPO -All -Domain $Domain | Where-Object DisplayName -Like $Name
		}
		foreach ($filterName in $gpoObjects.WmiFilter.Name)
		{
			$foundFilterHash[$filterName] = $allFilterHash[$filterName]
		}
	}
	end
	{
		$foundFilterHash.Values | Where-Object { $_ } | Export-Csv -Path (Join-Path -Path $Path -ChildPath "gp_wmifilters_$($Domain).csv") -Encoding UTF8 -NoTypeInformation
	}
}
