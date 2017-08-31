# 
# This script contains all the Azure defaults which are commonly used 
#


$DefaultVNETEnding      = "-net"
$DefaultRGEnding        = "-rg"
$DefaultNSGEnding       = "-nsg"
$DefaultSubnetEnding    = "-subnet"
$AllowedLocations       = @{"westeurope" = "weu"; "northeurope" = "neu"; "uksouth" = "uks"}
$AllowedEnvironments    = @{"prod" = "a115349b-7e1c-4879-9a46-b960faf4b890"; "uat" = "3ec5d7cc-f501-4fc8-a695-386d71f6007e"}
$AllowedSubnetCIDRs     = @{"normal" = "/24"; "small" = "/25"; "minimum" = "/26"}

$whc = "White"          # Write-Host default colour
$wis = ""               # "What If String" - to be displayed in output if WhatIf flag is set


#
# Set default colours and output parameters
#
if ( $WhatIf ) {
    $wis = "What if: "
} 

if ( $Verbose ) {
    $whc = "Green"      # "Write-Host Colour" - override default colour if Verbose flag is set
}



#
# Common Functions
#
Function Write-Debug {
    Param (
        [String]$Message,
        [String]$ForegroundColor = "Yellow"
    )

    Write-Host -ForegroundColor $ForegroundColor ("Debug: " + $Message)
}
