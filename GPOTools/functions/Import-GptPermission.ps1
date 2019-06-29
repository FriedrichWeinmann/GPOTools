function Import-GptPermission
{
<#
	.SYNOPSIS
		Import permissions to GPOs.
	
	.DESCRIPTION
		Import permissions to GPOs.
		This tries to restore the same permissions that existed on the GPOs before the export.
		Notes:
		- It is highly recommended to perform this before executing Import-GptLink.
		- Executing this requires the identities to have been imported (Import-GptIdentity)
	
	.PARAMETER Path
		The path where the permission export file is stored.
	
	.PARAMETER Name
		Only restore permissions for GPOs with a matching name.
	
	.PARAMETER GpoObject
		Select the GPOs to restore permissions to by specifying their full object.
	
	.PARAMETER ExcludeInherited
		Do not import permissions that were inherited permissions on the source GPO
	
	.PARAMETER Domain
		The domain to restore the GPO permissions to.
	
	.EXAMPLE
		PS C:\> Import-GptPermission -Path '.'
	
		Import GPO permissions from the current path.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]
		$Path,
		
		[string[]]
		$Name = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$GpoObject,
		
		[switch]
		$ExcludeInherited,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		#region Utility Functions
		function Update-GpoPermission
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				$ADObject,
				
				$Permission,
				
				$GpoObject,
				
				$DomainObject
			)
			
			try
			{
				$accessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList @(
					(ConvertFrom-ImportedIdentity -Permission $Permission -DomainObject $DomainObject),
					$Permission.ActiveDirectoryRights,
					$Permission.AccessControlType,
					$Permission.ObjectType,
					$Permission.InheritanceType,
					$Permission.InheritedObjectType
				)
			}
			catch
			{
				New-ImportResult -Action 'Update Gpo Permission' -Step 'Resolving Identity' -Target $Permission.GpoName -Success $false -Data $Permission -ErrorData $_
				return
			}
			
			$matchingRule = $null
			$matchingRule = $ADObject.ntSecurityDescriptor.Access | Where-Object {
				$accessRule.IdentityReference -eq $_.IdentityReference -and
				$accessRule.ActiveDirectoryRights -eq $_.ActiveDirectoryRights -and
				$accessRule.AccessControlType -eq $_.AccessControlType -and
				$accessRule.ObjectType -eq $_.ObjectType -and
				$accessRule.InheritanceType -eq $_.InheritanceType -and
				$accessRule.InheritedObjectType -eq $_.InheritedObjectType
			}
			
			if ($matchingRule)
			{
				New-ImportResult -Action 'Update Gpo Permission' -Step 'Skipped, already exists' -Target $Permission.GpoName -Success $true -Data $Permission, $accessRule
				return
			}
			
			#region Set AD Permissions
			try
			{
				Write-Verbose "Updating ACL on GPO $($ADObject.DistinguishedName)"
				$acl = Get-Acl -Path "AD:\$($ADObject.DistinguishedName)" -ErrorAction Stop
				$acl.AddAccessRule($accessRule)
				$acl | Set-Acl -Path "AD:\$($ADObject.DistinguishedName)" -ErrorAction Stop
			}
			catch
			{
				New-ImportResult -Action 'Update Gpo Permission' -Step 'Apply AD Permission' -Target $Permission.GpoName -Success $false -Data $Permission, $accessRule -ErrorData $_
				continue
			}
			#endregion Set AD Permissions
			
			#region Set File Permissions
			if (-not (Test-Path $ADObject.gPCFileSysPath))
			{
				New-ImportResult -Action 'Update Gpo Permission' -Step 'Apply File Permission' -Target $Permission.GpoName -Success $false -Data $Permission, $accessRule -ErrorData "Path not found"
				continue
			}
			try
			{
				$rights = 'Read'
				if ($accessRule.ActiveDirectoryRights -eq 983295) { $rights = 'FullControl' }
				$fileRule = New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList @(
					$accessRule.IdentityReference
					$rights
					$accessRule.AccessControlType
				)
				
				
				$acl = Get-Acl -Path $ADObject.gPCFileSysPath -ErrorAction Stop
				$acl.AddAccessRule($fileRule)
				$acl | Set-Acl -Path $ADObject.gPCFileSysPath -ErrorAction Stop
			}
			catch
			{
				[pscustomobject]@{
					Action = 'Update Gpo Permission'
					Step   = 'Apply File Permission'
					Target = $Permission.GpoName
					Success = $false
					Data   = $Permission
					Data2  = $accessRule
					Error  = $_
				}
			}
			#endregion Set File Permissions
			
			New-ImportResult -Action 'Update Gpo Permission' -Step Success -Target $Permission.GpoName -Success $true -Data $Permission, $accessRule
		}
		#endregion Utility Functions
		
		$pathItem = Get-Item -Path $Path
		if ($pathItem.Extension -eq '.csv') { $resolvedPath = $pathItem.FullName }
		else { $resolvedPath = (Get-ChildItem -Path $pathItem.FullName -Filter 'gp_permissions_*.csv' | Select-Object -First 1).FullName }
		if (-not $resolvedPath) { throw "Could not find permissions file in $($pathItem.FullName)" }
		
		if (-not $script:identityMapping)
		{
			throw 'Could not find imported identities to match. Please run Import-GptIdentitiy first!'
		}
		
		$domainObject = Get-ADDomain -Server $Domain
		$allPermissionData = Import-Csv -Path $resolvedPath
	}
	process
	{
		$gpoObjects = $GpoObject
		if (-not $GpoObject)
		{
			$gpoObjects = Get-GPO -All -Domain $Domain
		}
		
		foreach ($gpoItem in $gpoObjects)
		{
			if (-not (Test-Overlap -ReferenceObject $gpoItem.DisplayName -DifferenceObject $Name -Operator Like))
			{
				continue
			}
			$adObject = Get-ADObject -Identity $gpoItem.Path -Server $gpoItem.DomainName -Properties ntSecurityDescriptor, gPCFileSysPath
			
			foreach ($permission in $allPermissionData)
			{
				# Skip items that do not apply
				if ($permission.GpoName -ne $gpoItem.DisplayName) { continue }
				if ($ExcludeInherited -and $permission.IsInherited -eq "True") { continue }
				
				Update-GpoPermission -ADObject $adObject -Permission $permission -GpoObject $gpoItem -DomainObject $domainObject
			}
		}
	}
}
