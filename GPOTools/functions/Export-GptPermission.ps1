function Export-GptPermission
{
<#
	.SYNOPSIS
		Export the permissions assigned on GPOs
	
	.DESCRIPTION
		Export the permissions assigned on GPOs.
		
		Note: This command is currently fairly slow so give it some time.
	
	.PARAMETER Path
		The path where to create the export.
		Must be an existing folder.
	
	.PARAMETER Name
		Filter GPOs to process by name.
	
	.PARAMETER GpoObject
		Specify GPOs to process by object.
	
	.PARAMETER IncludeInherited
		Include inherited permissions in the export.
		By default, only explicit permissiosn are exported.
		Note: By default, all GPOs in a windows domain only have explicit permissions set.
		This will have little impact in most scenarios.
	
	.PARAMETER Domain
		The domain to export from.
	
	.EXAMPLE
		PS C:\> Export-GptPermission -Path '.'
	
		Exports permissions of all GPOs into the current folder.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]
		$Path,
		
		[string]
		$Name = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[switch]
		$IncludeInherited,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		Write-Verbose "Preparing Filters"
		$select_Name = @{ name = 'GpoName'; expression = { $gpoItem.DisplayName } }
		$select_Path = @{ name = 'GpoPath'; expression = { $gpoItem.Path } }
		$select_SID = @{ name = 'SID'; expression = { (Resolve-ADPrincipal -Name $_.IdentityReference -Domain $Domain).SID } }
		$select_RID = @{ name = 'RID'; expression = { (Resolve-ADPrincipal -Name $_.IdentityReference -Domain $Domain).RID } }
		$select_IsBuiltin = @{ name = 'IsBuiltIn'; expression = { (Resolve-ADPrincipal -Name $_.IdentityReference -Domain $Domain).IsBuiltIn } }
		$select_PrincipalType = @{ name = 'PrincipalType'; expression = { (Resolve-ADPrincipal -Name $_.IdentityReference -Domain $Domain).Type } }
		
		[System.Collections.ArrayList]$accessList = @()
	}
	process
	{
		Write-Verbose "Resolving Policies to process"
		$gpoObjects = $GpoObject
		if (-not $GpoObject)
		{
			$gpoObjects = Get-GPO -All -Domain $Domain | Where-Object DisplayName -Like $Name
		}
		Write-Verbose "Found $($gpoObjects.Count) Policies"
		$accessData = foreach ($gpoItem in $gpoObjects)
		{
			Write-Verbose "Processing policy: $($gpoItem.DisplayName)"
			$adObject = Get-ADObject -Identity $gpoItem.Path -Server $gpoItem.DomainName -Properties ntSecurityDescriptor
			$adObject.ntSecurityDescriptor.Access | Where-Object {
				$IncludeInherited -or -not $_.IsInherited
			} | Select-Object $select_Name, $select_Path, '*', $select_SID, $select_RID, $select_IsBuiltin, $select_PrincipalType
		}
		Write-Verbose "Found $($accessData.Count) permission entries."
		$null = $accessList.AddRange($accessData)
	}
	end
	{
		Write-Verbose "Exorting to file"
		$accessList | Export-Csv -Path (Join-Path -Path $Path -ChildPath "gp_permissions_$($Domain).csv") -Encoding UTF8 -NoTypeInformation
	}
}
