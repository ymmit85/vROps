<#
.SYNOPSIS  
    Run reports against multiple objects within vROps.
    
.DESCRIPTION
    Will run reports against multiple objects in vROps. Input list can be provided by parameter input or CSV.
    CSV file requires a single column with VM names of which to run report against.

.NOTES
    Version:    1.0
    Author:     Tim Williams

.LINK
    https://github.com/ymmit85/vrops

.PARAMETER outputDir
    Specify the directory to output logfile to.

.PARAMETER inputList
    Specify the path to the CSV file.

.PARAMETER resthost
    Hostname of vROPs host.

.PARAMETER username
    Username to log into vROps, script will prompt for password.
    Not required if token is provided.

.PARAMETER authsource
    Authentication source of user account logging into vROPs. 
    Use 'local' for local accounts.
    Not required if token is provided.

.PARAMETER token
    Authentication token already generated from PowervROps module.

.PARAMETER deleteReport
    Delete generated report from vROps server after download.

.PARAMETER reportName
    Name of report to run against objects.

.PARAMETER resourceKind
    Type of object running report against, this is used for searching objects.

.PARAMETER objectNames
    Names of objects to run report against. 

.EXAMPLE
    .\vROPs - Bulk_Report.ps1 -outputDir c:\temp -inputList 'c:\temp\inputfile.csv -restHost 'vropserver.lab.local' -token $token
    .\vROPs - Bulk Update.ps1 -outputDir c:\temp  -restHost 'vropserver.lab.local' -username admin -authsource local -objectnames 'srv1', 'srv2' -resourceKind VirtualMachine -reportName "Virtual Machine Performance Report"
#>

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
    $token,
    $deleteReport
    )
$errors = @()

#Below params can be hard coded if required.
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

#if auth token not created kill script
if (!($token)) {
    break
}

$errorPath = "$outputDir\$reportName - Errors.txt"

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
For($i = 0; $i -le $o; $i++) {

    #Loop through all objects
    foreach ($object in $objects) {
        $i++
            Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" ` -percentComplete (($i / $o)*100)

        #Find resouce ID of object to be reported on in vROPs
        If ($resourceKind) {
            $resource = (getresources -resthost $resthost -token $token -name $object -resourceKind $resourceKind).resourceList
        } else {
        $resource = (getresources -resthost $resthost -token $token -name $object).resourceList
        }

        #If multiple  objects are returned, filter out correct one based on requested object name.
        if (($resource.identifier).count -gt 1) {
            $resource = $resource |where {$_.resourcekey.name -eq $object} 
        }
        if ($resource.identifier -and ($resource.identifier).count -eq 1 ){

            #Submit request to create report
            Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Processing Object $object - ($i/$o)" -CurrentOperation "Creating Report" ` -percentComplete ($i / $objects.count*100)
            $rpt = createReport -resthost $resthost -token $token -reportdefinitionid $reportDef.reportDefinitions.id -objectid $resource.identifier

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

                    #Delete report once downloaded if selected
                    if ($deleteReport) {
                        Write-Progress -Activity "Running $reportName for $o object(s)" -Status "Deleting Report - ($rpt.id)" -CurrentOperation "Report Downloading"` -percentComplete ($i / $objects.count*100)
                        $rptDel = deleteReport -resthost $resthost -token $token -reportid $rpt.id
                    }

        # Check if multiple resources in vROPs with same name are found
        } elseif (($resource.identifier).count -gt 1){
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