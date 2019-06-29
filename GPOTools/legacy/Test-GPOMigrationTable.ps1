Function Test-GPOMigrationTable {
Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path
)
    $gpm = New-Object -ComObject GPMgmt.GPM
    $mt = $gpm.GetMigrationTable($Path)
    $mt.Validate().Status
}
