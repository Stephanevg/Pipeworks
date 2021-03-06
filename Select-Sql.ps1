function Select-SQL
{
    <#
    .Synopsis
        Select SQL data
    .Description
        Select data from a SQL databsae
    .Example
        Select-Sql -FromTable ATable -Property Name, Day, Month, Year -Where "Year = 2005" -ConnectionSetting SqlAzureConnectionString
    .Example
        Select-Sql -FromTable INFORMATION_SCHEMA.TABLES -ConnectionSetting SqlAzureConnectionString -Property Table_Name -verbose
    .Example
        Select-Sql -FromTable INFORMATION_SCHEMA.TABLES -ConnectionSetting "Data Source=$env:ComputerName;Initial Catalog=Master;Integrated Security=SSPI;" -Property Table_Name -verbose
    .Example
        Select-Sql "
    SELECT  sys.objects.name,
            SUM(row_count) AS 'Row Count',
            SUM(reserved_page_count) * 8.0 / 1024 AS 'Table Size (MB)'
    FROM sys.dm_db_partition_stats, sys.objects
    WHERE sys.dm_db_partition_stats.object_id = sys.objects.object_id
    GROUP BY sys.objects.name
    ORDER BY [Table Size (MB)] DESC
"
    .Link
        Add-SqlTable
    .Link
        Update-SQL

    #>
    [CmdletBinding(DefaultParameterSetName='SQLQuery')]
    [OutputType([PSObject], [Hashtable], [Data.DataRow])]
    param(
    # The table containing SQL results
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='SQLQuery')]    
    [Alias('SQL')]
    [string]$Query,


    # The path to a SQL file
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='SQLFile')]    
    [Alias('Fullname')]
    [string]$SqlFile,

    # The table containing SQL results
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [Alias('Table','From', 'TableName')]
    [string]$FromTable,

        # If set, will only return unique values.  This corresponds to the DISTINCT SQL qualifier.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [Alias('Unique')]
    [Switch]$Distinct,

    # The properties to pull from SQL. If not set, all properties (*) will be returned
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [string[]]$Property,

    # The sort order of the returned objects
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [Alias('First')]
    [Uint32]$Top,

    # The sort order of the returned objects
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [Alias('Sort')]
    [string[]]$OrderBy,

    # If set, sorted items will be returned in descending order.  By default, if items are sorted, they will be in ascending order.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [Switch]$Descending,

    # The where clause.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SimpleSQL')]
    [string]$Where,

    # A connection string or setting.    
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting,

    # The name of the SQL server.  This is used with a database name to craft a connection string to SQL server
    [string]
    $Server,

    # The database on a SQL server.  This is used with the server name to craft a connection string to SQL server
    [string]
    $Database,

    # If set, will output the SQL
    [Switch]
    $OutputSql,

    # If set, will use SQL server compact edition    
    [Switch]
    $UseSQLCompact,

    # The path to SQL Compact.  If not provided, SQL compact will be loaded from the GAC    
    [string]
    $SqlCompactPath,    
    

    # If set, will use SQL lite    
    [Alias('UseSqlLite')]
    [switch]
    $UseSQLite,

    # The path to SQLite.  If not provided, SQLite will be loaded from Program Files
    [Alias('SqlLitePath')]
    [string]    
    $SqlitePath,

    # If set, will use MySql to connect to the database    
    [Switch]
    $UseMySql,
    
    # The path to MySql's .NET connector.  If not provided, MySql will be loaded from Program Files        
    [string]    
    $MySqlPath,
    
    
    # The path to a SQL compact or SQL lite database    
    [Alias('DBPath')]
    [string]
    $DatabasePath,

    # The way the data will be outputted.  
    [ValidateSet("Hashtable", "Datatable", "DataSet", "PSObject")]
    [string]
    $AsA = "PSObject",

    # If set, the select statement will be run as a dirty read.  
    # In SQL Server, this will be With (nolock).  
    # In MYSql, this will change the session options for the transaction to enable a dirty read.
    [Switch]
    $Dirty
    )

    begin {
        
        if ($PSBoundParameters.ConnectionStringOrSetting) {
            if ($ConnectionStringOrSetting -notlike "*;*") {
                $ConnectionString = Get-SecureSetting -Name $ConnectionStringOrSetting -ValueOnly
            } else {
                $ConnectionString =  $ConnectionStringOrSetting
            }
            $script:CachedConnectionString = $ConnectionString
        } elseif ($psBoundParameters.Server -and $psBoundParameters.Database) {
            $ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;"
            $script:CachedConnectionString = $ConnectionString
        } elseif ($script:CachedConnectionString){
            $ConnectionString = $script:CachedConnectionString
        } else {
            $ConnectionString = ""
        }
        if (-not $ConnectionString -and -not ($UseSQLite -or $UseSQLCompact)) {
            throw "No Connection String"
            return
        }

        if (-not $OutputSQL) {

            if ($UseSQLCompact) {
                if (-not ('Data.SqlServerCE.SqlCeConnection' -as [type])) {
                    if ($SqlCompactPath) {
                        $resolvedCompactPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($SqlCompactPath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedCompactPath)
                    } else {
                        $asm = [reflection.assembly]::LoadWithPartialName("System.Data.SqlServerCe")
                    }
                    $null = $asm
                }
                $resolvedDatabasePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                $sqlConnection = New-Object Data.SqlServerCE.SqlCeConnection "Data Source=$resolvedDatabasePath"
                $sqlConnection.Open()
            } elseif ($UseSqlite) {
                if (-not ('Data.Sqlite.SqliteConnection' -as [type])) {
                    if ($sqlitePath) {
                        $resolvedLitePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($sqlitePath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedLitePath)
                    } else {
                        $asm = [Reflection.Assembly]::LoadFrom("$env:ProgramFiles\System.Data.SQLite\2010\bin\System.Data.SQLite.dll")
                    }
                    $null = $asm
                }
                
                
                $resolvedDbPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                $sqlConnection = New-Object Data.Sqlite.SqliteConnection "Data Source=$resolvedDbPath"
                $sqlConnection.Open()
                
            } elseif ($useMySql) {
                if (-not ('MySql.Data.MySqlClient.MySqlConnection' -as [type])) {
                    if (-not $mySqlPath) {
                        $programDir = if (${env:ProgramFiles(x86)}) {
                            ${env:ProgramFiles(x86)}
                        } else {
                            ${env:ProgramFiles} 
                        }
                        $mySqlPath = Get-ChildItem "$programDir\MySQL\Connector NET 6.7.4\Assemblies\"| 
                            Where-Object { $_.Name -like "*v*" } | 
                            Sort-Object { $_.Name.Replace("v", "") -as [Version] } -Descending |
                            Select-object -First 1 | 
                            Get-ChildItem -filter "MySql.Data.dll" | 
                            Select-Object -ExpandProperty Fullname
                    }
                    $asm = [Reflection.Assembly]::LoadFrom($MySqlPath)
                    $null = $asm
                    
                }
                $sqlConnection = New-Object MySql.Data.MySqlClient.MySqlConnection "$ConnectionString"
                $sqlConnection.Open()
            } else {
                $sqlConnection = New-Object Data.SqlClient.SqlConnection "$connectionString"
                $sqlConnection.Open()
            }
            

        }
    }

    process {
        $dataSet = $null

        if ($PSCmdlet.ParameterSetName -eq 'SimpleSQL') {
            if (-not $Property) {
                $property = "*"
            }

            if ($Property -eq '*') {
                $propString = '*' 
            } else {
                if ($Property -like "*(*)*") {
                    $propString = "$($Property -join ',')"
                } else {
                    $propString = "`"$($Property -join '","')`""
                }
            }
        
            # Very minor SQL injection prevention.  If this is your last line of defense, you're in trouble, but using this will keep you out of some trouble.
            if ($where.IndexOfAny(";$([Environment]::NewLine)`0`b`t".ToCharArray()) -ne -1) {
                Write-Error "The Where Statement doesn't look safe"
                return
            }


            $sqlStatement = "SELECT $(if ($Top) { "TOP $Top" } ) $(if ($Distinct) { 'DISTINCT ' }) $propString FROM $FromTable $(if ($Where) { "WHERE $where"}) $(if ($OrderBy) { "ORDER BY $($orderBy -join ',') $(if ($Descending) { 'DESC'})"})".TrimEnd("\").TrimEnd("/")
            Write-Verbose "$sqlStatement"
         
            
        } elseif ($PSCmdlet.ParameterSetName -eq 'SQLQuery') {
            $sqlStatement = $Query    
        } elseif ($PSCmdlet.ParameterSetName -eq 'SQLFile') {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($SqlFile)
            if (-not $resolvedPath) { return }
            $sqlStatement = [IO.File]::ReadAllText("$resolvedPath")
        }
        if ($Dirty) {
            if ($UseMySql) {
                $sqlStatement = 
"
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;
$sqlStatement ;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
"
            } elseif (-not ($UseSQLCompact -or $UseSQLite)) {
                $sqlStatement += " WITH (nolock)"
            }
        }
        $dataset = $null
        if ($OutputSql) {
            $sqlStatement
        } else {            
            if ($UseSQLCompact) {
                $sqlAdapter= New-Object "Data.SqlServerCE.SqlCeDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            } elseif ($UseSQLite) {
                $sqlAdapter= New-Object "Data.SQLite.SQLiteDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            } elseif ($UseMySql) {
                $sqlAdapter= New-Object "MySql.Data.MySqlClient.MySqlDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            } else {
                $sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            }
            
        }

        


        if ($dataSet) {    
            if ($AsA -eq 'DataSet') {
                $dataSet
            } elseif ($AsA -eq 'DataTable') {
                foreach ($t in $dataSet.Tables) {
                    ,$t
                }
            } elseif ($AsA -eq 'PSObject') {                        
                foreach ($t in $dataSet.Tables) {
            
                    foreach ($r in $t.Rows) {
                    
                        if ($r.pstypename) {                    
                            $r.pstypenames.clear()
                            foreach ($tn in ($r.pstypename -split "\|")) {
                                if ($tn) {
                                    $r.pstypenames.add($tn)
                                }
                            }
                        
                        }
                        $null = $r.psobject.properties.Remove("pstypename")
                
                        $r
                
                    }
                }
            } elseif ($AsA -eq 'Hashtable') {
                $avoidProperties = @{}
                foreach ($pName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors') {
                    $avoidProperties[$pName] = $true 
                }
                foreach ($t in $dataSet.Tables) {
            
                    foreach ($r in $t.Rows) {
                    
                        $out = @{}
                        
                        foreach ($prop in $r.psobject.Properties) {
                            if ($avoidProperties[$prop.Name]) {
                                continue
                            }
                            $out[$prop.Name] = $prop.Value
                        }                        
                        

                        $out
                
                    }
                }
            }
        }

        
    }

    end {
         
        if ($sqlConnection) {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }
        
    }
}
 
