function Get-EC2KeyPair
{
    <#
    .Synopsis
        Gets key pair information from EC2.
    .Description
        Gets key pair information from EC2.  Key pairs are used to identify secure information.
    .Example
        Get-EC2KeyPair
    .Link
        Remove-EC2KeyPair
    #>
    param()
    
    process {
        $AwsConnections.EC2.DescribeKeyPairs((New-Object Amazon.EC2.Model.DescribeKeyPairsRequest)).DescribeKeyPairsResult.KeyPair        
    }
} 
