function Enable-ADSystemOnlyChange
{
	param ([switch]
		$Disable)
	
	Write-Warning @'
This command must run locally on the domain controller where the
GPOs will be imported. You only need to execute this function if WMI filter
creation via script has failed. If you continue, the process will finish with
either restarting the NTDS service or rebooting the server.
'@
	if ((Read-Host "Continue? (y/n)") -ne 'y')
	{
		return
	}
	else
	{
		# Set the registry value
		$valueData = 1
		if ($Disable)
		{
			$valueData = 0
		}
		
		$key = Get-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -ErrorAction SilentlyContinue
		if (!$key)
		{
			New-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -ItemType RegistryKey | Out-Null
		}
		
		$kval = Get-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -Name "Allow System Only Change" -ErrorAction SilentlyContinue
		if (!$kval)
		{
			New-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -Name "Allow System Only Change" -Value $valueData -PropertyType DWORD | Out-Null
		}
		else
		{
			Set-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -Name "Allow System Only Change" -Value $valueData | Out-Null
		}
		
		# Restart the NTDS service. Use a reboot on older OS where the service does not exist.
		if (Get-Service NTDS -ErrorAction SilentlyContinue)
		{
			Write-Warning "You must restart the Directory Service to coninue..."
			Restart-Service NTDS -Confirm:$true
		}
		else
		{
			Write-Warning "You must reboot the server to continue..."
			Restart-Computer localhost -Confirm:$true
		}
		
	} # End If
}
