## SYNOPSIS  
    Run reports against multiple objects within vROps.
    
## DESCRIPTION
    Will run reports against multiple objects in vROps. Input list can be provided by parameter input or CSV.

### PARAMETER outputDir
    Specify the directory to output logfile to.

### PARAMETER inputList
    Specify the path to the CSV file.

### PARAMETER resthost
    Hostname of vROPs host.

### PARAMETER username
    Username to log into vROps, script will prompt for password.
    Not required if token is provided.

### PARAMETER authsource
    Authentication source of user account logging into vROPs. 
    Use 'local' for local accounts.
    Not required if token is provided.

### PARAMETER token
    Authentication token already generated from PowervROps module.

### PARAMETER deleteReport
    Delete generated report from vROps server after download.

### PARAMETER reportName
    Name of report to run against objects.

### PARAMETER resourceKind
    Type of object running report against, this is used for searching objects.

### PARAMETER objectNames
    Names of objects to run report against. 

### EXAMPLE
```powershell
.\vROPs - Bulk_Report.ps1 -outputDir c:\temp -inputList 'c:\temp\inputfile.csv -restHost 'vropserver.lab.local' -token $token
```
```powershell
.\vROPs - Bulk Update.ps1 -outputDir c:\temp  -restHost 'vropserver.lab.local' -username admin -authsource local -objectnames'srv1', 'srv2' -resourceKind VirtualMachine -reportName "Virtual Machine Performance Report"
```
