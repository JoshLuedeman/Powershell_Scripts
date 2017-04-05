workflow StopClassicVMs
{
               $SubscriptionId = Get-AutomationVariable -Name 'SubscriptionId'
    # Azure Subscription Name to be looked at

               # Get the connection
               $connection = Get-AutomationConnection -Name $connectionAssetName        

               # Authenticate to Azure with certificate
               Write-Verbose "Get connection asset: $ConnectionAssetName" -Verbose
               $Conn = Get-AutomationConnection -Name $ConnectionAssetName
               if ($Conn -eq $null)
               {
                              throw "Could not retrieve connection asset: $ConnectionAssetName. Assure that this asset exists in the Automation account."
               }

               $CertificateAssetName = $Conn.CertificateAssetName
               Write-Verbose "Getting the certificate: $CertificateAssetName" -Verbose
               $AzureCert = Get-AutomationCertificate -Name $CertificateAssetName
               if ($AzureCert -eq $null)
               {
                              throw "Could not retrieve certificate asset: $CertificateAssetName. Assure that this asset exists in the Automation account."
               }

               Write-Verbose "Authenticating to Azure with certificate." -Verbose
               #Set-AzureSubscription $AzureSubscriptionIdAssetName -Certificate $AzureCert 
               Select-AzureSubscription -SubscriptionName $AzureSubscriptionIdAssetName
    
    $dbServer = Get-AzureAutomationVariable -Name 'dbserver'
    $dbUser = Get-AutomationVariable -Name 'dbuser'
    $dbPass = Get-AzureAutomationVariable -Name 'dbpass'
    $db = Get-AutomationVariable -Name 'db_config'

    # Get contents of the whitelist
    if($dbServer -ne $null)
    {
        $sqlqry = "EXEC azure.get_whitelist 'VM';"
        InlineScript{$whitelist = Invoke-Sqlcmd -ServerInstance $dbServer -Database PWReporting -Query $sqlcmd -Username $dbUser -Password $dbPass}
    }
    else
    {
        $whitelist = @($null)
    }
               $VMs = Get-AzureVM | where-object -FilterScript {$_.status -ne 'StoppedDeallocated'} 
    
               foreach -parallel ($vm in $VMs)
               {
        if($whitelist.ItemArray -contains $vm.Name)
        {
            Write-Output("$vm.Name is in the whitelist. Passing")
        }   
        else
        {    
            $stopRtn = Stop-AzureVM -Name $VM.Name -ServiceName $VM.ServiceName -force -ea SilentlyContinue
            $count=1
            if(($stopRtn.OperationStatus) -ne 'Succeeded')
                {
                do{
                    Write-Output "Failed to stop $($VM.Name). Retrying in 60 seconds..."
                    Start-Sleep -Seconds 60
                    $stopRtn = Stop-AzureVM -Name $VM.Name -ServiceName $VM.ServiceName -force -ea SilentlyContinue
                    #$stopRtn.OperationStatus = "Succeeded"
                    Write-Output "Stop-AzureVM -Name $VM.Name -ServiceName $VM.ServiceName -force -ea SilentlyContinue"
                    $count++
                    }
                while(($stopRtn.OperationStatus) -ne 'Succeeded' -and $count -lt 5)
            
                }
            
            if($stopRtn){Write-Output "Stop-AzureVM cmdlet for $($VM.Name) $($stopRtn.OperationStatus) on attempt number $count of 5."}
        }
               }

               Write-Output ("Stop Azure RM VMs Runbook complete")
}
