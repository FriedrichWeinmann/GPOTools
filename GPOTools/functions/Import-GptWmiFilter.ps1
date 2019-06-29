function Import-GptWmiFilter
{
<#
	.SYNOPSIS
		Imports WMI filters.
	
	.DESCRIPTION
		Imports WMI filters stored to file using Export-GptWmiFilter.
		Note: This should be performed before using Import-GptPolicy.
		
	.PARAMETER Path
		The path from which to import the WmiFilters
	
	.PARAMETER Domain
		The domain into which to import the WmiFilters
	
	.EXAMPLE
		PS C:\> Import-GptWmiFilter -Path '.'
	
		Import WMI Filters from the current path.
#>
	[CmdletBinding()]
	param (
		[ValidateScript({ Test-Path -Path $_ })]
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$pathItem = Get-Item -Path $Path
		if ($pathItem.Extension -eq '.csv') { $resolvedPath = $pathItem.FullName }
		else { $resolvedPath = (Get-ChildItem -Path $pathItem.FullName -Filter 'gp_wmifilters_*.csv' | Select-Object -First 1).FullName }
		if (-not $resolvedPath) { throw "Could not find WMI Filters file in $($pathItem.FullName)" }
		
		$allWmiFilterEntries = Import-Csv -Path $resolvedPath
		$namingContext = (Get-ADRootDSE -Server $Domain).DefaultNamingContext
		$pdcEmulator = (Get-ADDomain -Server $Domain).PDCEmulator
	}
	process
	{
		foreach ($wmiFilter in $allWmiFilterEntries)
		{
			#region Update Existing
			if ($adObject = Get-ADObject -Server $pdcEmulator -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$($wmiFilter.Name)))")
			{
				$adObject | Set-ADObject -Server $pdcEmulator -Replace @{
					'msWMI-Author' = $wmiFilter.Author
					'msWMI-Parm1'  = $wmiFilter.Description
					'msWMI-Parm2'  = $wmiFilter.Filter
				}
			}
			#endregion Update Existing
			
			#region Create New
			else
			{
				$wmiGuid = "{$([System.Guid]::NewGuid())}"
				$creationDate = (Get-Date).ToUniversalTime().ToString("yyyyMMddhhmmss.ffffff-000")
				
				$attributes = @{
					"showInAdvancedViewOnly" = "TRUE"
					"msWMI-Name"			 = $wmiFilter.Name
					"msWMI-Parm1"		     = $wmiFilter.Description
					"msWMI-Parm2"		     = $wmiFilter.Filter
					"msWMI-Author"		     = $wmiFilter.Author
					"msWMI-ID"			     = $wmiGuid
					"instanceType"		     = 4
					"distinguishedname"	     = "CN=$wmiGuid,CN=SOM,CN=WMIPolicy,CN=System,$namingContext"
					"msWMI-ChangeDate"	     = $creationDate
					"msWMI-CreationDate"	 = $creationDate
				}
				
				$paramNewADObject = @{
					OtherAttributes = $attributes
					Name		    = $wmiGuid
					Type		    = "msWMI-Som"
					Path		    = "CN=SOM,CN=WMIPolicy,CN=System,$namingContext"
					Server		    = $pdcEmulator
				}
				
				$null = New-ADObject @paramNewADObject
			}
			#endregion Create New
		}
	}
}
