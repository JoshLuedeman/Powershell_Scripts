workflow Pause-All-Datawarehouses
{
	$CredentialName = "SQLDW-Cred"

    #Get the credential with the above name from the Automation Asset store
    $psCred = Get-AutomationPSCredential -Name $CredentialName
    if(!$psCred) {
        Throw "Could not find an Automation Credential Asset named '${CredentialName}'. Make sure you have created one in this Automation Account."
    }

	#Login using the above Credential
    Login-AzureRmAccount -Credential $psCred

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
            Suspend-AzureRmSqlDatabase -ResourceGroupName "$rg" -ServerName "$sn" -DatabaseName "$db"
        }    
	}
}
