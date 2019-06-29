Function Import-GPLink {
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
    $BackupPath,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $MigTableCSVPath # Path for migration table source for automatic migtable generation
)
    $gpm = New-Object -ComObject GPMgmt.GPM
    $Constants = $gpm.getConstants()
    $GPMBackupDir = $gpm.GetBackupDir($BackupPath)
    $GPMSearchCriteria = $gpm.CreateSearchCriteria()
    $BackupList = $GPMBackupDir.SearchBackups($GPMSearchCriteria)

    $MigTableCSV = Import-CSV $MigTableCSVPath
    $MigDomains  = $MigTableCSV | Where-Object {$_.Type -eq "Domain"}        

    ForEach ($GPMBackup in $BackupList) {

        "`n`n$($GPMBackup.GPODisplayName)"

        <#
        ID             : {2DA3E56D-061C-4CB7-95D8-DCA4D023ACF5}
        GPOID          : {F9A98B0E-12A3-4A1B-AFE9-97CEB089FEBE}
        GPODomain      : FOO.COM
        GPODisplayName : Desktop Super Powers
        Timestamp      : 1/14/2014 1:55:36 PM
        Comment        : Desktop Super Powers
        BackupDir      : C:\temp\Backup\
        #>
        [xml]$GPReport = Get-Content (Join-Path -Path $GPMBackup.BackupDir -ChildPath "$($GPMBackup.ID)\gpreport.xml")
        
        $gPLinks = $null
        $gPLinks = $GPReport.GPO.LinksTo | Select-Object SOMName, SOMPath, Enabled, NoOverride
        # There may not be any gPLinks in the source domain.
        If ($gPLinks) {
            # Parse out the domain name, translate it to the destination domain name.
            # Create a distinguished name path from the SOMPath
            # wingtiptoys.local/Testing/SubTest
            ForEach ($gPLink in $gPLinks) {

                $SplitSOMPath = $gPLink.SOMPath -split '/'

                # Swap the source and destination domain names
                $DomainName = $SplitSOMPath[0]
                ForEach ($d in $MigDomains) {
                    If ($d.Source -eq $SplitSOMPath[0]) {
                        $DomainName = $d.Destination
                    }
                }
                
                # Calculate the full OU distinguished name path
                $DomainDN = 'DC=' + $DomainName.Replace('.',',DC=')
                $OU_DN = $DomainDN
                For ($i=1;$i -lt $SplitSOMPath.Length;$i++) {
                    $OU_DN = "OU=$($SplitSOMPath[$i])," + $OU_DN
                }

                # Add the DN path as a property on the object
                Add-Member -InputObject $gPLink -MemberType NoteProperty -Name gPLinkDN -Value $OU_DN

                # Now check to see that the SOM path exists in the destination domain
                # If Exists, then create the link
                # If NotExists, then report an error
                
                <#  gPLink.
                SOMName     SOMPath                           Enabled NoOverride gPLinkDN                                    
                -------     -------                           ------- ---------- --------                                    
                SubTest     wingtiptoys.local/Testing/SubTest true    false      OU=SubTest,OU=Testing,DC=cohovineyard,DC=com
                wingtiptoys wingtiptoys.local                 false   false      DC=cohovineyard,DC=com                      
                #>

                # Put the potential error line outside the context of the IF
                # so that it doesn't cause the whole construct to error out.
                # This is a bit of a hack on the error trapping,
                # but the Get-ADObject does not seem to obey the -ErrorAction parameter
                # at least with PS v2 on 2008 R2.
                $SOMPath = $null
                $ErrorActionPreference = 'SilentlyContinue'
                $SOMPath = Get-ADObject -Server $DestServer -Identity $gPLink.gPLinkDN -Properties gPLink
                $ErrorActionPreference = 'Continue'

                # Only attempt to link the policy if the destination path exists.
                If ($SOMPath) {
                    "gPLink: $($gPLink.gPLinkDN)"
                    # It is possible that the policy is already linked to the destination path.
                    try {
                        New-GPLink -Domain $DestDomain -Server $DestServer `
                            -Name $GPMBackup.GPODisplayName `
                            -Target $gPLink.gPLinkDN `
                            -LinkEnabled $(If ($gPLink.Enabled -eq 'true') {'Yes'} Else {'No'}) `
                            -Enforced $(If ($gPLink.NoOverride -eq 'true') {'Yes'} Else {'No'}) `
                            -Order $(If ($SOMPath.gPLink.Length -gt 1) {$SOMPath.gPLink.Split(']').Length} Else {1}) `
                            -ErrorAction Stop
                        # We calculated the order by counting how many gPLinks already exist.
                        # This ensures that it is always linked last in the order.
                    }
                    catch {
                        Write-Warning "gPLink Error: $($gPLink.gPLinkDN)"
                        $_.Exception
                    }
                } Else {
                    Write-Warning "gPLink path does not exist: $($gPLink.gPLinkDN)"
                } # End if SOMPath exists
            } # End ForEach gPLink
        } Else {
            "No gPLinks for GPO: $($GPMBackup.GPODisplayName)."
        } # End If gPLinks exist
    }
}
