function Get-GptPrincipal
{
<#
	.SYNOPSIS
		Generates a list of principals relevant to the specified GPO.
	
	.DESCRIPTION
		Generates a list of principals relevant to the specified GPO.
		This is used internally to generate the identities export.
		It can also be used directly, to assess needed identities (for example when setting up a test domain).
	
	.PARAMETER Path
		Path to an already existing GPO backup.
		Using this will have the module scan a backup, rather than live GPO.
	
	.PARAMETER Name
		The name to filter GPOs by.
		Defaults to '*'
		Accepts multiple strings, a single wildcard match is needed for a GPO to be selected.
	
	.PARAMETER GpoObject
		The GPO to process, as returned by Get-Gpo.
	
	.PARAMETER Domain
		The domain to connect to.
		Defaults to the user dns domain.
	
	.PARAMETER IncludeUNC
		By default, UNC paths are not included in the output.
		These too can be read from GPO and might be relevant.
	
	.EXAMPLE
		PS C:\> Get-GptPrincipal
	
		Returns the relevant principals from all GPOs in the current domain.
#>
	[CmdletBinding(DefaultParameterSetName = 'GPO')]
	param (
		[Parameter(ParameterSetName = "Path")]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]
		$Path,
		
		[Parameter(ParameterSetName = 'GPO')]
		[string[]]
		$Name = '*',
		
		[Parameter(ParameterSetName = 'GPO', ValueFromPipeline = $true)]
		$GpoObject,
		
		[string]
		$Domain = $env:USERDNSDOMAIN,
		
		[switch]
		$IncludeUNC
	)
	
	begin
	{
		if (-not $Path)
		{
			$tempPath = New-Item -Path $env:TEMP -ItemType Directory -Name "Gpo_TempBackup_$(Get-Random -Maximum 999999 -Minimum 100000)" -Force
			$backupPath = $tempPath.FullName
		}
		else { $backupPath = (Resolve-Path -Path $Path).ProviderPath }
		
		$entryType = @{
			0 = 'User'
			1 = 'Computer'
			2 = 'LocalGroup'
			3 = 'DomainGroup'
			4 = 'UniversalGroup'
			5 = 'UNCPath'
			6 = 'Unknown'
		}
	}
	process
	{
		#region Export GPO to temporary path
		if (-not $Path)
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
			$null = $gpoObjects | Backup-GPO -Path $backupPath
		}
		#endregion Export GPO to temporary path
	}
	end
	{
		$groupPolicyManager = New-Object -ComObject GPMgmt.GPM
		$migrationTable = $groupPolicyManager.CreateMigrationTable()
		$constants = $groupPolicyManager.getConstants()
		$backupDirectory = $groupPolicyManager.GetBackupDir($backupPath)
		$backupList = $backupDirectory.SearchBackups($groupPolicyManager.CreateSearchCriteria())
		
		foreach ($policyBackup in $backupList)
		{
			$migrationTable.Add(0, $policyBackup)
			$migrationTable.Add($constants.ProcessSecurity, $policyBackup)
		}
		
		foreach ($entry in $migrationTable.GetEntries())
		{
			$paramAddMember = @{
				MemberType = 'NoteProperty'
				Name	   = 'EntryType'
				Value	   = $entryType[$entry.EntryType]
				PassThru   = $true
				Force	   = $true
			}
			
			switch ($entry.EntryType)
			{
				$constants.EntryTypeUNCPath
				{
					if (-not $IncludeUNC) { break }
					
					[PSCustomObject]@{
						EntryType = $entryType[$entry.EntryType]
						Path	  = $entry.Source
					}
				}
				default
				{
					#region SID
					if ($sid = $entry.Source -as [System.Security.Principal.SecurityIdentifier])
					{
						if ($sid.DomainSID)
						{
							Resolve-ADPrincipal -Name $sid -Domain $sid.DomainSID | Add-Member @paramAddMember
							continue
						}
						
						Resolve-ADPrincipal -Name $sid -Domain $Domain | Add-Member @paramAddMember
						continue
					}
					#endregion SID
					
					#region Name
					try
					{
						$sid = ([System.Security.Principal.NTAccount]$entry.Source).Translate([System.Security.Principal.SecurityIdentifier])
						
						if ($sid.DomainSID)
						{
							Resolve-ADPrincipal -Name $sid -Domain $sid.DomainSID | Add-Member @paramAddMember
							continue
						}
						
						Resolve-ADPrincipal -Name $sid -Domain $Domain | Add-Member @paramAddMember
						continue
					}
					catch
					{
						if ($entry.Source -like '*@*')
						{
							$entity, $domainName = $entry.Source -split '@'
							Resolve-ADPrincipal -Name $entity -Domain $domainName | Add-Member @paramAddMember
							continue
						}
						else
						{
							Resolve-ADPrincipal -Name $entry.Source -Domain $Domain | Add-Member @paramAddMember
							continue
						}
					}
					#endregion Name
				}
			}
		}
		
		if (-not $Path)
		{
			Remove-Item -Path $tempPath -Recurse -Force
		}
	}
}