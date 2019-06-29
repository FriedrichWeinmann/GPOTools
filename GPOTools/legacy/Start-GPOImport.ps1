Function Start-GPOImport {
Param (
    [Parameter(Mandatory=$true,HelpMessage="Must be FQDN.")]
    [ValidateScript({$_ -like "*.*"})]
    [String]
    $DestDomain,
    [Parameter(Mandatory=$true)]
    [String]
    $DestServer,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $BackupPath,  # Path from GPO backup
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $MigTableCSVPath,
    [Parameter()]
    [Switch]
    $CopyACL
)
    # Create the migration table
    # Capture the MigTablePath and MigTableCSVPath for use with subsequent cmdlets
    $MigTablePath = New-GPOMigrationTable -DestDomain $DestDomain -Path $Path -BackupPath $BackupPath -MigTableCSVPath $MigTableCSVPath

    # View the migration table
    Show-GPOMigrationTable -Path $MigTablePath

    # Validate the migration table
    # No output is good.
    Test-GPOMigrationTable -Path $MigTablePath

    # OPTIONAL
    # Remove any pre-existing GPOs of the same name in the destination environment
    # Use this for these scenarios:
    # - You want a clean import. Remove any existing policies of the same name first.
    # - You want to start over and import them again.
    # - Import-GPO will fail if a GPO of the same name exists in the target.
    Invoke-RemoveGPO -DestDomain $DestDomain -DestServer $DestServer -BackupPath $BackupPath

    # Import all from backup
    # This will fail for any policies that are missing migration table accounts in the destination domain.
    Invoke-ImportGPO -DestDomain $DestDomain -DestServer $DestServer -BackupPath $BackupPath -MigTablePath $MigTablePath -CopyACL

    # Import WMIFilters
    Import-WMIFilter -DestServer $DestServer -Path $BackupPath

    # Relink the WMI filters to the GPOs
    Set-GPWMIFilterFromBackup -DestDomain $DestDomain -DestServer $DestServer -BackupPath $BackupPath

    # Link the GPOs to destination OUs of same path
    # The migration table CSV is used to remap the domain name portion of the OU distinguished name paths.
    Import-GPLink -DestDomain $DestDomain -DestServer $DestServer -BackupPath $BackupPath -MigTableCSVPath $MigTableCSVPath
}
