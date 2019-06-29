function Import-GptLink
{
<#
	.SYNOPSIS
		Imports GPO Links.
	
	.DESCRIPTION
		Imports GPO Links.
		Use this to restore the exported links in their original order (or as close to it as possible).
	
	.PARAMETER Path
		The path from which to pick up the import file.
	
	.PARAMETER Name
		Only restore links of matching GPOs
	
	.PARAMETER Domain
		The domain into which to import.
	
	.EXAMPLE
		PS C:\> Import-GptLink -Path '.'
	
		Import GPO Links based on the exported links stored in the current path.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[string[]]
		$Name = '*',
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		#region Utility Functions
		function Get-OU
		{
		<#
			.SYNOPSIS
				Retrieves an OU. Caches results.
			
			.DESCRIPTION
				Retrieves an OU. Caches results.
				Results are cached separately for each domain/server.
			
			.PARAMETER DistinguishedName
				The name of the OU to check.
			
			.PARAMETER Server
				The domain or server to check against.
			
			.EXAMPLE
				PS C:\> Get-OU -DistinguishedName $dn -Server $Domain
			
				Return the OU pointed at with $dn if it exists.
		#>
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[string]
				$DistinguishedName,
				
				[Parameter(Mandatory = $true)]
				[string]
				$Server
			)
			
			if (-not $script:targetOUs) { $script:targetOUs = @{ } }
			if (-not $script:targetOUs[$Server]) { $script:targetOUs[$Server] = @{ } }
			
			if ($script:targetOUs[$Server].ContainsKey($DistinguishedName))
			{
				return $script:targetOUs[$Server][$DistinguishedName]
			}
			
			try
			{
				$paramGetADOrganizationalUnit = @{
					Identity    = $DistinguishedName
					Server	    = $Server
					Properties  = 'gpLink'
					ErrorAction = 'Stop'
				}
				$script:targetOUs[$Server][$DistinguishedName] = Get-ADOrganizationalUnit @paramGetADOrganizationalUnit
			}
			catch { $script:targetOUs[$Server][$DistinguishedName] = $null }
			return $script:targetOUs[$Server][$DistinguishedName]
		}
		
		function Set-GPLinkSet
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				$LinkObject,
				
				$Domain,
				
				$AllGpos,
				
				$Server
			)
			
			foreach ($linkItem in $LinkObject)
			{
				$linkItem.Index = [int]($linkItem.Index)
				$linkItem.TotalCount = [int]($linkItem.TotalCount)
			}
			$orgUnit = Get-OU -DistinguishedName $LinkObject[0].TargetOU -Server $Domain
			$insertIndex = 1
			foreach ($linkItem in ($LinkObject | Sort-Object Index))
			{
				if ($orgUnit.LinkedGroupPolicyObjects -contains $linkItem.Policy.CleanedPath)
				{
					$insertIndex = $orgUnit.LinkedGroupPolicyObjects.IndexOf($linkItem.Policy.CleanedPath) + 1
					continue
				}
				
				$paramSetGPLink = @{
					LinkEnabled = 'Yes'
					Guid	    = $linkItem.Policy.ID
					Order	    = $insertIndex
					Domain	    = $Domain
					Enforced    = 'No'
					Target	    = $orgUnit
					Server	    = $Server
					ErrorAction = 'Stop'
				}
				if ($linkItem.State -eq "1") { $paramSetGPLink['LinkEnabled'] = 'No' }
				if ($linkItem.State -eq "2") { $paramSetGPLink['Enforced'] = 'Yes' }
				
				try
				{
					$null = New-GPLink @paramSetGPLink
					New-ImportResult -Action 'Importing Group Policy Links' -Step 'Applying Link' -Target $linkItem.GpoName -Data $linkItem -Success $true
				}
				catch
				{
					New-ImportResult -Action 'Importing Group Policy Links' -Step 'Applying Link' -Target $linkItem.GpoName -Data $linkItem -Success $false -ErrorData $_
				}
				
				$insertIndex++
			}
		}
		#endregion Utility Functions
		
		$PSDefaultParameterValues['New-ImportResult:Action'] = 'Importing Group Policy Links'
		$PSDefaultParameterValues['New-ImportResult:Success'] = $false
		
		$pathItem = Get-Item -Path $Path
		if ($pathItem.Extension -eq '.csv') { $resolvedPath = $pathItem.FullName }
		else { $resolvedPath = (Get-ChildItem -Path $pathItem.FullName -Filter 'gp_links_*.csv' | Select-Object -First 1).FullName }
		if (-not $resolvedPath) { throw "Could not find GPO Links file in $($pathItem.FullName)" }
		
		$domainObject = Get-ADDomain -Server $Domain
		$policyObjects = Get-GPO -All -Domain $Domain | Select-Object *, @{
			Name	   = 'CleanedPath'
			Expression = { $_.Path -replace $_.ID, $_.ID }
		}
		$linkData = Import-Csv $resolvedPath | Where-Object {
			Test-Overlap -ReferenceObject $_.GpoName -DifferenceObject $Name -Operator Like
		} | Select-Object *, @{
			Name		    = "Policy"
			Expression	    = {
				$linkItem = $_
				$policyObjects | Where-Object DisplayName -EQ $linkItem.GpoName
			}
		}, @{
			Name																	   = "TargetOU"
			Expression																   = {
				'{0},{1}' -f ($_.OUDN -replace ',DC=\w+'), $domainObject.DistinguishedName
			}
		}
	}
	process
	{
		$groupedLinks = $linkData | Group-Object -Property GpoName
		$groupedLinks | Where-Object Name -NotIn $policyObjects.DisplayName | ForEach-Object {
			New-ImportResult -Step 'Checking GPO existence' -Target $_.Name -Data $_.Group -ErrorData "GPO $($_.Name) does not exist"
		}
		$linksPolicyExists = ($groupedLinks | Where-Object Name -In $policyObjects.DisplayName).Group
		$linksPolicyExists | Where-Object { -not (Get-OU -DistinguishedName $_.TargetOU -Server $Domain) } | ForEach-Object {
			New-ImportResult -Step 'Checking OU existence' -Target $_.GpoName -Data $_ -ErrorData "OU $($_.TargetOU) does not exist, cannot link $($_.GpoName)"
		}
		$linksToProcess = $linksPolicyExists | Where-Object { Get-OU -DistinguishedName $_.TargetOU -Server $Domain }
		
		$groupedToProcess = $linksToProcess | Group-Object -Property TargetOU
		foreach ($linkSet in $groupedToProcess)
		{
			Set-GPLinkSet -LinkObject $linkSet.Group -Domain $domainObject.DNSRoot -AllGpos $policyObjects -Server $domainObject.PDCEmulator
		}
	}
}
