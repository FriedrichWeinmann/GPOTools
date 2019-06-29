function New-MigrationTable
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[Parameter(Mandatory = $true)]
		[string]
		$BackupPath,
		
		[string]
		$Domain = $env:USERDNSDOMAIN
	)
	
	begin
	{
		$resolvedPath = (Resolve-Path $Path).ProviderPath
		$resolvedBackupPath = (Resolve-Path $BackupPath).ProviderPath
		$writePath = Join-Path -Path $resolvedPath -ChildPath "$Domain.migtable"
		
		#region Resolving source and destination Domain Names
		$domainObject = Get-ADDomain -Server $Domain
		$destDomainDNS = $domainObject.DNSRoot
		$destDomainNetBios = $domainObject.NetBIOSName
		
		if ($script:sourceDomainData)
		{
			$sourceDomainDNS = $script:sourceDomainData.DomainDNSName
			$sourceDomainNetBios = $script:sourceDomainData.NetBIOSName
		}
		elseif ($script:identityMapping.Count -gt 0)
		{
			$sourceDomainDNS = $script:identityMapping[0].DomainFqdn
			$sourceDomainNetBios = $script:identityMapping[0].DomainName
		}
		else
		{
			throw "Unable to determine source domain. Run Import-GptDomainData or Import-GptIdentity first!"
		}
		#endregion Resolving source and destination Domain Names
		
		#region Preparing imported identities
		$explicitIdentityMappings = foreach ($identity in $script:identityMapping)
		{
			if (($identity.IsBuiltIn -eq 'True') -and ($identity.SID -like "*-32-*"))
			{
				[PSCustomObject]@{
					Source = $identity.Name
					Target = $identity.Target
				}
			}
			else
			{
				[PSCustomObject]@{
					Source = ('{0}\{1}' -f $sourceDomainNetBios, $identity.Name)
					Target = ('{0}\{1}' -f $destDomainNetBios, $identity.Target)
				}
				[PSCustomObject]@{
					Source = ('{0}@{1}' -f $identity.Name, $sourceDomainDNS)
					Target = ('{0}@{1}' -f $identity.Target, $destDomainDNS)
				}
			}
		}
		#endregion Preparing imported identities
	}
	process
	{
		#region Preparing basic migration table
		$groupPolicyManager = New-Object -ComObject GPMgmt.GPM
		$migrationTable = $groupPolicyManager.CreateMigrationTable()
		$constants = $groupPolicyManager.getConstants()
		$backupDirectory = $groupPolicyManager.GetBackupDir($resolvedBackupPath)
		$backupList = $backupDirectory.SearchBackups($groupPolicyManager.CreateSearchCriteria())
		
		foreach ($policyBackup in $backupList)
		{
			$migrationTable.Add(0, $policyBackup)
			$migrationTable.Add($constants.ProcessSecurity, $policyBackup)
		}
		#endregion Preparing basic migration table
		
		#region Applying identity and UNC mappings
		foreach ($entry in $migrationTable.GetEntries())
		{
			switch ($entry.EntryType)
			{
				$constants.EntryTypeUNCPath
				{
					if ($entry.Source -like "\\$sourceDomainDNS\*")
					{
						$null = $migrationTable.UpdateDestination($entry.Source, $entry.Source.Replace("\\$sourceDomainDNS\", "\\$destDomainDNS\"))
					}
					if ($entry.Source -like "\\$sourceDomainNetBios\*")
					{
						$null = $migrationTable.UpdateDestination($entry.Source, $entry.Source.Replace("\\$sourceDomainNetBios\", "\\$destDomainNetBios\"))
					}
				}
				
				{ $constants.EntryTypeUser, $constants.EntryTypeGlobalGroup, $constants.EntryTypeUniversalGroup, $constants.EntryTypeUnknown -contains $_ } {
					if ($mapping = $explicitIdentityMappings | Where-Object Source -EQ $entry.Source)
					{
						$null = $migrationTable.UpdateDestination($entry.Source, $mapping.Target)
					}
				}
			}
		}
		#endregion Applying identity and UNC mappings
		
		$migrationTable.Save($writePath)
		$writePath
	}
}