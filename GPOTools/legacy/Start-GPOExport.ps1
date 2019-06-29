Function Start-GPOExport {
Param (
    [Parameter(Mandatory=$true)]
    [String]
    $SrceDomain,
    [Parameter(Mandatory=$true)]
    [String]
    $SrceServer,
    [Parameter(Mandatory=$true)]
    [String[]]
    $DisplayName,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path  # Working path to store migration tables and backups
)
    # Backup the GPOs
    # Capture the backup path for subsequent cmdlets
    # Dump the WMI filters also
    $BackupPath = Invoke-BackupGPO -SrceDomain $SrceDomain -SrceServer $SrceServer -DisplayName $DisplayName -Path $Path
    
    # Dump the permissions
    Export-GPPermission -SrceDomain $SrceDomain -SrceServer $SrceServer -DisplayName $DisplayName -Path $BackupPath

    # Dump the WMI filters
    # This is called from Invoke-BackupGPO
    #Export-WMIFilter -SrceServer $SrceServer -Path $BackupPath

    "Use this path as input for the import command."
    "BackupPath: ""$BackupPath"""
}
