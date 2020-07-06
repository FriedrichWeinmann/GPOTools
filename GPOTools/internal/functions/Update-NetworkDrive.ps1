function Update-NetworkDrive
{
<#
	.SYNOPSIS
		Remaps mapped network drives if needed.
	
	.DESCRIPTION
		Remaps mapped network drives if needed.
		Performs no operation, if no network drives are mapped on a GPO.
		Migration tables do not correctly update mapped drives, unfoortunately.
	
		Requires valid source data to be already imported, for example by running Import-GptDomainData or Import-GptIdentity.
	
	.PARAMETER GpoName
		Name of the GPO to update.
	
	.PARAMETER Domain
		The destination domain into which the GPO has been imported.
	
	.EXAMPLE
		PS C:\> Update-NetworkDrive -GpoName 'Share Y:' -Domain 'contoso.com'
	
		Updates the GPO "Share Y:" for the domain contoso.com, remapping the share from the source domain to the destination domain.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$GpoName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Domain
	)
	
	begin
	{
		try
		{
			$gpoObject = Get-GPO -Domain $Domain -Name $GpoName -ErrorAction Stop
			$destinationDomain = (Get-DomainData -Domain $Domain).ADObject
			$gpoADObject = Get-ADObject -Server $destinationDomain.PDCEmulator -Identity $gpoObject.Path -Properties gPCFileSysPath -ErrorAction Stop
		}
		catch { throw }
		
		if ($script:sourceDomainData)
		{
			$sourceDomainDNS = $script:sourceDomainData.DomainDNSName
			$sourceDomainNetBios = $script:sourceDomainData.NetBIOSName
		}
		elseif ($script:identityMapping.Count -gt 0)
		{
			$sourceDomainDNS = $script:identityMapping[0].DomainFqdn
			$sourceDomainNetBios = $script:identityMapping[0].DomainName
		}
		else
		{
			throw "Unable to determine source domain. Run Import-GptDomainData or Import-GptIdentity first!"
		}
	}
	process
	{
		Write-Verbose "$GpoName : Processing Network Shares"
		$driveXmlPath = Join-Path -Path $gpoADObject.gPCFileSysPath -ChildPath 'User\Preferences\Drives\Drives.xml'
		if (-not (Test-Path -Path $driveXmlPath))
		{
			Write-Verbose "$GpoName : Does not contain Network Shares"
			return
		}
		
		try { $driveString = Get-Content -Path $driveXmlPath -Raw -ErrorAction Stop -Encoding UTF8 }
		catch
		{
			Write-Verbose "$GpoName : Could not access Network Shares file"
			return
		}
		
		$driveStringNew = $driveString.Replace("\\$sourceDomainDNS\", "\\$($destinationDomain.DNSRoot)\").Replace("\\$sourceDomainNetBios\", "\\$($destinationDomain.NetBIOSName)\")
		
		if ($driveStringNew -eq $driveString)
		{
			Write-Verbose "$GpoName : Nothing to remap in the defined shares"
			return
		}
		
		try { Set-Content -Value $driveStringNew -Path $driveXmlPath -Encoding UTF8 -ErrorAction Stop }
		catch { throw }
	}
}