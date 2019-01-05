# Get-ObjectDetail

A function for exploring PowerShell objects, showing all values, array/dictionary contents, properties, etc.

By: tomasmu (2019-01-05)


Quick tour:

NAME
    Get-ObjectDetail

SYNTAX
    Get-ObjectDetail [[-InputObject] \<Object>] [[-Name] \<string>] [[-MaxDepth] \<int>] [[-ExcludeProperty] \<string[]>]  [\<CommonParameters>]

ALIASES
    god

A quick example output:
<pre>
PS C:\> $x = [ordered]@{
    hello = 13
    37 = "world!"
    yarr = @([char]'y', 'arr')
    guid = New-Guid
}
PS C:\> $x | Get-ObjectDetail

Name                   Value          Type              Comment
----                   -----          ----              ------
$x                     (...)          OrderedDictionary #exploring an ordered dictionary, non-value types get (...) as placeholder here
                                                        #the -Name parameter is the '$x' in the Name column (defaults to '$x')

$x['hello']            13             Int32             #first is an int, not much of interest here really

$x['37']               world!         String            #strings has one property
$x['37'].Length        6              Int32             #showing values/elements/key-value pairs at the top, properties at the bottom

$x['yarr']             (...)          Object[]          #array object @('y', 'arr')
$x['yarr'][0]          y              Char              #first element
$x['yarr'][1]          arr            String            #second..
$x['yarr'][1].Length   3              Int32
$x['yarr'].Count       2              Int32             #array properties last
$x['yarr'].Length      2              Int32
$x['yarr'].SyncRoot    (Duplicate)    Object[]          #this is $x['yarr'], which we have seen before (same HashCode), duplicates are shown but not explored further
$x['yarr'].IsReadOnly  False          Boolean

$x['guid']             (...)          Guid              #guid with nested properties
$x['guid'].Guid        ca47a913-0...  String
$x['guid'].Guid.Length 36             Int32             #this is depth 3 (0: $x, 1: ['guid'], 2: .Guid, 3: .Length)
                                                        #with '-MaxDepth 2' Length would be excluded


$x.Count               4              Int32             #dictionary properties below its key-value pairs
$x.Keys                (...)          OrderedDictionaryKeyValueCollection #non-indexable collections..
$x.Keys (0)            hello          String            #are being numbered with a pseudo-index, the index they would have had (N)
$x.Keys (0).Length     5              Int32             #values can be retrieved with ($x.Keys | select -Index N)
$x.Keys (1)            37             Int32
$x.Keys (2)            yarr           String
$x.Values              (...)          OrderedDictionaryKeyValueCollection
$x.Values (0)          13             Int32             #with '-ExcludeProperty Values' you can exclude this property by its name
</pre>
