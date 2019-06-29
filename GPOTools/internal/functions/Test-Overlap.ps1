function Test-Overlap
{
<#
	.SYNOPSIS
		Matches N:N mappings for congruence.
	
	.DESCRIPTION
		Matches N:N mappings for congruence.
		Use this for comparing two arrays for overlap.
		This can be used for scenarios such as:
		- Whether n Items in Array One are equal to an Item in Array Two.
		- Whether n Items in Array One are similar to an Item in Array Two.
		This is especially designed to abstract filtering by multiple wildcard filters.
	
	.PARAMETER ReferenceObject
		The object(s) to compare
	
	.PARAMETER DifferenceObject
		The array of items to compare them to.
	
	.PARAMETER Property
		Compare a property, rather than the basic object.
	
	.PARAMETER Count
		The number of congruent items required for a successful result.
		Defaults to 1.
	
	.PARAMETER Operator
		How the comparison should be performed.
		Defaults to 'Equal'
		Supported Comparisons: Equal, Like, Match
	
	.EXAMPLE
		PS C:\> Test-Overlap -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject
	
		Tests whether any item in the two arrays are equal.
#>
	[OutputType([System.Boolean])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		$ReferenceObject,
		
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		$DifferenceObject,
		
		[string]
		$Property,
		
		[int]
		$Count = 1,
		
		[ValidateSet('Equal', 'Like', 'Match')]
		[string]
		$Operator = 'Equal'
	)
	
	begin
	{
		$parameter = @{
			IncludeEqual = $true
			ExcludeDifferent = $true
		}
		if ($Property) { $parameter['Property'] = $Property }
	}
	process
	{
		switch ($Operator)
		{
			'Equal'
			{
				return (Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DebugPreference @parameter | Measure-Object).Count -ge $Count
			}
			'Like'
			{
				$numberFound = 0
				foreach ($reference in $ReferenceObject)
				{
					foreach ($difference in $DifferenceObject)
					{
						if ($Property -and ($reference.$Property -like $difference.$Property)) { $numberFound++ }
						elseif (-not $Property -and ($reference -like $difference)) { $numberFound++ }
						
						if ($numberFound -ge $Count) { return $true }
					}
				}
				
				return $false
			}
			'Match'
			{
				$numberFound = 0
				foreach ($reference in $ReferenceObject)
				{
					foreach ($difference in $DifferenceObject)
					{
						if ($Property -and ($reference.$Property -match $difference.$Property)) { $numberFound++ }
						elseif (-not $Property -and ($reference -match $difference)) { $numberFound++ }
						
						if ($numberFound -ge $Count) { return $true }
					}
				}
				
				return $false
			}
		}
	}
}
