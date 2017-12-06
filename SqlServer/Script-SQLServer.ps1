<#
.SYNOPSIS
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>

$folderPath = "C:\temp\sqlscripts"

cd SQLSERVER:\sql\JOSHLUEDEMAN\SQL2012\Databases

foreach ($db in dir)
{
New-Item $folderPath\$($db.name) -type directory
$k = $folderPath + "\" + $($db.name) + "\" + $($db.name) + "_db.sql"
$db.script() > $k
cd $($db.name)
cd tables
New-Item $folderPath\$($db.name)\Tables -ItemType directory
New-Item $folderPath\$($db.name)\StoredProcedures -ItemType directory
New-Item $folderPath\$($db.name)\Triggers -ItemType directory
New-Item $folderPath\$($db.name)\Roles -ItemType directory
New-Item $folderPath\$($db.name)\Views -ItemType directory
New-Item $folderPath\$($db.name)\Users -ItemType directory
New-Item $folderPath\$($db.name)\Schemas -ItemType directory
New-Item $folderPath\$($db.name)\Tables\Triggers -ItemType directory
New-Item $folderPath\$($db.name)\Tables\Indexes -ItemType directory
New-Item $folderPath\$($db.name)\Tables\ForeignKeys -ItemType directory
	foreach ($table in dir)
	
	{
	$t = $folderPath + "\" + $($db.name) + "\Tables\" + $table.PSChildName + "_table.sql"
	$table.Script() > $t
		cd $table.PSChildName
		cd Triggers
		foreach ($ttrigger in dir)
		{
		$tt = $folderPath + "\" + $($db.name) + "\Tables\Triggers\" + $ttrigger.PSChildName + "_tblTrigger.sql"
		$ttrigger.script() > $tt
		}
		cd ..
		cd Indexes
		foreach ($index in dir)
		{
		$i = $folderPath + "\" + $($db.name) + "\Tables\Indexes\" + $index.PSChildName + "_index.sql"
		$index.script() > $i
		}
		cd ..
        cd ForeignKeys
        foreach ($foreignKey in dir)
        {
        $fk = $folderPath + "\" + $($db.name) + "\Tables\ForeignKeys\" + $foreignKey.PSChildName + "_forkey.sql"
        $foreignKey.script() > $fk
        }
        cd ..
        cd ..
	}
cd ..
	
cd StoredProcedures

	foreach ($sp in dir)
	
	{
	$s = $folderPath + "\" + $($db.name) + "\StoredProcedures\" + $sp.PSChildName + "_sp.sql"
	$sp.Script() > $s
	}
cd ..

cd Triggers
	foreach ($trigger in dir)
	
	{
	$g = $folderPath + "\" + $($db.name) + "\Triggers\" + $trigger.PSChildName + "_trigger.sql"
	$trigger.script() > $g
	}
cd ..

cd Roles
	foreach ($role in dir)
	{
	$r = $folderPath + "\" + $($db.name) + "\Roles\" + $role.PSChildName + "_role.sql"
	$role.script() > $r
	}
cd ..

cd Views
	foreach ($view in dir)
	{
	$v = $folderPath + "\" + $($db.name) + "\Views\" + $view.PSChildName + "_view.sql"
	$view.script() > $v
	}
cd ..

cd Users
	foreach ($user in dir)
	{
	$u = $folderPath + "\" + $($db.name) + "\Users\" + $user.PSChildName + "_users.sql"
	$user.script() > $u
	}
cd ..

cd Schemas
	foreach ($schema in dir)
	{
	$a = $folderPath + "\" + $($db.name) + "\Schemas\" + $schema.PSChildName + "_schema.sql"
	$schema.script() > $a
	}
cd ..

}
