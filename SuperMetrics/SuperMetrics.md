# Super Metrics

These have been validated in vROPS 7.0.

## Property Based metrics


### Count total hosts running specific ESXi build
    count(${adaptertype=VMWARE, objecttype=HostSystem, depth=1, attribute=sys|build,where  = "equals 10719125"})

#### Calculate percentage of hosts running above build (*Note update Super Metric ID*)
        sum(${this, metric=Super Metric|sm_93260e86-446d-4af0-8715-4b9289dd7e70}/${this, metric=summary|total_number_hosts})*100

### Count total hosts in Maintenance mode

    count(${adaptertype=VMWARE, objecttype=HostSystem, depth=1, attribute=runtime|maintenanceState,where = "contains inMaintenance"})

### Count total hosts in Maintenance mode

    count(${adaptertype=VMWARE, objecttype=HostSystem, depth=1, attribute=runtime|connectionState,where = "contains notResponding"})