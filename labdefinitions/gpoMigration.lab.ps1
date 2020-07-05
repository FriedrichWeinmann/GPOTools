$labname = 'GPOMigration'
$labSources = 'C:\LabSources'
$imageUI = 'Windows Server 2019 Datacenter (Desktop Experience)'
$imageNoUI = 'Windows Server 2019 Datacenter'

$forest1 = 'contoso.com'
$forest1_subdomain = 'country.contoso.com'
$forest2 = 'fabrikam.com'
$forest2_subdomain = 'department.fabrikam.com'

#region Utility Functions
function New-LabChildDomain
{
	[CmdletBinding()]
	param (
		[string]
		$ComputerName,
		
		[string]
		$DnsServer,
		
		[string]
		$ParentForest,
		
		[string]
		$DomainName
	)
	
	Set-LabDnsServer -ClientVMName $ComputerName -ServerVMName $DnsServer
	Invoke-LabCommand -ActivityName "Creating Child Domain: $($DomainName) on $($ComputerName)" -ComputerName $ComputerName -ScriptBlock {
		param (
			$ParentForest,
			
			$DomainName
		)
		$paramInstallADDSDomain = @{
			CreateDnsDelegation		      = $true
			ParentDomainName			  = $ParentForest
			InstallDns				      = $true
			Force						  = $true
			SafeModeAdministratorPassword = ("Test1234" | ConvertTo-SecureString -AsPlainText -Force)
			Credential				      = (New-Object PSCredential("$($ParentForest.Split(".")[0])\Administrator", ("Somepass1" | ConvertTo-SecureString -AsPlainText -Force)))
			SkipPreChecks				  = $true
			NewDomainName				  = $DomainName
		}
		
		Install-ADDSDomain @paramInstallADDSDomain
	} -ArgumentList $ParentForest, $DomainName
}

function Set-LabDnsServer
{
	[CmdletBinding()]
	param (
		[string[]]
		$ClientVMName,
		
		[string]
		$ServerVMName
	)
	
	$serverIP = (Get-LabVM -ComputerName $ServerVMName).IpV4Address
	
	Invoke-LabCommand -ActivityName "Configuring DNS Server to: $($ServerVMName) ($($serverIP)) on $($ClientVMName)" -ComputerName $ClientVMName -ScriptBlock {
		param (
			$DnsServer
		)
		$mainInterface = (Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias Ethernet).ifIndex
		Set-DnsClientServerAddress -InterfaceIndex $mainInterface -ServerAddresses $DnsServer
	} -ArgumentList $serverIP
}

function New-LabADTrust
{
	[CmdletBinding()]
	param (
		[string[]]
		$ComputerName,
		
		[string]
		$RemoteForest,
		
		[ValidateSet('Bidirectional', 'Outbound', 'Inbound')]
		[string]
		$Direction = 'Bidirectional'
	)
	
	Invoke-LabCommand -ActivityName "Creating Forest Trust" -ComputerName $ComputerName -ScriptBlock {
		param (
			$RemoteForest,
			
			$Direction
		)
		$remoteContext = New-Object -TypeName "System.DirectoryServices.ActiveDirectory.DirectoryContext" -ArgumentList @("Forest", $RemoteForest, "Administrator", "Somepass1")
		$RemoteForest = [System.DirectoryServices.ActiveDirectory.Forest]::getForest($remoteContext)
		$localforest = [System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()
		$localForest.CreateTrustRelationship($RemoteForest, $Direction)
	} -ArgumentList $RemoteForest, $Direction
}

function Add-LabDNSForwarder
{
	[CmdletBinding()]
	param (
		[string[]]
		$ComputerName,
		
		[string]
		$ServerVMName
	)
	
	$serverIP = (Get-LabVM -ComputerName $ServerVMName).IpV4Address
	
	Invoke-LabCommand -ActivityName "Adding DNS Forwarder to: $($ServerVMName) ($($serverIP)) on $($ComputerName)" -ComputerName $ComputerName -ScriptBlock {
		param (
			$DnsServer
		)
		
		Add-DnsServerForwarder -IPAddress $DnsServer
	} -ArgumentList $serverIP
}
#endregion Utility Functions

New-LabDefinition -Name $labname -DefaultVirtualizationEngine HyperV

$parameters = @{
	Memory		    = 2GB
	OperatingSystem = $imageUI
}

Add-LabMachineDefinition -Name LabGPDCF1 -DomainName $forest1 -Roles RootDC @parameters
Add-LabMachineDefinition -Name LabGPDCF2 -DomainName $forest2 -Roles RootDC @parameters
Add-LabMachineDefinition -Name LabGPDCF1SD @parameters
Add-LabMachineDefinition -Name LabGPDCF2SD @parameters

Install-Lab
Install-LabWindowsFeature -ComputerName LabGPDCF1SD, LabGPDCF2SD -FeatureName AD-Domain-Services -IncludeManagementTools

New-LabChildDomain -ComputerName LabGPDCF1SD -DnsServer LabGPDCF1 -ParentForest $forest1 -DomainName $forest1_subdomain.Split(".")[0]
New-LabChildDomain -ComputerName LabGPDCF2SD -DnsServer LabGPDCF2 -ParentForest $forest2 -DomainName $forest2_subdomain.Split(".")[0]

Restart-LabVM -ComputerName (Get-LabVM)
Start-Sleep -Seconds 120

Invoke-LabCommand -ActivityName 'Setting Up AD Structure' -ComputerName LabGPDCF1SD, LabGPDCF2SD -ScriptBlock {
	$domain = Get-ADDomain
	
	# OU Structure
	$baseOU = New-ADOrganizationalUnit -Path $domain.DistinguishedName -Name Company -PassThru
	$serversOU = New-ADOrganizationalUnit -Path $baseOU -Name Servers -PassThru
	$usersOU = New-ADOrganizationalUnit -Path $baseOU -Name Users -PassThru
	$groupsOU = New-ADOrganizationalUnit -Path $baseOU -Name Groups -PassThru
	$clientsOU = New-ADOrganizationalUnit -Path $baseOU -Name Clients -PassThru
	$serviceAccountsOU = New-ADOrganizationalUnit -Path $baseOU -Name ServiceAccounts -PassThru
	
	# User Accounts
	$param = @{
		Enabled		    = $true
		PassThru	    = $true
		AccountPassword = "Test1234" | ConvertTo-SecureString -AsPlainText -Force
		Path		    = $usersOU
	}
	$userMax = New-ADUser @param -Name mm -GivenName Max -Surname Mustermann
	$userMaria = New-ADUser @param -Name ma -GivenName Maria -Surname Musterfrau
	$userAria = New-ADUser @param -Name am -GivenName Aria -Surname Musterfrau
	
	# Groups
	$param = @{
		PassThru   = $true
		Path	   = $groupsOU
		GroupScope = 'Global'
	}
	$groupMaintal = New-ADGroup @param -Name Maintal
	$groupLothringen = New-ADGroup @param -Name Lothringen
	$groupPreussen = New-ADGroup @param -Name Preussen
	
	# Group Memberships
	Add-ADGroupMember -Identity $groupMaintal -Members $userMax, $userMaria
	Add-ADGroupMember -Identity $groupLothringen -Members $userAria
	Add-ADGroupMember -Identity $groupPreussen -Members $groupMaintal,$userAria
}

Invoke-LabCommand -ActivityName "Setting Keyboard Layout" -ComputerName (Get-LabVM).Name -ScriptBlock { Set-WinUserLanguageList -LanguageList 'de-de' -Confirm:$false -Force }
Restart-LabVM -ComputerName (Get-LabVM).Name