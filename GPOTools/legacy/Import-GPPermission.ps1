Function Import-GPPermission {
Param (
    [Parameter(Mandatory=$true)]
    [String]
    $DestDomain,
    [Parameter(Mandatory=$true)]
    [String]
    $DestServer,
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [String[]]
    $DisplayName,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $MigTablePath
)
    $MigTable = Show-GPOMigrationTable -Path $MigTablePath |
        Select-Object *, `
            @{name='SourceName';expression={($_.Source -split '@')[0]}}, `
            @{name='SourceDomain';expression={($_.Source -split '@')[1]}}, `
            @{name='DestinationName';expression={($_.Destination -split '@')[0]}}, `
            @{name='DestinationDomain';expression={($_.Destination -split '@')[1]}}

    $GPO_ACEs_CSV = Import-Csv $Path |
        Select-Object *, `
            @{name='IDName';expression={($_.IdentityReference -split '\\')[-1]}}, `
            @{name='IDDomain';expression={($_.IdentityReference -split '\\')[0]}}

    <#
    Show-GPOMigrationTable -Path $MigTablePath | ft -auto

    Source                              DestOption   Type           Destination                       
    ------                              ----------   ----           -----------                       
    Administrators                      SameAsSource Unknown                                          
    Domain Admins@wingtiptoys.local     Set          GlobalGroup    Domain Admins@cohovineyard.com    
    fsogroup@wingtiptoys.local          Set          GlobalGroup    fsogroup@cohovineyard.com         
    Enterprise Admins@wingtiptoys.local Set          UniversalGroup Enterprise Admins@cohovineyard.com
    joebobtoo@wingtiptoys.local         Set          User           joebobtoo@cohovineyard.com        
    anlan@wingtiptoys.local             Set          User           anlan@cohovineyard.com            
    fsouser@wingtiptoys.local           Set          User           fsouser@cohovineyard.com          
    anhill@wingtiptoys.local            Set          User           anhill@cohovineyard.com           
    joebobfoo@wingtiptoys.local         Set          User           joebobfoo@cohovineyard.com 

    Selected and split...
    
    MigTable
    
    Source            : joebobfoo@wingtiptoys.local
    DestOption        : Set
    Type              : User
    Destination       : joebobfoo@cohovineyard.com
    SourceName        : joebobfoo
    SourceDomain      : wingtiptoys.local
    DestinationName   : joebobfoo
    DestinationDomain : cohovineyard.com       

    ACLs

    Name                  : Starter Computer
    Path                  : cn={FC18876F-2975-4638-B8DE-D83AB4415A51},cn=policies,c
                            n=system,DC=wingtiptoys,DC=local
    ActiveDirectoryRights : CreateChild, DeleteChild, Self, WriteProperty, DeleteTr
                            ee, Delete, GenericRead, WriteDacl, WriteOwner
    InheritanceType       : All
    ObjectType            : 00000000-0000-0000-0000-000000000000
    InheritedObjectType   : 00000000-0000-0000-0000-000000000000
    ObjectFlags           : None
    AccessControlType     : Allow
    IdentityReference     : WINGTIPTOYS\Enterprise Admins
    IsInherited           : False
    InheritanceFlags      : ContainerInherit
    PropagationFlags      : None
    IDName              * : Enterprise Admins
    IDDomain            * : WINGTIPTOYS
    #>
    ForEach ($Name in $DisplayName) {

        "Importing GPO Permissions: $Name"
        
        $GPO = Get-GPO -Domain $DestDomain -Server $DestServer -DisplayName $Name

        ForEach ($ACE in ($GPO_ACEs_CSV | Where-Object {$_.Name -eq $Name})) {

            Write-Host "Setting GPO permission: '$($ACE.IDName)' on '$Name'"    

            # Find the CSV ACE identity name in the MigTable
            # Possible zero or one matches, should not be multiple
            $MigID = $MigTable | Where-Object {$_.SourceName -eq $ACE.IDName}
            
            # If entry, then attempt to set it
            If ($MigID) {
                # Find the AD object based on the type listed in the MigTable
                $ADObject = $null

                Try {
                    Switch ($MigID.Type) {
                        'Unkown'          {$ADObject = $null; break}
                        'User'            {$ADObject = Get-ADUser -Identity $MigID.DestinationName -Server $MigID.DestinationDomain; break}
                        'Computer'        {$ADObject = Get-ADComputer -Identity $ACE.IDName -Server $DestDomain; <# Special handling #>; break}
                        'GlobalGroup'     {$ADObject = Get-ADGroup -Identity $MigID.DestinationName -Server $MigID.DestinationDomain; break}
                        'LocalGroup'      {$ADObject = Get-ADGroup -Identity $MigID.DestinationName -Server $MigID.DestinationDomain; break}
                        'UniversalGroup'  {$ADObject = Get-ADGroup -Identity $MigID.DestinationName -Server "$($MigID.DestinationDomain):3268"; break}
                        Default           {$ADObject = $null; break}
                    }
                }
                Catch {
                    # AD object not found. Warning written below.
                }
                
                # If we found the object, then attempt to set the permission.
                If ($ADObject) {

                    "Found ADObject $($ADObject.Name). Writing permission."
                    # Same effect as using Get-ACL "AD:\..."
                    $acl = $GPO | Select-Object -ExpandProperty Path | Get-ADObject -Properties NTSecurityDescriptor | Select-Object -ExpandProperty NTSecurityDescriptor
                    
                    $ObjectType = [GUID]$($ACE.ObjectType)
                    $InheritedObjectType = [GUID]$($ACE.InheritedObjectType)
                    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                        $ADObject.SID, $ACE.ActiveDirectoryRights, $ACE.AccessControlType, $ObjectType, `
                        $ACE.InheritanceType, $InheritedObjectType
                    $acl.AddAccessRule($ace)
                    
                    # Commit the ACL
                    Set-Acl -Path "AD:\$($GPO.Path)" -AclObject $acl
                
                } Else {
                # Else, Log failure to find security principal
                    Write-Warning "ADObject not found.  ACE not set: '$($ACE.IDName)' on '$Name'"    
                }
                
            } Else {
            # Else, attempt to set without migration table translation (ie. CREATOR OWNER, etc.)

                "Setting ACE without migration table translation: '$($ACE.IDName)' on '$Name'"

                $sid = $null
                Try {
                    $sid = (New-Object System.Security.Principal.NTAccount($ACE.IDName)).Translate([System.Security.Principal.SecurityIdentifier])
                }
                Catch {
                    Write-Warning "Error.  Cannot set: '$($ACE.IDName)' on '$Name'"
                }
                
                If ($sid) {
                
                    # Same effect as using Get-ACL "AD:\..."
                    $acl = $GPO | Select-Object -ExpandProperty Path | Get-ADObject -Properties NTSecurityDescriptor | Select-Object -ExpandProperty NTSecurityDescriptor

                    $ObjectType = [GUID]$($ACE.ObjectType)
                    $InheritedObjectType = [GUID]$($ACE.InheritedObjectType)
                    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                        $sid, $ACE.ActiveDirectoryRights, $ACE.AccessControlType, $ObjectType, `
                        $ACE.InheritanceType, $InheritedObjectType
                    $acl.AddAccessRule($ace)
                    
                    # Commit the ACL
                    Set-Acl -Path "AD:\$($GPO.Path)" -AclObject $acl
                }

            }
<#
            # This is how you would set permissions using the GPO cmdlets.
            # However, they do not support DENY permissions. Not cool.
                        
            If ($ACE.'Trustee-SidType' -eq 'WellKnownGroup') {
                $ACE.'Trustee-SidType' = 'Group'
            }

            Try {
                Set-GPPermissions                                                                                     `
                    -Name            $GPMBackup.GPODisplayName                                                        `
                    -PermissionLevel $([Microsoft.GroupPolicy.GPPermissionType]$ACE.Permission)                       `
                    -TargetName      $ACE.'Trustee-Name'                                                              `
                    -TargetType      $([Microsoft.GroupPolicy.Commands.PermissionTrusteeType]$ACE.'Trustee-SidType')  `
                    -Domain          $DestDomain                                                                      `
                    -Server          $DestServer                                                                      `
                    -Replace |
                Out-Null
            }
            Catch {
                Write-Warning "Unable to set the following GP permission: '$($ACE.'Trustee-Name')' on '$($GPMBackup.GPODisplayName)'`n$ACE`n$($_.Exception)"
            }
#>

""
        } # End ForEach ACE
        # Force the ACL changes to SYSVOL
        $GPO.MakeAclConsistent()
    } # End ForEach DisplayName
}
