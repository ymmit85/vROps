<#
.SYNOPSIS  
    Add custom properties/metrics to objects in vROPs
    
.DESCRIPTION
    Will add multiple custom properties/metrics to objects in vROPs.
    Data is sourced form csv file, script can be modified as required if multiple values are to be added.

.NOTES
    Version:    1.0
    Author:     Tim Williams

.LINK

.PARAMETER outputDir
    Specify the directory to output logfile to.

.PARAMETER inputList
    Specify the path to the configuration CSV file.

.PARAMETER resthost
    Hostname of vROPs host.

.PARAMETER username
    Username to log into vROps, script will prompt for password.

.PARAMETER authsource
    Authentication source of user account logging into vROPs. 
    Use 'local' for local accounts.

.PARAMETER token
    Authentication token already generated from PowervROps module.

.EXAMPLE
    .\vROPs - Bulk Update.ps1 -outputDir c:\temp -inputList 'c:\temp\inputfile.csv -restHost 'vropserver.lab.local' -token $token
    .\vROPs - Bulk Update.ps1 -outputDir c:\temp  -restHost 'vropserver.lab.local' -username admin -authsource local
#>

param (
    $outputDir,
    $inputList,
    $resthost,
    $username,
    $authsource,
    $token,
    $debug
    )
$errors = @()

<#
Hard set params if required
$resthost = 'vrops.network.local
$username = 'admin'
$password = 'password1'
$authsource = 'local'
#>

if ($username -and (!($password)) -and (!($token))) {
    $password = Read-Host 'Enter Password'
    $token = acquiretoken -resthost $resthost -username $username -password $password -authsource $authsource
}

$errorPath = "$outputDir\Custom Properties - Errors.txt"

#if auth token not created kill script
if (!($token)) {
    break
}

if ($inputList) {
    $objects = Import-Csv $inputList
} elseif ($objectNames) {
    $objects = $objectNames
} elseif (!($inputList) -and !($objectNames)) {
    Write-host "No input list or Object Names provided" -ForegroundColor Red
    break
}
$o = $objects.Count

#Create Progress bar in PowerShell window
For($i = 0; $i -le $o; $i++) {

    #Loop through all objects
    foreach ($object in $objects) {
        $i++
        Write-Progress -Activity "Updating Properties for $o object(s)" -Status "Processing Object $($Object.objectName) - ($i/$o)" ` -percentComplete ($i / $o*100)

        #Find resouce ID of object to be reported on in vROPs
        $resource = getresources -resthost $resthost -token $token -name $object.objectName -resourceKind $object.objecttype
        if ($resource.resourceList.identifier -and ($resource.resourceList.identifier).count -eq 1 ){
            $id = $resource.resourceList.identifier
            $id
            # Create the json payload to add the statistics to the virtual machine
                $body = @{ 
                    'property-content' = @( @{
                        'timestamps' = @(getTimeSinceEpoch -date (get-date))
                        'statKey' = $object.Name
                        $object.type = @($object.Value)
                        'others' = @()
                        'otherAttributes' = @{}
                        }
                    )
                } | convertto-json -depth 5
                
                if ($debug) {
                    $body
                    }
                $RES= addProperties -resthost $resthost -token $token -objectid $id -body $body
                $RES
write-host "res $res" -ForegroundColor Green
        # Check if multiple resources in vROPs with same name are found
        } elseif (($resource.resourceList.identifier).count -gt 1){
            write-debug "Multiple entires found for $object"
            $errors += $object + " - Multiple Entries Found"
            Continue
        #throw warnng if object is not found in vROPs
        } else {
            write-host "$object Not found"
            $errors += "$object + - Not Found"
            Out-File -InputObject $errors -FilePath $errorPath -Append
        }
    }
}

#Write out failed object list
if ($errors) {
    write-host $errors.count " issues found. Check " $errorPath
}