##################################################
#
# Load Config File and import values
#
##################################################

$cfgFile = ".\deploy_config.xml"
$cfg = [xml](gc $cfgFile)

# Import PublishSettings File
Add-AzureAccount
Get-AzurePublishSettingsFile
Import-AzurePublishSettingsFile -PublishSettingsFile $cfg.Config.PublishSettingsPath.ToString()
Read-Host -Prompt "Press Enter to continue after loading Publish Settings File"

Set-AzureSubscription -SubscriptionName $cfg.Config.SubscriptionName.ToString() -CurrentStorageAccountName $cfg.Config.MainStorage.Name.ToString()
Select-AzureSubscription -SubscriptionName $cfg.Config.SubscriptionName.ToString()

##################################################
#
# Storage Determination and/or Creation
#
##################################################

# Create Main Storage if needed

IF($cfg.Config.MainStorage.NewStorage.ToLower() -eq "yes")
    {
        Write-Host "Starting Create of Storage Account" + $cfg.Config.MainStorage.Name.ToString()
        New-AzureStorageAccount -StorageAccountName $cfg.Config.MainStorage.Name.ToString() -Location $cfg.Config.InstallRegion.ToString() -Verbose
    }

$mainStorName = $cfg.Config.MainStorage.Name.ToString()
$mainStorAddr = "$mainStorName.blob.core.windows.net"

IF($cfg.Config.SecStorageNeeded.ToLower() -eq "yes")
    {
        IF($cfg.Config.SecStorage.NewStorage.ToLower() -eq "yes")
            {
                Write-Host "Creating Second Storage"
                New-AzureStorageAccount -StorageAccountName $cfg.Config.SecStorage.Name.ToString() -Location $cfg.Config.InstallRegion.ToString() -Verbose
            }
        $secStorName = $cfg.Config.SecStorage.Name.ToString()
        $secStorAddr = "$secStorName.blob.core.windows.net"
        $secStorKey = Get-AzureStorageKey $secStorName | %{ $_.Primary} -Verbose
        $secStorContext = New-AzureStorageContext -StorageAccountName $secStorName -StorageAccountKey $secStorKey -Verbose

        IF($cfg.Config.SecStorage.NewContainer.ToLower() -eq "yes")
            {
                Write-Host "Creating Secondary Storage Container"
                New-AzureStorageContainer -Name $cfg.Config.SecStorage.ContainerName.ToLower() -Context $secStorContext -Verbose
            }
    }

$mainStorKey = Get-AzureStorageKey $mainStorName | %{ $_.Primary} -Verbose
$mainStorContext = New-AzureStorageContext -StorageAccountName $mainStorName -StorageAccountKey $mainStorKey -Verbose

IF($cfg.Config.MainStorage.NewContainer.ToLower() -eq "yes")
    {
        Write-Host "Creating Primary Storage Container"
        New-AzureStorageContainer -Name $cfg.Config.MainStorage.ContainerName.ToLower() -Context $mainStorContect -Verbose
    }
Write-Host "Done Creating storage pieces"

##################################################
#
# Metastore Determination and/or Creation
#
##################################################
Write-Host "Beginning metastore steps"
IF($cfg.Config.Metastore.ExtMetastore.ToLower() -eq "yes") 
    {
        Write-Host "Metastore needed"
        IF($cfg.Config.Metastore.New.ToLower() -eq "yes")
            {
                Write-Host "Creating a new metastore"
                IF($cfg.Config.Metastore.NewServer.ToLower() -eq "yes")
                    {
                        Write-Host "Creating Azure SQL DB Server"
                        $SqlDbSrv = New-AzureSqlDatabaseServer -AdministratorLogin $cfg.Config.Metastore.UserName -AdministratorLoginPassword $cfg.Config.Metastore.Pwd.ToString() -Location $cfg.Config.InstallRegion.ToString() -Verbose
                        
                    }
                ELSE
                    {
                        $SqlDbSrv = Get-AzureSqlDatabaseServer "$cfg.Config.Metastore.ServerName.ToString()" -Verbose
                    }
                New-AzureSqlDatabaseServerFirewallRule -ServerName $SqlDbSrv.ServerName.ToString() -AllowAllAzureServices -Verbose
                Write-Host "Creating MetaStore DB"
                New-AzureSqlDatabase -ServerName $SqlDbSrv.ServerName.ToString() -Edition Business -DatabaseName $cfg.Config.Metastore.HiveDbName.ToString() -Verbose
                IF($cfg.Config.Metastore.HiveDbName.ToLower() -ne  $cfg.Config.Metastore.OozieDbName.ToLower())
                    {
                           Write-Host "Creating Second Metastore DB for Oozie"
                           New-AzureSqlDatabase -ServerName $SqlDbSrv.ServerName.ToString() -Edition Business -DatabaseName $cfg.Config.Metastore.OozieDbName.ToString() -Verbose
                    }

            }

    $sqlPassSecure = ConvertTo-SecureString -String $cfg.Config.Metastore.Pwd.ToString() -AsPlainText -Force -Verbose
    $sqlCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cfg.Config.Metastore.UserName.ToString(), $sqlPassSecure -Verbose
    $SqlDbSrvAddr = $SqlDbSrv.ServerName.ToString() + ".database.windows.net"
    }
ELSE
    {
        Write-Host "No metastore needed"
    }

##################################################
#
# Cluster Type Determination and Creation
#
##################################################
Write-Host "Beginning Cluster Build"
$hadoopPassSecure = ConvertTo-SecureString -String $cfg.Config.Cluster.Pwd.ToString() -AsPlainText -Force -Verbose
$hadoopLogin = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cfg.Config.Cluster.UserName.ToString(), $hadoopPassSecure -Verbose

IF($cfg.Config.SecStorageNeeded.ToLower() -eq "yes")
    {
        IF($cfg.Config.Metastore.ExtMetastore.ToLower() -eq "yes")
            {
                Write-Host "Creating Cluster with Secondary Storage and External Metastore"
                New-AzureHDInsightClusterConfig -ClusterSizeInNodes $cfg.Config.Cluster.NodeNum.ToString() `
                    | Set-AzureHDInsightDefaultStorage -StorageAccountName $mainStorAddr -StorageAccountKey $mainStorKey -StorageContainerName $cfg.Config.MainStorage.ContainerName.ToLower() `
                    | Add-AzureHDInsightStorage -StorageAccountName $secStorAddr -StorageAccountKey $secStorKey `
                    | Add-AzureHDInsightMetastore -SqlAzureServerName $SqlDbSrvAddr -DatabaseName $cfg.Config.Metastore.OozieDbName.ToString() -Credential $sqlCred -MetastoreType OozieMetastore `
                    | Add-AzureHDInsightMetastore -SqlAzureServerName $SqlDbSrvAddr -DatabaseName $cfg.Config.Metastore.HiveDbName.ToString() -Credential $sqlCred -MetastoreType HiveMetastore `
                    | New-AzureHDInsightCluster -Location $cfg.Config.InstallRegion.ToString() -Name $cfg.Config.Cluster.Name.ToString() -Credential $hadoopLogin -Verbose
            }
        ELSE
            {
                Write-Host "Creating Cluster with Secondary Storage and No External Metastore"
                New-AzureHDInsightClusterConfig -ClusterSizeInNodes $cfg.Config.Cluster.NodeNum.ToString() `
                    | Set-AzureHDInsightDefaultStorage -StorageAccountName $mainStorAddr -StorageAccountKey $mainStorKey -StorageContainerName $cfg.Config.MainStorage.ContainerName.ToLower() `
                    | Add-AzureHDInsightStorage -StorageAccountName $secStorAddr -StorageAccountKey $secStorKey `
                    | New-AzureHDInsightCluster -Location $cfg.Config.InstallRegion.ToString() -Name $cfg.Config.Cluster.Name.ToString() -Credential $hadoopLogin -Verbose
            }
    }
ELSE
    {
        IF($cfg.Config.Metastore.ExtMetastore.ToLower() -eq "yes")
            {
                Write-Host "Creating Cluster without Secondary Storage and including an External Metastore"
                New-AzureHDInsightClusterConfig -ClusterSizeInNodes $cfg.Config.Cluster.NodeNum.ToString() `
                    | Set-AzureHDInsightDefaultStorage -StorageAccountName $mainStorAddr -StorageAccountKey $mainStorKey -StorageContainerName $cfg.Config.MainStorage.ContainerName.ToLower() `
                    | Add-AzureHDInsightMetastore -SqlAzureServerName $SqlDbSrvAddr -DatabaseName $cfg.Config.Metastore.OozieDbName.ToString() -Credential $sqlCred -MetastoreType OozieMetastore `
                    | Add-AzureHDInsightMetastore -SqlAzureServerName $SqlDbSrvAddr -DatabaseName $cfg.Config.Metastore.HiveDbName.ToString() -Credential $sqlCred -MetastoreType HiveMetastore `
                    | New-AzureHDInsightCluster -Location $cfg.Config.InstallRegion.ToString() -Name $cfg.Config.Cluster.Name.ToString() -Credential $hadoopLogin -Verbose
            }
        ELSE
            {
                Write-Host "Creating Cluster with no Secondary Storage and No External Metastore"
                New-AzureHDInsightCluster -Name $cfg.Config.Cluster.Name.ToString() -Location $cfg.Config.InstallRegion.ToString() `
                    -DefaultStorageAccountName $mainStorAddr `
                    -DefaultStorageAccountKey $mainStorKey -DefaultStorageContainerName $cfg.Config.MainStorage.ContainerName.ToLower() `
                    -ClusterSizeInNodes $cfg.Config.Cluster.NodeNum.ToString() -Credential $hadoopLogin -Verbose
            }
    }
Write-Host $cfg.Config.Cluster.Name " has been created"
