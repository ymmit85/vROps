#Requires -Module PowervROps

param(
    $vROpsHost,
    [System.Management.Automation.PSCredential]$vROpsCred,
    $cluster,
    $object,
    [Parameter(
        ParameterSetName='Setting'
    )]
        $Setting,
    [Parameter(
        ParameterSetName='Hosts'
    )]
        $objosts,
    [Parameter(
        ParameterSetName='VMs'
    )]
        $vms,
    [Parameter(
        ParameterSetName='SettingList'
    )]
        $SettingList

)

#region function
        function updatevROPs {
            Param(
                $vROpsHost,
                [System.Management.Automation.PSCredential]$vROpsCred,
                $statKey,
                $value,
                $vROpsId
            )
        #Get current Epoch time for entering data 
        $date = getTimeSinceEpoch

        #Update JSON for data to be entered into vROps for Compliance Status
        $body = @{ 
            'property-content' = @( @{
                'timestamps' = @($date)
                'values' = @($value)
                'statKey' = $statKey
                'others' = @()
                'otherAttributes' = @{}
                }
            )
        } | convertto-json -depth 5
        #Send Data to vROps
        try {
        $addProp = addProperties -resthost $vROpsHost -credential $vROpsCred -objectid $vROpsId -body $body
        } catch {}
    }
#end region function

#Get Hosts in specified cluster, if not get all hosts in the connected vCenter
if ($object -eq 'Host') {
        $resourceKind = 'HostSystem'
    if ($cluster) {
        $objects = get-cluster $cluster | get-vmhost
    } else {
        $objects = get-vmhost
    }
} elseif ($object -eq 'VM') {
      $resourceKind = 'VirtualMachine'
    if ($cluster) {
        $objects = get-cluster $cluster | get-vm
    } else {
        $objects = get-vm
    }
}

#region vROPs config
#Configure default valures for searching for vROps objects and updating properties
$adapterKind = 'vmware'
$propertyType = 'values'
#endregion vROPs config

$o = $objects.Count

if ($SettingList) {
    $inputlist = (get-content $SettingList) | Convertfrom-json
} else {
    $inputlist = $setting
    }

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

    #Process all hosts
    foreach ($obj in $objects) {
    $i++
    Write-Progress -Activity "$($obj.name) - ($i/$o)" ` -percentComplete (($i / $o)*100)

    #get vrops resource ID
    $objName = $obj.name
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$objName"

        foreach ($s in $inputlist) {
            $cmd = '$obj'
            $result = invoke-expression ($cmd+$s)
            $statkeyName = $s.trimstart(".")
            $statkeyName = $statkeyName -replace '\W','|'
            updatevROPs -statKey "Setting|$statkeyName" -value $result -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        }
    }
}