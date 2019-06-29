Function Export-WMIFilter {
Param(
    [Parameter(Mandatory=$true)]
    [String[]]
    $Name,
    [Parameter(Mandatory=$true)]
    [String]
    $SrceServer,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path
)
    # CN=SOM,CN=WMIPolicy,CN=System,DC=wingtiptoys,DC=local
    $WMIPath = "CN=SOM,CN=WMIPolicy,$((Get-ADDomain -Server $SrceServer).SystemsContainer)"

    Get-ADObject -Server $SrceServer -SearchBase $WMIPath -Filter {objectClass -eq 'msWMI-Som'} -Properties msWMI-Author, msWMI-Name, msWMI-Parm1, msWMI-Parm2 |
     Where-Object {$Name -contains $_."msWMI-Name"} |
     Select-Object msWMI-Author, msWMI-Name, msWMI-Parm1, msWMI-Parm2 |
     Export-CSV (Join-Path $Path WMIFilter.csv) -NoTypeInformation
}
