function Resolve-DomainMapping {
    <#
    .SYNOPSIS
        Resolves a source domain from a GPO export into domain of the destination domain.
    
    .DESCRIPTION
        Resolves a source domain from a GPO export into domain of the destination domain.
        The mapping data for this is managed by Register-GptDomainMapping.
        Usual source of mapping data is Import-GptDomainData and a scan of the destination forest.

        Accepts SID, Fqdn and Netbios Name as input to find the correct domain.
        Uses SID first, then Fqdn and only as a last resort the Netbios name, if all are specified.

        It returns an AD Domain object, representing the destination domain the source domain maps to.
        This object can be faked by the user, if manual data sources need to be included,
        but it is assumed, that such an object will also have all the data fields required.
    
    .PARAMETER DomainSid
        SID of the domain from the export source.
    
    .PARAMETER DomainFqdn
        Fqdn of the domain from the export source.
    
    .PARAMETER DomainName
        Name of the domain from the export source.
    
    .EXAMPLE
        PS C:\> Resolve-DomainMapping -DomainSid $identity.DomainSID -DomainFqdn $identity.DomainFqdn -DomainName $identity.DomainName

        Resolves the destination domain to map the specified identity to.
        Tries to use SID first, then FQDN and Netbios name only if nothing else worked.
    #>
    [CmdletBinding()]
    param (
        [string]
        $DomainSid,

        [string]
        $DomainFqdn,

        [string]
        $DomainName
    )

    if (-not $script:domainMapping) {
        throw "No domain mappings loaded yet. Run Import-GptDomain or Register-GptDomainMapping to initialize the domain resolution table."
    }

    if ($DomainSid -and $script:domainMapping.Sid[$DomainSid]) {
        return $script:domainMapping.Sid[$DomainSid]
    }
    if ($DomainFqdn -and $script:domainMapping.FQDN[$DomainFqdn]) {
        return $script:domainMapping.FQDN[$DomainFqdn]
    }
    if ($DomainName -and $script:domainMapping.Name[$DomainName]) {
        return $script:domainMapping.Name[$DomainName]
    }

    throw "No matching domain found! ($DomainSid | $DomainFqdn | $DomainName)"
}