param(
    $vROpsHost,
    [System.Management.Automation.PSCredential]$vROpsCred,
    $cluster,
    [Parameter(
        ParameterSetName='Setting'
    )]
        $Setting,
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
        $addProp = addProperties -resthost $vROpsHost -credential $vROpsCred -objectid $vROpsId -body $body
    }
#end region function

#region vROPs config
#Configure default valures for searching for vROps objects and updating properties
$resourceKind = 'HostSystem'
$adapterKind = 'vmware'
$propertyType = 'values'
#endregion vROPs config

#Get Hosts in specified cluster, if not get all hosts in the connected vCenter
if ($cluster) {
    $hosts = get-cluster $cluster | get-vmhost
} else {
    $hosts = get-vmhost
}

$o = $hosts.Count

if ($SettingList) {
    $inputlist = (get-content $SettingList) | Convertfrom-json
} else {
    $inputlist = $setting
    }

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

    #Process all hosts
    foreach ($h in $hosts) {
    $i++
    Write-Progress -id 1 -Activity "$($h.name) ($i/$o)" -percentComplete (($i / $o)*100)

    #get vrops resource ID
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$h"
    $AdvancedSettings = get-AdvancedSetting -entity $h -ErrorAction SilentlyContinue
        foreach ($s in $inputlist) {
            $result = $AdvancedSettings | where-Object {$_.name -like $s}
            foreach ($r in $result) {      
                Write-Progress -id 2 -Activity $r.name
                updatevROPs -statKey "Advanced Setting|$($r.name)" -value $r.value -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
            }
        }
    }
}