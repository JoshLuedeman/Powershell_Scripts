workflow StopAzureDWs
{
        param (
        [Parameter(Mandatory=$false)] 
        [String]  $connectionName = 'AzureRunAsConnection',
        
        [Parameter(Mandatory=$false)]
        [String] $SubscriptionId = ''
    )
        $SubscrtiptionId = Get-AutomationVariable -Name 'SubscriptionId'
               try
               {
                              # Get the connection "AzureRunAsConnection "
                              $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

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
    
    $dbServer = Get-AzureAutomationVariable -Name 'dbserver'
    $dbUser = Get-AutomationVariable -Name 'dbuser'
    $dbPass = Get-AzureAutomationVariable -Name 'dbpass'
    $db = Get-AutomationVariable -Name 'db_config'

    # Azure Subscription Name to be looked at
    Select-AzureRmSubscription -SubscriptionId $SubscriptionId 

    # Get contents of the whitelist
    if($dbServer -ne $null)
    {
        $sqlqry = "EXEC azure.get_whitelist 'DW';"
        InlineScript{$whitelist = Invoke-Sqlcmd -ServerInstance $dbServer -Database $db -Query $sqlcmd -Username $dbUser -Password $dbPass}
    }
    else
    {
        $whitelist = $null
    }

    #Get all SQL Datawarehouses in the subscription
    $dws = Get-AzureRmResource | Where-Object ResourceType -EQ "Microsoft.Sql/servers/databases" | Where-Object Kind -ILike "*datawarehouse*"
    
    #Loop through each SQLDW
    foreach($dw in $dws)
    {
        $rg = $dw.ResourceGroupName
        $dwc = $dw.ResourceName.split("/")
        $sn = $dwc[0]
        $db = $dwc[1]
        $status = Get-AzureRmSqlDatabase -ResourceGroupName $rg -ServerName $sn -DatabaseName $db | Select Status
        
        #Check the status
        if($status.Status -ne "Paused")
        {
            #If the status is not equal to "Paused", pause the SQLDW
            if($whitelist.ItemArray -contains $sn)
            {
                Write-Output("$sn is in the whitelist. Passing.")
            }
            else
            {
                Suspend-AzureRmSqlDatabase -ResourceGroupName "$rg" -ServerName "$sn" -DatabaseName "$db"
                Write-Output "Suspend-AzureRMSqlDatabase -ResourceGroupName $rg -ServerName $sn -DatabaseName $db"
            }
        }    
               }


}