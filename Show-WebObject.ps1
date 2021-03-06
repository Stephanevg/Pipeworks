function Show-WebObject
{
    <#
    .Synopsis
        Shows a web object
    .Description
        Shows a web object stored in cloud storage
    .Link
        Get-AzureTable
    .Example
        New-Object PSObject -Property @{
            Content = "# Some Markdown or HTML "            
        } |
            Set-AzureTable -TableName MyTable -RowKey Home -PartitionKey Website
        Show-WebObject -Table MyTable -Part Website -Row Home
    #>
    [CmdletBinding(DefaultParameterSetName='TableStorageObject')]
    [OutputType([string])]
    param(
    # The name of the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('TableName')]
    [string]$Table, 
    # The partition in the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('PartitionKey')]
    [string]$Part,
    # The row in the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('RowKey')]
    [string]$Row,
    
    # The table storage account 
    [Parameter(ParameterSetName='TableStorageObject')]
    [string]$StorageAccount,
    
    # The table storage key
    [Parameter(ParameterSetName='TableStorageObject')]
    [string]$StorageKey    
    )

    begin 
    {
        $page = ""
        
        $FetchedItems = @{}        
        $FetchedTimes = @{}

        $unpackItem = {
            $item = $_
            $item.psobject.properties |                         
                Where-Object { 
                    ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                    (-not $_.Value.ToString().Contains(' ')) 
                }|                        
                ForEach-Object {
                    try {
                        $expanded = Expand-Data -CompressedData $_.Value
                        $item | Add-Member NoteProperty $_.Name $expanded -Force
                    } catch{
                        Write-Verbose $_
                    
                    }
                }
                
            $item.psobject.properties |                         
                Where-Object { 
                    ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                    (-not $_.Value.ToString().Contains('<')) 
                }|                                   
                ForEach-Object {
                    try {
                        $fromMarkdown = ConvertFrom-Markdown -Markdown $_.Value
                        $item | Add-Member NoteProperty $_.Name $fromMarkdown -Force
                    } catch{
                        Write-Verbose $_
                    
                    }
                }
            $item     
        }
    }
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'TableStorageObject') {
            $item = Get-AzureTable -TableName $table -Partition $part -Row $row -StorageAccount $StorageAccount -StorageKey $storageKey #-ErrorAction SilentlyContinue
        }

        if (-not $item) { return } 
        
        $hasContent = $false
        if ($item.Content) {
            
            $content = if (-not $item.Content.Contains(" ")) {
                # Treat compressed
                Expand-Data -CompressedData $item.Content
            } else {
                $item.Content
            }
            $content = if (-not $Content.Contains("<")) {
                # Treat as markdown
                ConvertFrom-Markdown -Markdown $content 
            } else {
                # Treat as HTML
                $content
            }
            $hasContent = $true
            $page += $content            
        }
        
        if ($item.LatestItem) {
            # Embed Ajax to fetch the latest item from the given partition
        }                                
        
        if ($item.Video) {
            $hasContent = $true
            $page += "<br/>$(Write-Link $item.Video)<br/><br/>" | New-Region -Style @{'text-align'='center'} 
            
        }
        
        if ($item.ItemId) {
            $hasContent = $true
            $part,$row = $item.ItemId -split ":"
            $page += Get-AzureTable -TableName $table -Partition $part -Row $row |
                ForEach-Object $unpackItem|
                Out-HTML -ItemType { 
                    $_.pstypenames | Select-Object -Last 1                     
                } 
        }                
        
        if ($item.Detail) {
            $hasContent = $true
            $layerOrder = @()
            
            if ($item.ShowDetailAs -ne 'Page') {                        
                $detailLayers = $item.Detail -split "\|" |                 
                    foreach-Object { $_.Trim()} | 
                    Where-Object { $_ }|
                    ForEach-Object -Begin {
                        $detailPages = @{}
                    } -process {
                        $layerOrder += $_
                        $detailPages[$_] =  if ($FetchedItems["$table.$part.$_"]) {
                            if ((Get-Date).aDdMinutes(-20) -le $FetchedTimes["$table.$part.$_"]) {
                                $FetchedItems["$table.$part.$_"] = $null
                                Show-WebObject -Table $table -Part $part -Row $_ -StorageAccount $StorageAccount -StorageKey $StorageKey 
                            } else {
                                $FetchedItems["$table.$part.$_"]
                            }
                            
                        } else {
                            Show-WebObject -StorageAccount $StorageAccount -StorageKey $StorageKey -Table $table -Part $part -Row $_                        
                        }
                        
                        $FetchedItems["$table.$part.$_"] = $detailPages[$_]
                    } -End {
                        $detailPages
                    }
                    
                    
                $newRegionParameters = @{Layer=$DetailLayers;LayerOrder=$layerOrder}
                if ($item.ShowDetailAs) { 
                    $newRegionParameters["As" + $item.ShowDetailAs] = $true
                }
            } else {
                $page += $item.Detail -split "\|" |                 
                    foreach-Object { $_.Trim()} | 
                    Where-Object { $_ }|
                    Write-Link -Horizontal -Style @{'font-size'='medium'} -HorizontalSeparator ' ' -Url { $_ + ".aspx" } -Caption { $_ } -Button -Style @{'font-size'='x-large'}
                    
                $page += "
<BR/>"
            }
            if ($item.Id -and $newREgionParameters) {
                $newRegionParameters.LayerID = $item.Id
                $page += New-Region @newregionparameters
            }
            
            
            
        }
        
        if ($item.Related) {
            $hasContent = $true
            $page += 
                ((ConvertFrom-Markdown -Markdown $item.Related) -replace "\<a href", "<a class='RelatedLink' href") |
                    New-Region -Style @{'text-align'='right';'padding'='10px'} 
            $page += @'
<script>
    $('.RelatedLink').button()
</script>
'@            
            
        }
        if ($item.Next -or $item.Previous) {
            $hasContent = $true
            $previousChunk = if ($item.Previous) {
            $previousCaption = "<span class='ui-icon ui-icon-seek-prev'>
                </span>
                <br/>
                <span style='text-align:center'>
                Last
                </span>"

                Write-Link -Caption $previousCaption -Url $item.Previous -Button
            } else {
                ""
            }
            
            $nextChunk = if ($item.Next) {
            $nextCaption = "<span class='ui-icon ui-icon-seek-next'>
                </span>
                <br/>
                <span style='text-align:center'>
                Next
                </span>"
                Write-Link -Caption $nextCaption -Url $item.Next -Button
            } else {
                ""
            }
            $page+= "
<table style='width:100%'>
    <tr>
        <td style='50%;text-align:left'>
            $previousChunk
        </td>
        <td style='50%;text-align:right'>
            $nextChunk
        </td>
    <tr>
</table>"            
        }
        
        if (-not $hasContent) {
            $page += $item | 
                Out-HTML -ItemType { $_.pstypenames | Select-Object -Last 1 } 
        }
    }
    
    end {
        $page
    }
    

} 
