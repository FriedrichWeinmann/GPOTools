function Invoke-ImportGPO
{
	param (
		[Parameter(Mandatory = $true)]
		[String]
		$DestDomain,
		
		[Parameter(Mandatory = $true)]
		[String]
		$DestServer,
		
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[String]
		$BackupPath,
		
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[String]
		$MigTablePath,
		
		[Parameter()]
		[Switch]
		$CopyACL
	)
	$gpm = New-Object -ComObject GPMgmt.GPM
	$Constants = $gpm.getConstants()
	$GPMBackupDir = $gpm.GetBackupDir($BackupPath)
	$GPMSearchCriteria = $gpm.CreateSearchCriteria()
	$BackupList = $GPMBackupDir.SearchBackups($GPMSearchCriteria)
	
	foreach ($GPMBackup in $BackupList) {
        <#
        ID             : {2DA3E56D-061C-4CB7-95D8-DCA4D023ACF5}
        GPOID          : {F9A98B0E-12A3-4A1B-AFE9-97CEB089FEBE}
        GPODomain      : FOO.COM
        GPODisplayName : Desktop Super Powers
        Timestamp      : 1/14/2014 1:55:36 PM
        Comment        : Desktop Super Powers
        BackupDir      : C:\temp\Backup\
        #>
		
		"Importing GPO: $($GPMBackup.GPODisplayName)"
		try
		{
			Import-GPO -Domain $DestDomain -Server $DestServer -BackupGpoName $GPMBackup.GPODisplayName -TargetName $GPMBackup.GPODisplayName -Path $BackupPath -MigrationTable $MigTablePath -CreateIfNeeded
		}
		catch
		{
			if ($_.Exception.ToString().Contains('0x8007000D'))
			{
				""
				$_.Exception
				"Error importing GPO: $($_.InvocationInfo.BoundParameters.Item('BackupGpoName'))"
				"One or more security principals (user, group, etc.) in the migration table are not found in the destination domain."
				""
			}
			else
			{
				""
				"An import error occurred:"
				$_ | Format-List * -force
				$_.InvocationInfo.BoundParameters | Format-List * -force
				$_.Exception
				""
			}
		} # End Catch
		
		# Migrate the ACLs
		# NOTE: This may not handle universal groups or groups from other domains.
		if ($CopyACL)
		{
			Import-GPPermission -DestDomain $DestDomain -DestServer $DestServer -DisplayName $GPMBackup.GPODisplayName -Path "$BackupPath\GPPermissions.csv" -MigTablePath $MigTablePath
		} # End If CopyACL
	} # End ForEach GPMBackup
}
