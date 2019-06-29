Function Invoke-RemoveGPO {
Param (
    [Parameter(Mandatory=$true)]
    [String]
    $DestDomain,
    [Parameter(Mandatory=$true)]
    [String]
    $DestServer,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $BackupPath
)
    $gpm = New-Object -ComObject GPMgmt.GPM
    $Constants = $gpm.getConstants()
    $GPMBackupDir = $gpm.GetBackupDir($BackupPath)
    $GPMSearchCriteria = $gpm.CreateSearchCriteria()
    $BackupList = $GPMBackupDir.SearchBackups($GPMSearchCriteria)

    ForEach ($GPMBackup in $BackupList) {
        <#
        ID             : {2DA3E56D-061C-4CB7-95D8-DCA4D023ACF5}
        GPOID          : {F9A98B0E-12A3-4A1B-AFE9-97CEB089FEBE}
        GPODomain      : FOO.COM
        GPODisplayName : Desktop Super Powers
        Timestamp      : 1/14/2014 1:55:36 PM
        Comment        : Desktop Super Powers
        BackupDir      : C:\temp\Backup\
        #>

        Write-Host "From domain $DestDomain removing GPO: $($GPMBackup.GPODisplayName)"
        try {
            Remove-GPO -Domain $DestDomain -Server $DestServer -Name $GPMBackup.GPODisplayName -ErrorAction Stop
        }
        catch {
            $_.Exception
            Continue
        }
    }
}
