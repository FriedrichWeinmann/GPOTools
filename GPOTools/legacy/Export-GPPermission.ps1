function Export-GPPermission
{
	param (
		[Parameter(Mandatory = $true,
				   ParameterSetName = "All")]
		[Switch]
		$All,
		
		# Backup all GPOs

		
		[Parameter(Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ParameterSetName = "DisplayName")]
		[String[]]
		$DisplayName,
		
		# Array of GPO DisplayNames to backup

		
		[Parameter(Mandatory = $true)]
		[String]
		$SrceDomain,
		
		[Parameter(Mandatory = $true)]
		[String]
		$SrceServer,
		
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[String]
		$Path
	)
	
	begin
	{
		$select_Name = @{ name = 'Name'; expression = { $Name } }
		$select_Path = @{ name = 'Path'; expression = { $GPO.Path } }
	}
	process
	{
		$GPO_ACEs = @()
		
		if ($All)
		{
			$DisplayName = (Get-GPO -Server $SrceServer -Domain $SrceDomain -All).DisplayName
		}
		
		foreach ($Name in $DisplayName)
		{
			$GPO = Get-GPO -Server $SrceServer -Domain $SrceDomain -Name $Name
			# Using the NTSecurityDescriptor attribute instead of calling Get-ACL
			$ACL = (Get-ADObject -Identity $GPO.Path -Properties NTSecurityDescriptor |
				Select-Object -ExpandProperty NTSecurityDescriptor).Access
			
			$GPO_ACEs += $ACL | Select-Object $select_Name, $select_Path, '*'
		}
		
		$GPO_ACEs | Export-CSV (Join-Path $Path GPPermissions.csv) -NoTypeInformation
	}
}
