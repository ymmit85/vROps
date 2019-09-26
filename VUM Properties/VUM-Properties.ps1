#Requires -Module PowervROps

param(
    $vROpsHost,
    [System.Management.Automation.PSCredential]$vROpsCred,
    $baseline,
    $cluster,
    $debug
)

#region function
    function updatevROPs {
        Param(
            $vROpsHost,
            $vROpsCred,
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
$vumBaseline = @()
#endregion vROPs config

#get Patch baseline to check, or if ALL entered get all baselines in VUM
if ($baseline -eq "All") {
    $vumBaseline = get-baseline 
} else {
    foreach ($b in $baseline) {
        $vumBaseline = get-baseline $baseline
        $m = $vumBaseline.count
    }
}

#Get Hosts in specified cluster, if not get all hosts in the connected vCenter
if ($cluster) {
    $hosts = get-cluster $cluster | get-vmhost
} else {
    $hosts = get-vmhost
}

$o = $hosts.Count

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

    #Process all hosts
    foreach ($h in $hosts) {
    $i++
    Write-Progress  -Id 1 -Activity "$($h.name) - ($i/$o)" ` -percentComplete (($i / $o)*100)

    #get vrops resource ID
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$h"

        #Check Baseline against Host
        For($j = 0; $j -le $m; $j++) {
            foreach ($bL in $vumbaseline) {
            $j++
            Write-Progress -Id 2 -Activity "Processing $($bL.name)" -Status "($j/$m)" ` -percentComplete (($j / $m)*100)
            $compliance = get-compliance -entity $h -baseline $bL

            #Make compliance results friendly
            if ($compliance.Status -eq "Compliant") {
                $values = "Compliant"
            } elseif ($compliance.Status -eq "Not Compliant") {
                $values = "Not Compliant"
            } elseif (($compliance.Status -eq "Unknown") -or ($compliance.Status -eq $null))  {
                $values = "Unknown"
            }
            updatevROPs -statKey "VUM|$($bL.name)" -value $values -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
            }
        }
    }
}