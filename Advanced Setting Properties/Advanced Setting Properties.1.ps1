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
if (!($vROpsCred)) {
    $vROpsCred = get-credential
}

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
        addProperties -resthost $vROpsHost -credential $vROpsCred -objectid $vROpsId -body $body
    }
#end region function

#Get Hosts in specified cluster, if not get all hosts in the connected vCenter
if ($object -eq 'Host') {
    if ($cluster) {
        $objects = get-cluster $cluster | get-vmhost
    } else {
        $objects = get-vmhsot
    }
} elseif ($object -eq 'VM') {
    if ($cluster) {
        $objects = get-cluster $cluster | get-vm
    } else {
        $objects = get-vm
    }
}

#region vROPs config
#Configure default valures for searching for vROps objects and updating properties
if ($objosts) {
    $resourceKind = 'HostSystem'
} elseif ($VMs) {
  $resourceKind = 'VirtualMachine'
}
$adapterKind = 'vmware'
$propertyType = 'values'
#endregion vROPs config

$o = $objects.Count

if ($SettingList) {
    $inputlist = (get-content $SettingList) | Convertfrom-json
} else {
    $setting 
    $inputlist = $setting
    }

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

    #Process all hosts
    foreach ($obj in $objects) {
    $i++
    Write-Progress -Activity "$($obj.name) - ($i/$o)" ` -percentComplete (($i / $o)*100)

    #get vrops resource ID
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$obj"

        foreach ($s in $inputlist) {
            $result = $obj | Get-AdvancedSetting $s
            $m = $result.count
            For($j = 0; $j -le $m; $j++) {
                foreach ($r in $result) {      
                    $j++
                    Write-Progress -Id 2 -Activity "Processing $($r.name)" -Status "($j/$m)" ` -percentComplete (($j / $m)*100)
                    updatevROPs -statKey "Advanced Setting|$($r.name)" -value $r.value -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
                }
            }
        }
    }
}