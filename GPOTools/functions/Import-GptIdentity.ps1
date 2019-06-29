function Import-GptIdentity
{
<#
	.SYNOPSIS
		Imports identity data exported from the source domain.
	
	.DESCRIPTION
		Imports identity data exported from the source domain.
		This data is used for mapping source identities to destination identities.
	
	.PARAMETER Path
		The path where to pick up the file.
	
	.PARAMETER Name
		Filter identities by name.
	
	.PARAMETER Domain
		The destination domain that later GPOs will be imported to.
	
	.PARAMETER Mapping
		A mapping hashtable allowing you to map identities that have unequal names.
	
	.EXAMPLE
		PS C:\> Import-GptIdentity -Path '.'
	
		Import the identity export file from the current folder.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]
		$Path,
		
		[string[]]
		$Name = '*',
		
		[string]
		$Domain = $env:USERDNSDOMAIN,
		
		[System.Collections.IDictionary]
		$Mapping = @{ }
	)
	
	begin
	{
		$pathItem = Get-Item -Path $Path
		if ($pathItem.Extension -eq '.csv') { $resolvedPath = $pathItem.FullName }
		else { $resolvedPath = (Get-ChildItem -Path $pathItem.FullName -Filter 'gp_Identities*.csv' | Select-Object -First 1).FullName }
		if (-not $resolvedPath) { throw "Could not find identities file in $($pathItem.FullName)" }
		
		$domainSID = (Get-ADDomain -Server $Domain).DomainSID.Value
		
		# Declare Module scope index of identities and what they map to
		$script:identityMapping = New-Object 'System.Collections.Generic.List[Object]'
		
		# Helpful Select Hashtables
		$select_TargetMapping = @{
			Name	   = 'Target'
			Expression = { $Mapping[$importEntry.Name] }
		}
		$select_TargetName = @{
			Name	   = 'Target'
			Expression = { $targetName }
		}
	}
	process
	{
		$importData = Import-Csv -Path $resolvedPath
		foreach ($importEntry in $importData)
		{
			# Skip entries filtered out
			if (-not (Test-Overlap -ReferenceObject $importEntry.Name -DifferenceObject $Name -Operator Like))
			{
				continue
			}
			
			#region Case: Mapped Entry
			if ($Mapping[$importEntry.Name])
			{
				$script:identityMapping.Add(($importEntry | Select-Object *, $select_TargetMapping))
			}
			#endregion Case: Mapped Entry
			
			#region Case: Discovery
			else
			{
				#region Case: Native BuiltIn Principal
				if (($importEntry.IsBuiltIn -eq 'True') -and ($importEntry.SID -like "*-32-*"))
				{
					try { $targetName = ([System.Security.Principal.SecurityIdentifier]$importEntry.SID).Translate([System.Security.Principal.NTAccount]).Value }
					catch
					{
						Write-Warning "Failed to translate identity: $($importEntry.Name) ($($importEntry.SID))"
						continue
					}
					$script:identityMapping.Add(($importEntry | Select-Object *, $select_TargetName))
				}
				#endregion Case: Native BuiltIn Principal
				
				#region Case: Domain Specific BuiltIn Principal
				elseif ($importEntry.IsBuiltIn -eq 'True')
				{
					$targetSID = '{0}-{1}' -f $domainSID, $importEntry.RID
					$adObject = Get-ADObject -Server $Domain -LDAPFilter "(&(objectClass=$($importEntry.Type))(objectSID=$($targetSID)))"
					if (-not $adObject)
					{
						Write-Warning "Failed to resolve AD identity: $($importEntry.Name) ($($targetSID))"
						continue
					}
					$targetName = $adObject.Name
					$script:identityMapping.Add(($importEntry | Select-Object *, $select_TargetName))
				}
				#endregion Case: Domain Specific BuiltIn Principal
				
				#region Case: Custom Principal
				else
				{
					$adObject = Get-ADObject -Server $Domain -LDAPFilter "(&(objectClass=$($importEntry.Type))(name=$($importEntry.Name)))"
					if (-not $adObject)
					{
						Write-Warning "Failed to resolve AD identity: $($importEntry.Name)"
						continue
					}
					$targetName = $adObject.Name
					$script:identityMapping.Add(($importEntry | Select-Object *, $select_TargetName))
				}
				#endregion Case: Custom Principal
			}
			#endregion Case: Discovery
		}
	}
}