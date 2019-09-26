param(
    $vROpsHost,
    [System.Management.Automation.PSCredential]$vROpsCred,
    $debug
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
        #$body
        #Send Data to vROps
        if ($debug) {
            $body
        }

        $addProp = addProperties -resthost $vROpsHost -credential $vROpsCred -objectid $vROpsId -body $body
    }
#end region function

#region vROPs config
#Configure default valures for searching for vROps objects and updating properties
$adapterKind = 'vmware'
$propertyType = 'values'
#endregion vROPs config

$vc = $global:defaultviserver.name

#region getLicenceKeys
$licMgr = Get-View LicenseManager -Server $vc
    $licAssignmentMgr = Get-View -Id $licMgr.LicenseAssignmentManager -Server $vc
    $LicenseData = @()
    $licAssignmentMgr.QueryAssignedLicenses($vc.InstanceUid) | %{
        $LicenseData += $_ | select @{N='vCenter';E={$vc.Name}},EntityDisplayName,
        @{N='LicenseKey';E={$_.AssignedLIcense.LicenseKey}},
        @{N='LicenseName';E={$_.AssignedLicense.Name}},
        @{N='ExpirationDate';E={$_.AssignedLicense.Properties.where{$_.Key -eq 'expirationDate'}.Value }}
    }
#endregion getLicenceKeys

#
$hostLicenseData = $LicenseData | Where-Object {$_.LicenseName -like '*VMware vSphere 6 Enterprise Plus*'}

#Process all hosts
foreach ($license in $hostLicenseData) {
    #get vrops resource ID
    $resourceKind = 'HostSystem'
    $id = getResourcesWithAdapterAndResourceKind -credential $vROpsCred -resthost $vROpsHost -adapterKindKey $adapterKind -resourceKind $resourceKind -identifiers "[VMEntityName]=$($license.EntityDisplayName)"
        updatevROPs -statKey "LicenseData|LicenseName" -value $($license.LicenseName) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|LicenseKey" -value $($license.LicenseKey) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|ExpirationDate" -value $($license.ExpirationDate.ToString()) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
}

$vCenterLicenseData = $LicenseData | Where-Object {$_.LicenseName -like '*vCenter*'}

foreach ($vCenterLicense in $vCenterLicenseData) {
    #get vrops resource ID
    $resourceKind = 'VMwareAdapter Instance'
    $vcName = $vCenterLicense.EntityDisplayName
    $vcName = $vcName.Substring(0, $vcName.IndexOf('.'))
    $id = (getresources -resthost $vROpsHost -credential $vROpsCred -name $vcName -resourceKind $resourceKind).resourceList  
        updatevROPs -statKey "LicenseData|LicenseName" -value $($vCenterLicense.LicenseName) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|LicenseKey" -value $($vCenterLicense.LicenseKey) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|ExpirationDate" -value $($vCenterLicense.ExpirationDate.ToString()) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
    }

$vSANLicenseData = $LicenseData | Where-Object {$_.LicenseName -like '*VMware vSAN*'}

foreach ($vSANLicense in $vSANLicenseData) {
    #get vrops resource ID
    $resourceKind = 'ClusterComputeResource'
    $clusterName = $vSANLicense.EntityDisplayName
    $id = (getresources -resthost $vROpsHost -credential $vROpsCred -name $clusterName -resourceKind $resourceKind).resourceList
        updatevROPs -statKey "LicenseData|LicenseName" -value $($vSANLicense.LicenseName) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|LicenseKey" -value $($vSANLicense.LicenseKey) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
        updatevROPs -statKey "LicenseData|ExpirationDate" -value $($vSANLicense.ExpirationDate.ToString()) -vROpsId $id.identifier -vROpsHost $vROpsHost -vROpsCred $vROpsCred
    }