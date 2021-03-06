function Install-PSNode
{
    <#
    .Synopsis
        Install a PSNode server on the local machine
    .Description
        Installs a PSNode server on a local machine
    .Example
        Install-PSNode "http://*:9090" -Command { 'hello world' } 
    .Link
        Start-PSNode
    .Link
        Open-Port
    #>
    [OutputType([Nullable])]
    param(
    # The server url, ie. http://localhost:9090/
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
    [string]$Server,
    
    # The command to run within the server
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=1)]   
    [ScriptBlock]$Command,
    
    # The authentication type
    [Parameter(Position=2, ValueFromPipelineByPropertyName=$true)]
    [Net.AuthenticationSchemes]
    $AuthenticationType = "Anonymous"
    )
    
    process {
       
        $safeServerName  = $Server.Replace("/", "").Replace(":","").Replace('*', 'star')
        Add-SecureSetting -Name "PSNode$safeservername" -String "$command"
        
        $port = ([uri]$server.Replace('*', 'place')).Port
        
        
        Open-Port -Port $port -Name "Port $port ForPSNode"
        
        $startScript = 
            "Import-Module Pipeworks; 
            `$command = Get-SecureSetting `"PSNode$safeservername`" -ValueOnly
            `$command = [ScriptBlock]::Create(`$command)
            Start-PSNode -Server '$server' -Command `$command -AuthenticationType '$AuthenticationType' -DoNotReturn
            "
            
        #region Create Task to Start the Server
        $scheduler = New-Object -ComObject Schedule.Service
        $scheduler.Connect()
        
        $task = $scheduler.NewTask(0)
        $task.Principal.RunLevel = 1
        $task.Settings.MultipleInstances = 3
        $task.Settings.RunOnlyIfNetworkAvailable = $true
        
        $action = $task.Actions.create(0)
        $action.path = "$pshome\powershell.exe"
        $base64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($startScript))
        $action.arguments = "-sta -noexit -windowstyle hidden -encodedCommand $base64 "
    
        $null = $task.Triggers.create(7)
        $logonTrigger = $task.Triggers.create(9)
        $logonTrigger.UserID = "$(whoami)"
        
        $registeredTask = $scheduler.GetFolder("").RegisterTask("PSNode-$safeservername", $task.XmlText, 6, $null, $null, 3, $null)
        $null = $registeredTask
        #endregion Create Task to Start the Server
    }
} 
