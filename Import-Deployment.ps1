function Import-Deployment
{
    <#
    .Synopsis
        Imports modules in your deployment
    .Description
        Imports modules in a deployment
    .Link
        Push-Deployment
    .Link
        Add-Deployment
    .Link
        Remove-Deployment
    .Example
        # Import all modules in a deployment
        Import-Deployment
    #>
    [CmdletBinding(DefaultParameterSetName='AllDeployments')]
    [OutputType([Management.Automation.PSModuleInfo])]
    param(
    # The name of the deployment 
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificDeployments')]
    [string]
    $Name
    )

    begin {
        #Get all deployments
        $deployments = Get-Deployment
        
        $progId = Get-Random
        #region Define Loader for each module
        $loadModule = {            
            $c++
            $perc = ($c / $total) * 100
            
            $in = $_
            Write-Progress "Importing Modules" $in.Name -PercentComplete $perc -Id $progId
            $module = @(Import-Module $_.Path -PassThru -Global -Force)

            if ($module.ExportedFunctions.Keys -like "*SecureSetting*") {
                
                Import-Module Pipeworks -Force -Global
            }

            if ($module.Count -gt 1 ) {
                $module | Where-Object {$_.Name -eq $in.Name } 
            } else {
                $module
            }
        }
        #endregion Define Loader for each module

    }

    process {        
        #region Find appropriate deployment
        if ($PSCmdlet.ParameterSetName -eq 'AllDeployments') {
            $deploymentsToLoad = $deployments |
                Sort-Object Name
        } else {
            $deploymentsToLoad = $deployments|                
                Where-Object { $_.Name -like $name } |
                Sort-Object Name
        }
        #endregion Find appropriate deployment

        #region Import deployment modules
        if ($deploymentsToLoad) {
            $c =0; $total = @($deploymentsToLoad).Count 
            foreach ($_ in $deploymentsToLoad) {
                . $loadModule
            }
        }
        #endregion Import deployment modules
    }
} 
