workflow StopRmVms
{
               try
               {
                              # Get the connection "AzureRunAsConnection "
                              $servicePrincipalConnection=Get-AutomationConnection -Name 'AzureRunAsConnection'         

                              "Logging in to Azure..."
                              Add-AzureRmAccount `
                                             -ServicePrincipal `
                                             -TenantId $servicePrincipalConnection.TenantId `
                                             -ApplicationId $servicePrincipalConnection.ApplicationId `
                                             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
               }
               catch {
                              if (!$servicePrincipalConnection)
                              {
                                             $ErrorMessage = "Connection $connectionName not found."
                                             throw $ErrorMessage
                              } else{
                                             Write-Error -Message $_.Exception
                                             throw $_.Exception 
                              }
               }

               $AzureSubscriptionIdAssetName = Get-AutomationVariable -Name 'SubscriptionId'
               Select-AzureRmSubscription -SubscriptionName $AzureSubscriptionIdAssetName

    $dbServer = Get-AzureAutomationVariable -Name 'dbserver'
    $dbUser = Get-AutomationVariable -Name 'dbuser'
    $dbPass = Get-AzureAutomationVariable -Name 'dbpass'
    $db = Get-AutomationVariable -Name 'db_config'

    # Get contents of the whitelist
    if($dbServer -ne $null)
    {
        $sqlqry = "EXEC azure.get_whitelist 'VM';"
        InlineScript{$whitelist = Invoke-Sqlcmd -ServerInstance $dbServer -Database $db -Query $sqlcmd -Username $dbUser -Password $dbPass}
    }
    else
    {
        $whitelist = @($null)
    }

               $ResourceGroups = Get-AzureRmResourceGroup

               foreach($ResourceGroup in $ResourceGroups)
               {
                              Write-Output ("Showing all VMs in resource group " + $ResourceGroup.ResourceGroupName)
                              $VMs = Get-AzureRmVM -ResourceGroupName $ResourceGroup.ResourceGroupName

                                             foreach -parallel ($vm in $VMs)
                                             {       
                                                            if($whitelist.ItemArray -contains $vm.Name)
                {
                    Write-Output("$vm.Name is in the whitelist. Passing")
                }
                else
                {
                    $stopRtn = Stop-AzureRmVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $VM.Name -force -ea SilentlyContinue
                    $count=1
                    if(($stopRtn.OperationStatus) -ne 'Succeeded')
                       {
                        if($whitelist.ItemArray -contains $sn)
                        {
                            do{
                                Write-Output "Failed to stop $($VM.Name). Retrying in 60 seconds..."
                                Start-Sleep -Seconds 60 
                                $stopRtn = Stop-AzureRmVM -ResourceGroupName $ResourceGroup.ResourceGroupName.ToString() -Name $VM.Name.ToString() -force -ea SilentlyContinue
                                #$stopRtn.OperationStatus = "Succeeded"
                                Write-Output "Stop-AzureRmVM -ResourceGroupName $ResourceGroup.ResourceGroupName.ToString() -Name $VM.Name.ToString() -force -ea SilentlyContinue"
                                $count++
                                }
                             while(($stopRtn.OperationStatus) -ne 'Succeeded' -and $count -lt 5)
                        }
                        }
            
                    if($stopRtn){Write-Output "Stop-AzureRmVM cmdlet for $($VM.Name) $($stopRtn.OperationStatus) on attempt number $count of 5."}
                }
                                             }

               }
               
               Write-Output ("Stop Azure RM VMs Runbook complete")


}
