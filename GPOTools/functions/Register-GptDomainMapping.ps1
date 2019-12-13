function Register-GptDomainMapping {
    <#
    .SYNOPSIS
        Maps source domain names to the associated target domain.
    
    .DESCRIPTION
        Maps source domain names to the associated target domain.
        This is used to map source identities to the correct destination domains.
        This data is used during import/restore only!
    
    .PARAMETER SourceName
        Netbios name of the source domain.
        Last resort for source identity domain translation.
    
    .PARAMETER SourceFQDN
        FQDN of the source domain.
    
    .PARAMETER SourceSID
        SID of the source domain.
        Primary tool for source identity domain translation.
    
    .PARAMETER Destination
        The destination domain.
        Either offer an active directory domain object (Returned by Get-ADDOmain) or a name that will be looked up.
    
    .PARAMETER Server
        Server to use for looking up the destination domain data.
        Used only when the Destination parameter waas set to string value (such as the fqdn of the domain).
    
    .EXAMPLE
        PS C:\> Register-GptDomainMapping -SourceName corp -SourceFQDN corp.contoso.com -SourceSID $sid -Destination $domain

        Registers name mappings, pointing corp.contoso.com to the destination domain stored in $domain.
    #>
    [CmdletBinding()]
    param (
        [string]
        $SourceName,

        [string]
        $SourceFQDN,

        [string]
        $SourceSID,

        $Destination,
        [string]
        
        $Server
    )

    begin
    {
        if (-not $script:domainMapping) {
            $script:domainMapping = @{
                Name = @{ }
                FQDN = @{ }
                SID = @{ }
            }
        }
        # Do not check for actual type, in order to allow users to fake/mock up a custom object
        if ($Destination.PSObject.TypeNames -contains 'Microsoft.ActiveDirectory.Management.ADDomain') {
            $domainObject = $Destination
        }
        else {
            $params = @{
                Domain = $Destination
                ErrorAction = 'Stop'
            }
            if ($Server) { $params['Server'] = $Server }
            try { $domainObject = Get-ADDomain @params }
            catch {
                Write-Warning "Failed to resolve destination domain: $Destination : $_"
                throw
            }
        }
    }
    process
    {
        if ($SourceName) {
            $script:domainMapping.Name[$SourceName] = $domainObject
        }
        if ($SourceFQDN) {
            $script:domainMapping.FQDN[$SourceFQDN] = $domainObject
        }
        if ($SourceSID) {
            $script:domainMapping.SID[$SourceSID] = $domainObject
        }
    }
}