function Import-GptObject
{
<#
	.SYNOPSIS
		Import Group Policy Objects previously exported using Export-GptObject.
	
	.DESCRIPTION
		Import Group Policy Objects previously exported using Export-GptObject.
	
	.PARAMETER Path
		The path where the GPO export folders are located.
		Note: GPO export folders have a GUID as name.
	
	.PARAMETER Name
		Only import GPOs with a matching name.
	
	.PARAMETER Domain
		THe destination domain to import into.
	
	.EXAMPLE
		PS C:\> Import-GptObject -Path '.'
	
		Import all GPO objects exported into the current folder.
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
		$pdcEmulator = (Get-ADDomain -Server $Domain).PDCEmulator
		if (-not (Test-Path $Path))
		{
			New-ImportResult -Action 'Importing Policy Objects' -Step 'Validating import path' -Target $Path -Success $false
			throw "Import path not found: $Path"
		}
		if ((Get-Item -Path $Path).Extension -eq '.csv') { $gpoFile = Get-Item -Path $Path }
		elseif (Test-Path -Path (Join-Path -Path $Path -ChildPath 'gp_object_*.csv')) { $gpoFile = Get-Item (Join-Path -Path $Path -ChildPath 'gp_object_*.csv') }
		elseif (Test-Path -Path (Join-Path -Path (Join-Path -Path $Path -ChildPath 'GPO') -ChildPath 'gp_object_*.csv')) { $gpoFile = Get-Item (Join-Path -Path (Join-Path -Path $Path -ChildPath 'GPO') -ChildPath 'gp_object_*.csv') }
		else
		{
			New-ImportResult -Action 'Importing Policy Objects' -Step 'Validating import path' -Target $Path -Success $false
			throw "Could not find GPO backup index under: $Path"
		}
		$gpoData = Import-Csv -Path $gpoFile.FullName
		
		try { $migrationTablePath = New-MigrationTable -Path $gpoFile.DirectoryName -BackupPath $gpoFile.DirectoryName -Domain $Domain -ErrorAction Stop }
		catch
		{
			New-ImportResult -Action 'Importing Policy Objects' -Step 'Creating Migration Table' -Target $Path -Success $false -ErrorData $_
			throw
		}
	}
	process
	{
		foreach ($gpoEntry in $gpoData)
		{
			if (-not (Test-Overlap -ReferenceObject $gpoEntry.DisplayName -DifferenceObject $Name -Operator Like))
			{
				continue
			}
			
			$paramImportGPO = @{
				Domain	      = $Domain
				Server	      = $pdcEmulator
				BackupGpoName = $gpoEntry.DisplayName
				TargetName    = $gpoEntry.DisplayName
				Path		  = $gpoFile.DirectoryName
				MigrationTable = $migrationTablePath
				CreateIfNeeded = $true
				ErrorAction   = 'Stop'
			}
			try
			{
				Write-Verbose "Importing Policy object: $($gpoEntry.DisplayName)"
				$importedGPO = Import-GPO @paramImportGPO
				if ($gpoEntry.WmiFilter)
				{
					$wmiFilter = Get-ADObject -SearchBase "CN=SOM,CN=WMIPolicy,$((Get-ADDomain -Server $pdcEmulator).SystemsContainer)" -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$($gpoEntry.WmiFilter)))"
					Set-ADObject -Identity $importedGPO.Path -Replace @{ gPCWQLFilter = "[$Domain;$($wmiFilter.Name);0]" } -Server $pdcEmulator
				}
				New-ImportResult -Action 'Importing Policy Objects' -Step 'Import Object' -Target $gpoEntry -Success $true -Data $gpoEntry, $migrationTablePath
			}
			catch
			{
				New-ImportResult -Action 'Importing Policy Objects' -Step 'Import Object' -Target $gpoEntry -Success $false -Data $gpoEntry, $migrationTablePath -ErrorData $_
				Write-Error $_
			}
		}
	}
}
