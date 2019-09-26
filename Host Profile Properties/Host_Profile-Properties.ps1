#Requires -Module PowervROps

param(
    $vROpsHost,
    [System.Management.Automation.PSCredential]$vROpsCred,
    $cluster,
    $debug
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

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

#Process all hosts
foreach ($h in $hosts) {
    $i++

    $appliedHostProfile = get-VMHostProfile -Entity $h
    Write-Progress -Activity "$($h.name) - ($i/$o)" -Status "Host Profile: $($appliedHostProfile.name)" ` -percentComplete (($i / $o)*100)

    #get vrops resource ID
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$h"

    #Check if there is a Host Profile attached to the host, if no move to next host
    if ($appliedHostProfile) {
        #Test Host Profile Compliance
        $results = test-VMHostProfileCompliance $h -usecache
    } else {
        updatevROPs -statKey "HostProfile|Name" -value "NA" -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        Continue
    }

        #Update vROps for host.
        if ($results){

            #Make compliance results friendly
            if ($results.extensiondata.ComplianceStatus -eq $null) {
                $values = "Unknown"
            } elseif ($results.extensiondata.ComplianceStatus -eq "nonCompliant") {
                $values = "Not Compliant"
            } elseif ($results.extensiondata.ComplianceStatus -eq "compliant") {
                $values = "Compliant"
            } else {
                $values = "Unknown"
            }

            updatevROPs -statKey "HostProfile|Status" -value $values -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
            updatevROPs -statKey "HostProfile|Name" -value $appliedHostProfile.name -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        }
    }
}