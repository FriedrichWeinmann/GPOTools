Function Set-GPWMIFilterFromBackup {
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
    # Get the WMI Filter associated with each GPO backup
    $GPOBackups = Get-ChildItem $BackupPath -Filter "backup.xml" -Recurse

    ForEach ($Backup in $GPOBackups) {

        $GPODisplayName = $WMIFilterName = $null

        [xml]$BackupXML = Get-Content $Backup.FullName
        $GPODisplayName = $BackupXML.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName."#cdata-section"
        $WMIFilterName = $BackupXML.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.WMIFilterName."#cdata-section"

        If ($WMIFilterName) {
            "Linking WMI filter '$WMIFilterName' to GPO '$GPODisplayName'."
            $WMIFilter = Get-ADObject -SearchBase "CN=SOM,CN=WMIPolicy,$((Get-ADDomain -Server $DestServer).SystemsContainer)" `
                -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$WMIFilterName))" `
                -Server $DestServer
            If ($WMIFilter) {
                Set-ADObject -Identity (Get-GPO $GPODisplayName).Path `
                    -Replace @{gPCWQLFilter="[$DestDomain;$($WMIFilter.Name);0]"} `
                    -Server $DestServer
            } Else {
                Write-Warning "WMI filter '$WMIFilterName' NOT FOUND.  Manually create and link the WMI filter."
            }
        } Else {
            "No WMI Filter for GPO '$GPODisplayName'."
        }
    }
}
