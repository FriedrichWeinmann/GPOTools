function New-ImportResult
{
<#
	.SYNOPSIS
		Create unified import result objects.
	
	.DESCRIPTION
		Create unified import result objects.
	
	.PARAMETER Action
		The action taken.
	
	.PARAMETER Step
		The current step of the action.
	
	.PARAMETER Target
		The target of the step.
	
	.PARAMETER Success
		Whether the action was a success.
	
	.PARAMETER Data
		Any data to add to the report
	
	.PARAMETER ErrorData
		Any error data to add to the report
	
	.EXAMPLE
		PS C:\> New-ImportResult -Action 'Importing Policy Objects' -Step 'Import Object' -Target $gpoEntry -Success $true -Data $gpoEntry, $migrationTablePath
	
		Creates a new object representing a successful GPO import.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Action,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Step,
		
		$Target,
		
		[Parameter(Mandatory = $true)]
		[bool]
		$Success,
		
		$Data,
		
		$ErrorData
	)
	
	[pscustomobject]@{
		PSTypeName = 'GPOTools.ImportResult'
		Action	   = $Action
		Step	   = $Step
		Target	   = $Target
		Success    = $Success
		Data	   = $Data
		Error	   = $ErrorData
	}
}