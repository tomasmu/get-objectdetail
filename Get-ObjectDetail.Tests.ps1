#by: tomasmu
#date: 2019-01-05

. ($PSCommandPath -replace '\.Tests\.ps1', '.ps1')
#Remove-Module GetObjectDetail
#Import-Module GetObjectDetail

#helper function to make test arrays to compare output with
function ConvertToCsvRow {
    param(
        [parameter(ValueFromPipeline = $true)]$InputObject,
        [switch]$ArraySyntax
    )

    process {
        $InputObject | ForEach-Object {
                [PSCustomObject]@{
                    Name  = $_.Name
                    Value = ($_.Value | ForEach-Object { $_ }) -join ' '
                    Type  = $_.Type
                }
            } |
            ConvertTo-Csv -NoTypeInformation -Delimiter ',' |
            ForEach-Object {
                if ($ArraySyntax) {
                    "'$($_ -replace "'", "''")'"
                }
                else {
                    $_
                }
            } |
            select -Skip 1
    }
}

Describe 'IsEnumerable' {
    #todo: split into separate tests
    Context 'Given an IENumerable (array/hashtable/hashset)' {
        It 'Returns True' {
            IsEnumerable @() | Should Be $true
            IsEnumerable @{} | Should Be $true
            IsEnumerable ([System.Collections.Generic.HashSet[string]]::new()) | Should Be $true
        }
    }

    Context 'Given an enumerable type (string) which we want to treat as a value' {
        It 'Returns False' {
            IsEnumerable "special case" | Should Be $false
        }
    }

    Context 'Given non-enumerable types (null/int/date)' {
        It 'Returns False' {
            IsEnumerable $null | Should Be $false
            IsEnumerable 42 | Should Be $false
            IsEnumerable (Get-Date) | Should Be $false
        }
    }
}

Describe 'IsDictionary' {
    Context 'Given a dictionary (hashtable)' {
        It 'Returns True' {
            IsDictionary @{ a = 42 } | Should Be $true
        }
    }

    Context 'Given a non-dictionary (hashset)' {
        It 'Returns False' {
            IsDictionary ([System.Collections.Generic.HashSet[string]]::new()) | Should Be $false
        }
    }

    #todo: split into separate tests
    Context 'Given a non-dictionary (null/array/int/string)' {
        It 'Returns False' {
            IsDictionary $null | Should Be $false
            IsDictionary @('42') | Should Be $false
            IsDictionary 42 | Should Be $false
            IsDictionary "str" | Should Be $false
        }
    }
}

Describe 'IsSimple' {
    #todo: split into separate tests
    Context "Given a 'simple/value/primitive' type (null/int/string)" {
        It "Returns True" {
            IsSimple $null | Should Be $true
            IsSimple 42 | Should Be $true
            IsSimple "str" | Should Be $true
        }
    }

    Context 'Given complex type (array/hashtable/guid/intarray/timespan)' {
        It 'Returns False' {
            IsSimple @('a', 1) | Should Be $false
            IsSimple @{ 'a' = 1 } | Should Be $false
            IsSimple (New-Guid) | Should Be $false
            IsSimple ([int[]](12, 34)) | Should Be $false
            IsSimple ([timespan]::new(1)) | Should Be $false
        }
    }
}

Describe 'IsIndexable' {
    #todo: split into separate tests
    Context 'Given a type which is indexable with integers (string/array/intArray)' {
        It 'Returns True' {
            IsIndexable "str" | Should Be $true
            IsIndexable @('a', 1) | Should Be $true
            IsIndexable ([int[]](12, 34)) | Should Be $true
        }
    }

    Context 'Given a type that cannot be indexable with integers (null/dictionary/hashset/int)' {
        It 'Returns False' {
            IsIndexable $null | Should Be $false
            IsIndexable @{ 'a' = 1 } | Should Be $false
            IsIndexable ([System.Collections.Generic.HashSet[string]]) | Should Be $false
            IsIndexable 42 | Should Be $false
        }
    }
}

Describe 'WriteObject' {
    Context 'Given an object with value' {
        It 'Outputs the properties we want' {
            $object = @(12, 34)
            $expected = [PSCustomObject]@{
                Name  = "name"
                Value = "12 34"
                Type  = "Object[]"
            } | ConvertToCsvRow
            
            WriteObject -Name "name" -InputObject $object | ConvertToCsvRow | Should Be $expected
        }
    }

    Context 'Given an object and custom value' {
        It 'Outputs the properties we want' {
            $object = @(12, 34)
            $expected = [PSCustomObject]@{
                Name = "name"
                Value = "custom"
                Type = "Object[]"
            } | ConvertToCsvRow
            
            WriteObject -Name "name" -InputObject $object -CustomValue "custom" | ConvertToCsvRow | Should Be $expected
        }
    }
}

Describe 'Get-ObjectDetail' {
    Context 'Given int' {
        It 'Returns expected object' {
            $object = 42
            $expected = @(
                '"$x","42","Int32"'
            )

            Get-ObjectDetail -InputObject $object | ConvertToCsvRow | Should Be $expected
        }
    }

    Context 'Given string' {
        It 'Returns expected object and properties' {
            $object = "this sentence has thirtynine characters"
            $expected = @(
                '"$x","this sentence has thirtynine characters","String"'
                '"$x.Length","39","Int32"'
            )

            Get-ObjectDetail -InputObject $object | ConvertToCsvRow | Should Be $expected
        }
    }

    Context 'Given complex object (guid)' {
        It 'Shows (...) as object value since its content will be expanded later' {
            $object = Get-Date
            $expected = @(
                '"$x","(...)","Guid"'
                '"$x.Guid","0cc4af99-edbc-4813-8106-22971f5f7e75","String"'
                '"$x.Guid.Length","36","Int32"'
            )
        }
    }

    Context 'Given object with duplicates' {
        It 'Marks duplicate complex types as (Duplicate)' {
            $duplicate = [PSObject]@{ Double = 6.283185 }
            $notDuplicate = 42
            $object = [PSCustomObject]@{
                Duplicate1 = $duplicate
                Duplicate2 = $duplicate
                NotDuplicate1 = $notDuplicate
                NotDuplicate2 = $notDuplicate
            }
            $expected = @(
                '"$x","(...)","PSCustomObject"'
                '"$x.Duplicate1","(...)","Hashtable"'
                '"$x.Duplicate2","(Duplicate)","Hashtable"'
                '"$x.NotDuplicate1","42","Int32"'
                '"$x.NotDuplicate2","42","Int32"'
            )

            Get-ObjectDetail -InputObject $object -MaxDepth 1 | ConvertToCsvRow | Should Be $expected
        }
    }

    Context 'Given int array' {
        It 'Returns expected object' {
            $object = [int[]](12, 34)
            $expected = @(
                '"$x","(...)","Int32[]"'
                '"$x[0]","12","Int32"'
                '"$x[1]","34","Int32"'
                '"$x.Count","2","Int32"'
                '"$x.Length","2","Int32"'
                '"$x.LongLength","2","Int64"'
                '"$x.Rank","1","Int32"'
                '"$x.SyncRoot","(Duplicate)","Int32[]"'
                '"$x.IsReadOnly","False","Boolean"'
                '"$x.IsFixedSize","True","Boolean"'
                '"$x.IsSynchronized","False","Boolean"'
            )

            Get-ObjectDetail -InputObject $object | ConvertToCsvRow | Should Be $expected
        }
    }
}
