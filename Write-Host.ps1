function Write-Host
{
    <#
    .ForwardHelpTargetName Write-Host
    .ForwardHelpCategory Cmdlet
    #>

    [CmdletBinding()]
    [OutputType([Nullable])]
    param(    
    [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
    [System.Object]
    ${Object},

    [Switch]
    ${NoNewline},

    [System.Object]
    ${Separator},

    [System.ConsoleColor]
    ${ForegroundColor},

    [System.ConsoleColor]
    ${BackgroundColor},
    
    # If set, will output text written to the host as an HTML span
    [Switch]
    $AsHtml)

    process {
        #region Override Write-Host for web context
        if ($AsHtml -or ($request -and $response) -or $host.Name -eq 'Default Host') {
            # Write as HTML
            $objectHtml = $Object
            
            $styleChunk = if ($ForegroundColor -or $backgroundColor)  {
                if ($ForegroundColor -and $backgroundcolor) {
                    " style='color:${ForeGroundColor};background=${BackgroundColor}'"
                } else {
                    if ($ForegroundColor) {
                        " style='color:${ForeGroundColor}'"
                    } else {
                        " style='background=${BackgroundColor}'"
                    }
                }
            } else {
                ""
            }
            $tag = "span"
            "<${tag}${styleChunk}>${ObjectHtml}</${tag}>$(if (-not $NoNewLine) {'<br/>'})"
        } else {
            # If we're not in a web site...
            Microsoft.PowerShell.Utility\Write-Host @psboundParameters
        }
        #endregion Override Write-Host for web context
    }
} 
