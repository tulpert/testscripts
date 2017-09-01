# 
# This script contains all the Azure defaults which are commonly used 
#


$DefaultVNETEnding      = "-net"
$DefaultRGEnding        = "-rg"
$DefaultNSGEnding       = "-nsg"
$DefaultSubnetEnding    = "-subnet"
$AllowedLocations       = @{"westeurope" = "weu"; "northeurope" = "neu"; "uksouth" = "uks"}
$AllowedEnvironments    = @{"prod" = "a115349b-7e1c-4879-9a46-b960faf4b890"; "uat" = "3ec5d7cc-f501-4fc8-a695-386d71f6007e"}
$EnvironmentShortform   = @{"prod" = "p"; "uat" = "t"}
$AllowedSubnetCIDRs     = @{"large" = "24"; "big" = "25"; "medium" = "26"; "small" = "27"; "tiny" = "28"; "minimal" = "29"}
$LowestNetworkSegment   = 10            # When generating new networks. Do not generate lower than this.
$HighestNetworkSegment  = 240           # When generating new networks. Do not generate higher than this. 

# 
# 256 - large (default)
# 128 - big
#  64 - medium
#  32 - small
#  16 - tiny
#   8 - minimal
# 



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



# #
# # Common Functions
# #
# Function Write-Debug {
#     Param (
#         [String]$Message,
#         [String]$ForegroundColor = "Yellow"
#     )
# 
#     Write-Host -ForegroundColor $ForegroundColor ("Debug: " + $Message)
# }
