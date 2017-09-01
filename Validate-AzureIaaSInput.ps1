# Created by Hakon 01 sep 2017

# This script checks default input parameters for the AzureIaas* family of scripts.
# It should only be called by those functions and not manually.
# Nothing bad will happen if you do call it manually, but I doubt you'll have any use for the output
#
# - hb

if ( $Location ) {
    if ( $Location -notin ($AllowedLocations.Keys) ) {
        Write-Host -ForegroundColor Red ("Location cannot be used. Allowed locations are: " + $AllowedLocations.Keys)
        Break
    }
}

if ( $SubnetSize ) {
    if ( $SubnetSize -notin ($AllowedSubnetCIDRs.Keys) ) {
        Write-Host -ForegroundColor Red ("Specified subnet size cannot be used. Allowed sizes are: " + $AllowedSubnetCIDRs.Keys)
        Break 
    }
}

if ( $Environment ) {
    if ( $Environment -notin ($AllowedEnvironments.Keys) ) {
        Write-Host -ForegroundColor Red ("Specified environment cannot be used. Allowed environments are: " + $AllowedEnvironments.Keys)
        Break 
    }
}
