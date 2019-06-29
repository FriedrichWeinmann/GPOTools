Function Import-WMIFilter {
Param (
    [Parameter(Mandatory=$true)]
    [String]
    $DestServer,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path
)
    $WMIExportFile = Join-Path -Path $Path -ChildPath 'WMIFilter.csv'
    If ((Test-Path $WMIExportFile) -eq $false) {

        Write-Warning "No WMI filters to import."

    } Else {
    
        $WMIImport = Import-Csv $WMIExportFile
        $WMIPath = "CN=SOM,CN=WMIPolicy,$((Get-ADDomain -Server $DestServer).SystemsContainer)"

        $ExistingWMIFilters = Get-ADObject -Server $DestServer -SearchBase $WMIPath `
            -Filter {objectClass -eq 'msWMI-Som'} `
            -Properties msWMI-Author, msWMI-Name, msWMI-Parm1, msWMI-Parm2

        ForEach ($WMIFilter in $WMIImport) {

            If ($ExistingWMIFilters | Where-Object {$_.'msWMI-Name' -eq $WMIFilter.'msWMI-Name'}) {
                Write-Host "WMI filter already exists: $($WMIFilter."msWMI-Name")"
            } Else {
                $msWMICreationDate = (Get-Date).ToUniversalTime().ToString("yyyyMMddhhmmss.ffffff-000")
                $WMIGUID = "{$([System.Guid]::NewGuid())}"
    
                $Attr = @{
                    "msWMI-Name" = $WMIFilter."msWMI-Name";
                    "msWMI-Parm2" = $WMIFilter."msWMI-Parm2";
                    "msWMI-Author" = $WMIFilter."msWMI-Author";
                    "msWMI-ID"= $WMIGUID;
                    "instanceType" = 4;
                    "showInAdvancedViewOnly" = "TRUE";
                    "msWMI-ChangeDate" = $msWMICreationDate; 
                    "msWMI-CreationDate" = $msWMICreationDate
                }
    
                # The Description in the GUI (Parm1) may be null. If so, that will botch the New-ADObject.
                If ($WMIFilter."msWMI-Parm1") {
                    $Attr.Add("msWMI-Parm1",$WMIFilter."msWMI-Parm1")
                }

                $ADObject = New-ADObject -Name $WMIGUID -Type "msWMI-Som" -Path $WMIPath -OtherAttributes $Attr -Server $DestServer -PassThru
                Write-Host "Created WMI filter: $($WMIFilter."msWMI-Name")"
            }
        }
    } # End If No WMI filters
}
