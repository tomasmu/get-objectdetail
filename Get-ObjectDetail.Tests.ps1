#by: tomasmu
#date: 2019-01-05

. ($PSCommandPath -replace '\.Tests\.ps1', '.ps1')
#Remove-Module GetObjectDetail
#Import-Module GetObjectDetail

#helper function for output comparison and creating test arrays
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
    Context 'Given an IEnumerable (array/hashtable/list)' {
        It 'Returns True' {
            IsEnumerable @() | Should Be $true
            IsEnumerable @{} | Should Be $true
            IsEnumerable ([System.Collections.Generic.List[int]]::new()) | Should Be $true
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

Describe 'EndsWithPropertyCycle' {
    #$x.prop.a.a.a.a     Count 4
    #$x.prop.a.b.a.b.a.b Count 3
    #$x.prop.a.b.a       Count 1 (uninteresting, repeated once in a row = a property exists)
    Context 'Given a property cycle of length 1, and -Count 2' {
        It 'Returns True if cycle occurs 2 times in the end' {
            $cycleLength1 = '.a'
            EndsWithPropertyCycle -Count 2 -Text "`$x.prop$p$p"     | Should Be $true
            EndsWithPropertyCycle -Count 2 -Text "`$x.prop$p$p$p$p" | Should Be $true

            EndsWithPropertyCycle -Count 2 -Text "`$x.prop$p"       | Should Be $false
        }
    }

    Context 'Given a property cycle of length 3, and -Count 4' {
        It 'Returns True if cycle occurs 4 times in the end' {
            $cycleLength3 = '.a.b.c'
            EndsWithPropertyCycle -Count 4 -Text "`$x.prop$p$p$p$p"     | Should Be $true
            EndsWithPropertyCycle -Count 4 -Text "`$x.prop$p$p$p$p$p$p" | Should Be $true

            EndsWithPropertyCycle -Count 4 -Text "`$x.prop$p$p$p"       | Should Be $false
        }
    }

    Context 'Given no ending property cycle' {
        It 'Returns False' {
            EndsWithPropertyCycle -Count 2 -Text "`$x.prop.a.b.a" | Should Be $false
            EndsWithPropertyCycle -Count 2 -Text "`$x.prop.a.a.b" | Should Be $false
            EndsWithPropertyCycle -Count 2 -Text "`$x.prop.a.b.c" | Should Be $false
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
        It 'Outputs the custom value' {
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
    #todo: test columns separately with | select Col to make tests less brittle?
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

    Context 'Given complex object (date)' {
        It 'Shows (...) as object value since its content will be expanded later' {
            $object = Get-Date
            $expected = @(
                '"$x","(...)","DateTime"'
            )

            Get-ObjectDetail -InputObject $object -MaxDepth 0 | ConvertToCsvRow | Should Be $expected
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

    Context 'Given object with duplicates' {
        It 'Marks duplicate complex types as (Duplicate), but not duplicate value types' {
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

    Context 'Given dictionary with mixed content' {
        It 'Just works' {
            $object = [ordered]@{
                hello = 13
                37 = "world!"
                yarr = @([char]'y', 'arr')
                someday = Get-Date 636823000000000000
            }
            $expected = @(
                '"$x","(...)","OrderedDictionary"'
                '"$x[''hello'']","13","Int32"'
                '"$x[''37'']","world!","String"'
                '"$x[''37''].Length","6","Int32"'
                '"$x[''yarr'']","(...)","Object[]"'
                '"$x[''yarr''][0]","y","Char"'
                '"$x[''yarr''][1]","arr","String"'
                '"$x[''yarr''][1].Length","3","Int32"'
                '"$x[''yarr''].Count","2","Int32"'
                '"$x[''yarr''].Length","2","Int32"'
                '"$x[''yarr''].LongLength","2","Int64"'
                '"$x[''yarr''].Rank","1","Int32"'
                '"$x[''yarr''].SyncRoot","(Duplicate)","Object[]"'
                '"$x[''yarr''].IsReadOnly","False","Boolean"'
                '"$x[''yarr''].IsFixedSize","True","Boolean"'
                '"$x[''yarr''].IsSynchronized","False","Boolean"'
                '"$x[''someday'']","(...)","DateTime"'
                '"$x[''someday''].DisplayHint","DateTime","DisplayHintType"'
                '"$x[''someday''].DisplayHint.value__","2","Int32"'
                '"$x[''someday''].DateTime","den 5 januari 2019 15:46:40","String"'
                '"$x[''someday''].DateTime.Length","27","Int32"'
                '"$x[''someday''].Date","(...)","DateTime"'
                '"$x[''someday''].Date.DateTime","den 5 januari 2019 00:00:00","String"'
                '"$x[''someday''].Date.DateTime.Length","27","Int32"'
                '"$x[''someday''].Date.Date","(Duplicate)","DateTime"'
                '"$x[''someday''].Date.Day","5","Int32"'
                '"$x[''someday''].Date.DayOfWeek","Saturday","DayOfWeek"'
                '"$x[''someday''].Date.DayOfWeek.value__","6","Int32"'
                '"$x[''someday''].Date.DayOfYear","5","Int32"'
                '"$x[''someday''].Date.Hour","0","Int32"'
                '"$x[''someday''].Date.Kind","Unspecified","DateTimeKind"'
                '"$x[''someday''].Date.Kind.value__","0","Int32"'
                '"$x[''someday''].Date.Millisecond","0","Int32"'
                '"$x[''someday''].Date.Minute","0","Int32"'
                '"$x[''someday''].Date.Month","1","Int32"'
                '"$x[''someday''].Date.Second","0","Int32"'
                '"$x[''someday''].Date.Ticks","636822432000000000","Int64"'
                '"$x[''someday''].Date.TimeOfDay","(...)","TimeSpan"'
                '"$x[''someday''].Date.TimeOfDay.Ticks","0","Int64"'
                '"$x[''someday''].Date.TimeOfDay.Days","0","Int32"'
                '"$x[''someday''].Date.TimeOfDay.Hours","0","Int32"'
                '"$x[''someday''].Date.TimeOfDay.Milliseconds","0","Int32"'
                '"$x[''someday''].Date.TimeOfDay.Minutes","0","Int32"'
                '"$x[''someday''].Date.TimeOfDay.Seconds","0","Int32"'
                '"$x[''someday''].Date.TimeOfDay.TotalDays","0","Double"'
                '"$x[''someday''].Date.TimeOfDay.TotalHours","0","Double"'
                '"$x[''someday''].Date.TimeOfDay.TotalMilliseconds","0","Double"'
                '"$x[''someday''].Date.TimeOfDay.TotalMinutes","0","Double"'
                '"$x[''someday''].Date.TimeOfDay.TotalSeconds","0","Double"'
                '"$x[''someday''].Date.Year","2019","Int32"'
                '"$x[''someday''].Day","5","Int32"'
                '"$x[''someday''].DayOfWeek","Saturday","DayOfWeek"'
                '"$x[''someday''].DayOfWeek.value__","6","Int32"'
                '"$x[''someday''].DayOfYear","5","Int32"'
                '"$x[''someday''].Hour","15","Int32"'
                '"$x[''someday''].Kind","Unspecified","DateTimeKind"'
                '"$x[''someday''].Kind.value__","0","Int32"'
                '"$x[''someday''].Millisecond","0","Int32"'
                '"$x[''someday''].Minute","46","Int32"'
                '"$x[''someday''].Month","1","Int32"'
                '"$x[''someday''].Second","40","Int32"'
                '"$x[''someday''].Ticks","636823000000000000","Int64"'
                '"$x[''someday''].TimeOfDay","(...)","TimeSpan"'
                '"$x[''someday''].TimeOfDay.Ticks","568000000000","Int64"'
                '"$x[''someday''].TimeOfDay.Days","0","Int32"'
                '"$x[''someday''].TimeOfDay.Hours","15","Int32"'
                '"$x[''someday''].TimeOfDay.Milliseconds","0","Int32"'
                '"$x[''someday''].TimeOfDay.Minutes","46","Int32"'
                '"$x[''someday''].TimeOfDay.Seconds","40","Int32"'
                '"$x[''someday''].TimeOfDay.TotalDays","0.657407407407407","Double"'
                '"$x[''someday''].TimeOfDay.TotalHours","15.7777777777778","Double"'
                '"$x[''someday''].TimeOfDay.TotalMilliseconds","56800000","Double"'
                '"$x[''someday''].TimeOfDay.TotalMinutes","946.666666666667","Double"'
                '"$x[''someday''].TimeOfDay.TotalSeconds","56800","Double"'
                '"$x[''someday''].Year","2019","Int32"'
                '"$x.Count","4","Int32"'
                '"$x.IsReadOnly","False","Boolean"'
                '"$x.Keys","(...)","OrderedDictionaryKeyValueCollection"'
                '"$x.Keys (0)","hello","String"'
                '"$x.Keys (0).Length","5","Int32"'
                '"$x.Keys (1)","37","Int32"'
                '"$x.Keys (2)","yarr","String"'
                '"$x.Keys (2).Length","4","Int32"'
                '"$x.Keys (3)","someday","String"'
                '"$x.Keys (3).Length","7","Int32"'
                '"$x.Keys.Count","4","Int32"'
                '"$x.Keys.SyncRoot","(...)","Object"'
                '"$x.Keys.IsSynchronized","False","Boolean"'
                '"$x.Values","(...)","OrderedDictionaryKeyValueCollection"'
                '"$x.Values (0)","13","Int32"'
                '"$x.Values (1)","world!","String"'
                '"$x.Values (1).Length","6","Int32"'
                '"$x.Values (2)","(Duplicate)","Object[]"'
                '"$x.Values (3)","(Duplicate)","DateTime"'
                '"$x.Values.Count","4","Int32"'
                '"$x.Values.SyncRoot","(Duplicate)","Object"'
                '"$x.Values.IsSynchronized","False","Boolean"'
                '"$x.IsFixedSize","False","Boolean"'
                '"$x.SyncRoot","(...)","Object"'
                '"$x.IsSynchronized","False","Boolean"'
            )

            Get-ObjectDetail -InputObject $object | ConvertToCsvRow | Should Be $expected
        }
    }
}
