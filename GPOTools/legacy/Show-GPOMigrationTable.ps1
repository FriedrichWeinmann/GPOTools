Function Show-GPOMigrationTable {
Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $Path # Path for migration table
)
    $gpm = New-Object -ComObject GPMgmt.GPM
    $mt = $gpm.GetMigrationTable($Path)

    # http://technet.microsoft.com/en-us/library/cc739066(v=WS.10).aspx
    # $Constants = $gpm.getConstants()
    $mt.GetEntries() |
        Select-Object Source, `
        @{name='DestOption';expression={
            Switch ($_.DestinationOption) {
                0 {'SameAsSource'; break}
                1 {'None'; break}
                2 {'ByRelativeName'; break}
                3 {'Set'; break}
            }
        }}, `
        @{name='Type';expression={
            Switch ($_.EntryType) {
                0 {'User'; break}
                1 {'Computer'; break}
                2 {'LocalGroup'; break}
                3 {'GlobalGroup'; break}
                4 {'UniversalGroup'; break}
                5 {'UNCPath'; break}
                6 {'Unknown'; break}
            }
        }},
        Destination
}
