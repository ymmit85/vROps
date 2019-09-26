# vROPs Properties_Update

Script will allow input from CSV file to bulk update objects in vROPs with custom Metrics & Properties.

## Inputs

### CSV File

CSV will require the following fields.

    objectName,name,type,value

    objectName = Name of object within vROPs
    name = Name of property or metric to add
    type =  Specifies a Property or Metric to add
            data = Metric (number)
            values = Metric (string)
    value = Value of Property or Metric

### Script Parameters

    $outputDir = Directory to output errors
    $inputList = Path to input csv
    $resthost = vROPs Hostname
    $username = Username to connect with
    $authsource = Authentication source within vROPs for user account (local for local user accounts.)
    $token = Authentication token saved as variable from acquireToken function in PowervROPs
    $debug = Set value to view debug output while screen is running