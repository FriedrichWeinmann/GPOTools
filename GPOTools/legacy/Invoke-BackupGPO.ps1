function Invoke-BackupGPO {
Param(
    [Parameter(Mandatory=$true,
        ParameterSetName="All")]
    [Switch]
    $All, # Backup all GPOs
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="DisplayName")]
    [String[]]
    $DisplayName, # Array of GPO DisplayNames to backup
    [Parameter(Mandatory=$true)]
    [String]
    $SrceDomain,
    [Parameter(Mandatory=$true)]
    [String]
    $SrceServer,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path # Base path where backup folder will be created
)
    $BackupPath = Join-Path $Path "\GPO Backup $SrceDomain $(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')\"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    
    If ($All) {
        Backup-GPO -Server $SrceServer -Domain $SrceDomain -Path $BackupPath -All | Out-Null
    } Else {
        ForEach ($Name in $DisplayName) {
            Backup-GPO -Server $SrceServer -Domain $SrceDomain -Path $BackupPath -Name $Name | Out-Null
        }
    }

    # Backup WMI filters
    If ($All) {
        $WMIFilterNames = Get-GPO -All |
            Where-Object {$_.WmiFilter} |
            Select-Object -ExpandProperty WmiFilter |
            Select-Object -ExpandProperty Name -Unique
    } Else {
        $WMIFilterNames = Get-GPO -All |
            Where-Object {$DisplayName -contains $_.DisplayName -and $_.WmiFilter} |
            Select-Object -ExpandProperty WmiFilter |
            Select-Object -ExpandProperty Name -Unique
    }
    If ($WMIFilterNames) {
        Export-WMIFilter -Name $WMIFilterNames -SrceServer $SrceServer -Path $BackupPath
    } Else {
        Write-Host "No WMI filters to export."
    }

    return $BackupPath
}
