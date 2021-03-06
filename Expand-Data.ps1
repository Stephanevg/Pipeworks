function Expand-Data
{
    <#
    .Synopsis
        Expands Compressed Data
    .Description
        Expands Compressed Data using the .NET GZipStream class
    .Link
        Compress-Data
    .Link
        http://msdn.microsoft.com/en-us/library/system.io.compression.gzipstream.aspx    

    .Example
        Compress-Data -String ("abc" * 1kb) | 
            Expand-Data  
    #>
    [CmdletBinding(DefaultParameterSetName='BinaryData')]
    [OutputType([string],[byte])]
    param(
    # The compressed data, as a Base64 string
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,ParameterSetName='CompressedData')]
    [string]
    $CompressedData,
    
    # The compressed data, as a byte array
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,ParameterSetName='BinaryData')]
    [Byte[]]
    $BinaryData,
    
    # The type of data the decompressed object will be (a string or a byte array)
    [ValidateSet('String', 'Byte')]
    [string]
    $As = 'String'
    )   
       
    process {
        #region Open Data
        if ($psCmdlet.ParameterSetName -eq 'CompressedData') {
            try {
            $binaryData = [System.Convert]::FromBase64String($CompressedData)
            } catch {
                Write-Verbose "Unable to uncompress base 64 string"
                return
            }
        }
        
        $ms = New-Object System.IO.MemoryStream
        $ms.Write($binaryData, 0, $binaryData.Length)
        $ms.Seek(0,0) | Out-Null
        $cs = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]"Decompress")
        #endregion Open Data

        #region Compress And Render
        if ($as -eq 'string') {
            $sr = New-Object System.IO.StreamReader($cs)
            $sr.ReadToEnd()
        } else {
            $bytes = do {
            $byte = $cs.ReadByte()
            if ($byte -ne -1) {
                [Byte]$byte
            } else {
                break
            }    
            } while ($byte -ne 1)
            $bytes -as [byte[]]
            
        }
        #endregion Compress And Render

    }
    
}

