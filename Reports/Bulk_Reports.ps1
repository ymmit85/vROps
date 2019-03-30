param (
    $outputDir,
    $inputList,
    $objectNames,
    $reportName,
    [ValidateSet("ClusterComputeResource","ComputeResource","CustomDatacenter","Datacenter","Datastore","StoragePod","DatastoreFolder","VM Entity Status","Folder","HostFolder","HostSystem","NetworkFolder","ResourcePool","VMwareAdapter Instance","VirtualMachine","VMFolder","DistributedVirtualPortgroup","VmwareDistributedVirtualSwitch","vSphere World")] 
    [String]
    $resourceKind,
    $resthost,
    $username,
    $authsource,
    $deleteReport
    )
$errors = @()

<#
Hard set params if required
$resthost = 'vrops.network.local
$username = 'admin'
$password = 'password1'
$authsource = 'local'
$deleteReport = 'y'
$reportName = "My VM Report"
$inputList = 'c:\temp\list.csv'
$outputDir = 'c:\temp'
#>

if ($username -and (!($password))) {
    $password = Read-Host 'Enter Password'
    $token = acquiretoken -resthost $resthost -username $username -password $password -authsource $authsource
}

$errorPath = "$outputDir\$reportName - Errors.txt"

#if auth token not created kill script
if (!($token)) {
    break
}

$reportDef = getReportDefinitions -resthost $resthost -token $token -name $reportName
if ($reportDef.reportDefinitions) {
    Write-host "Report Template $($reportDef.reportDefinitions.name) found."
} else {
    write-host "Report definition with name $reportName not found." -ForegroundColor Red
    $errors += $reportName + " - Not Found"
    break
}

if ($inputList) {
    $csvinput = Import-Csv $inputList -Header A
    $objects = $csvinput.A
} elseif ($objectNames) {
    $objects = $objectNames
} elseif (!($inputList) -and !($objectNames)) {
    Write-host "No input list or Object Names provided" -ForegroundColor Red
    break
}
$o = $objects.Count

#Create Progress bar in PowerShell window
For($i = 1; $i -le $o; $i++) {

    #Loop through all objects
    foreach ($object in $objects) {
        $i++
            Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" ` -percentComplete ($i / $o*100)

        #Find resouce ID of object to be reported on in vROPs
        If ($resourceKind) {
            $resource = getresources -resthost $resthost -token $token -name $object -resourceKind $resourceKind
        } else {
        $resource = getresources -resthost $resthost -token $token -name $object
        }
        if ($resource.resourceList.identifier -and ($resource.resourceList.identifier).count -eq 1 ){

            #Submit request to create report
            Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" -CurrentOperation "Creating Report" ` -percentComplete ($i / $objects.count*100)
            $rpt = createReport -resthost $resthost -token $token -reportdefinitionid $reportDef.reportDefinitions.id -objectid $resource.resourceList.identifier

            #Get status of the requested report
            $rptStatus = getReport -resthost $resthost -token $token -reportid $rpt.id
                do {
                    $rptStatus = getReport -resthost $resthost -token $token -reportid $rpt.id
                    Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" -CurrentOperation "Report $($rptStatus.status)" ` -percentComplete ($i / $objects.count*100)
                } until ($rptStatus.status -eq 'COMPLETED')

                    #When status of report is complted - download report
                    Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" -CurrentOperation "Report Downloading"` -percentComplete ($i / $objects.count*100)
                    downloadReport -resthost $resthost -token $token -reportid $rpt.id -format pdf -outputfile $outputDir\$object" - "$reportName.pdf
                    downloadReport -resthost $resthost -token $token -reportid $rpt.id -format csv -outputfile $outputDir\$object" - "$reportName.csv

                    #add in part here that deletes the report after download.
                    if ($deleteReport) {
                        Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Deleting Report - ($rpt.id)" -CurrentOperation "Report Downloading"` -percentComplete ($i / $objects.count*100)
                        $rptDel = deleteReport -resthost $resthost -token $token -reportid $rpt.id
                    }

        # Check if multiple resources in vROPs with same name are found
        } elseif (($resource.resourceList.identifier).count -gt 1){
            write-debug "Multiple entires found for $object"
            $errors += $object + " - Multiple Entries Found"
            Continue
        #throw warnng if object is not found in vROPs
        } else {
            write-debug "$object Not found"
            $errors += $object + " - Not Found"
            Out-File -InputObject $errors -FilePath $errorPath -Append

        }
    }
}

#Write out failed object list
if ($errors) {
    write-host $errors.count " issues found. Check " $errorPath
}
