#
# Steps: 
# 
# Create Resource Group     (if doesn't exist)
# Create Virtual Network    (if doesn't exist)
# Create Subnet             
#  - with size "normal" /24, "small" /25 or "minimum" /26
    
Function New-AzureIaaSSubnet {
    # Todo: 
    #
    # * Ensure that all created subnets are in the same number. Currently script will create the first available subnet
    #   and not worry if it matches subnets in mirrored vnets. Example it should create 10.13.24.0/24 and 10.16.24.0/24 (Same C-net sequence)
    #   but it may as well create 10.13.24.0/24 and 10.13.64/24 if that is the first available C-net in the second mirror.
    #
    #
    Param (
        [Parameter(Mandatory = $True)][String]$Name,
        [Parameter(Mandatory = $True)][String]$VNet,
        # [String]$Location,              # If not set, will default to ALL locations
        [String]$SubnetSize = "large",
        [String]$Environment = "uat",
        [Switch]$WhatIf,
        [Switch]$Force
    )
    $SubnetName = (($Name.ToLower()) -Replace ("-subnet$"), "" )

    #
    # Load defaults
    # 
    # This code snippet is common to all IaaS scripts
    #
    $tmp = (Get-Variable PSCommandPath ).Value -Split "\\"
    $CommonScriptsPath = $tmp[0] 
    for ($i = 1; $i -lt ($tmp.length -1) ; $i++) {
        $CommonScriptsPath += "`\" + $tmp[$i]
    }
    $GetDefaultsPath    = ($CommonScriptsPath + "`\Get-AzureDefaults.ps1")
    $ValidateInputPath  = ($CommonScriptsPath + "`\Validate-AzureIaaSInput.ps1")
    . $GetDefaultsPath
    . $ValidateInputPath

    # 
    # Check that the defaults are loaded as expected
    #
    if ( ! $AllowedLocations ) {
        Write-Error ("Could not load defaults [" + $GetDefaultsPath + "]. Cannot continue.")
        Break
    }
    Remove-Variable tmp, GetDefaultsPath, ValidateInputPath


    #
    # Check if specific location is specified
    #
    if ( $Location ) {
        $LocationHash = @{$Location = $AllowedLocations[$Location]}
        Write-Host -ForegroundColor Red ("Ability to create subnet on single location is currently prohibited. Will not continue.")
        Break
    } else {
        $LocationHash = $AllowedLocations
    }

    # Access the Virtual Networks in Azure and store them for further use
    try {
        $AZVNets = Get-AzureRMVirtualNetwork
    } catch {
        Write-Host -ForegroundColor Red ("Could not retrieve Azure Virtual Networks. Make sure you are logged in and have access to the Azure portal.")
        Write-Host -ForegroundColor Red ("Error message:`n" + ($_.Exception.Message))
        Break
    }

    #
    # Check to see if we can locate the VNet specified.
    # 
    # Keep in mind that the VNet name can be specified in shortform, i.e. "mgmt" or in long form, i.e. "mgmt-net".
    # The actual name of the subnet will be for example 't-neu-mgmt-net', i.e. '<environment>-<location>-<vnetname>-net'
    #
    $CreateHash = @{}
    $VNet = $VNet.ToLower()
    $Iterator = ( ( (256 / ([Convert]::ToInt32(("1"+("0"*((([int32]($AllowedSubnetCIDRs[$SubnetSize]) +1)-24)-1))), 2)))  ))
    $LocationHash.Keys | % {
        $ThisLocationShort = $LocationHash[$_]
        if ( $VNet.EndsWith($DefaultVNetEnding) ) {
            Write-Debug ("vnet is LONG with ending")
            $VNetLongName = ($EnvironmentShortform[$Environment] + "-" + $ThisLocationShort + "-"+$VNet)
        } else {
            $VNetLongName = ($EnvironmentShortform[$Environment] + "-" + $ThisLocationShort + "-"+$VNet+$DefaultVNetEnding)
        }


        Write-Verbose ( " ----- " )
        Write-Verbose ( "Working on Virtual Network [" + $VNetLongName + "]" )
        if ( $VNetLongName.ToLower() -in $AZVNets.Name ) {
            $CreateHash.Add($VNetLongName, @{})
            $CreateHash[$VNetLongName].Add("location", $_)
            $CreateHash[$VNetLongName].Add("locationshort", $ThisLocationShort)
            #
            # VNet is found.
            #
            # Find the current subnets in this VNET and determine the next logical subnet based on the specified CIDR
            #
            $CurrentVNet = $AZVNets | ? -Property Name -Contains $VNetLongName

            #
            # Check if a subnet with the same name exists already
            # That would be bad, m'kay?
            #
            $NewSubnetName = ($VNetLongName+"-" + $SubnetName + $DefaultSubnetEnding).ToLower()
            if ( $NewSubnetName -in ($CurrentVNet.Subnets.Name)) {
                Write-Host -ForegroundColor Red ("Subnet with same name already exists in same VNet. Cannot continue.")
                $CreateHash = $null
                $AllMasterNets = $null
                Break
            }



            $CreateHash[$VNetLongName].Add("vnetobject", $CurrentVNet)
            $AllMasterNets = $CurrentVNet.AddressSpace.AddressPrefixes
            $UsedVirtualNetworkSubnetCIDRs = $CurrentVNet.Subnets.AddressPrefix

            $AllMasterNets | Sort-Object  | % {
                # The VNet can contain multiple CIDR address prefixes. Loop through all of them
                if ( ! $FoundFreeSubnet ) {
                    $CurrentMasterNet = $_
                    $tmp = $CurrentMasterNet.Split("/")
                    $MasterPrefixCIDRMask = $tmp[1]
                    $MasterIPBNet = (($tmp[0]) -Replace "\d+\.\d+$", "")
                    
                    #
                    # Check that the subnet we're trying to create is equal or smaller than the master vnet
                    #
                    if ( $MasterPrefixCIDRMask -le $AllowedSubnetCIDRs[$SubnetSize] ) {
                        # We can continue

                        for ( $i = $LowestNetworkSegment; $i -lt $HighestNetworkSegment; $i++ ) {
                            for ( $j = 0; $j -lt 255; $j = $j + $Iterator ) {
                                $tmpCIDR = [String]([String]$MasterIPBNet+[String]$i+"."+[String]$j+"/"+$AllowedSubnetCIDRs[$SubnetSize])
                                $MasterIPxNet = (($tmpCIDR) -Replace "\d+\/\d+$", "" ) # (($tmp[0]) -Replace "\d+$", "")

                                #
                                # Do some logic to determine if the requested AddressPrefix ($tmpCIDR) will fit into existing subnet
                                # or if we have to start on a completely new C-net
                                #
                                if ( ((($UsedVirtualNetworkSubnetCIDRs) -match "^"+$MasterIPxNet) -Replace "^.*\/", "" ) -ne  $AllowedSubnetCIDRs[$SubnetSize]) {
                                    # This CIDR is taken by different netmask
                                    Write-Verbose ("Subnet taken by different CIDR netmask [" + $MasterIPxNet + "x/y" + "]. Will check next C-net.")
                                    $j = 999999
                                } else {
                                    if ( ((($tmpCIDR) -Replace "\/.*$", "") -notin ( ($UsedVirtualNetworkSubnetCIDRs) -Replace "\/.*$", "")) ) {
                                        Write-Verbose (" - Success - The IP range [" +  $tmpCIDR + "] is available !!!") 
                                        $FoundFreeSubnet = $true

                                        $CreateHash[$VNetLongName].Add("newsubnet", $tmpCIDR)
                                        $CreateHash[$VNetLongName].Add("newsubnetname", ($VNetLongName+"-" + $SubnetName + $DefaultSubnetEnding))
                                        $i = $j = 999999
                                        Break
                                    } else {
                                        #if ( ($UsedVirtualNetworkSubnetCIDRs) -match $MasterIPxNet+"\d+\/" + $AllowedSubnetCIDRs[$SubnetSize]) {
                                        Write-Debug ("Found subnet with same submask, but this range [" + $tmpCIDR + "] is taken. Will check next range.")
                                        Write-Verbose ("Found subnet with same submask, but this range [" + $tmpCIDR + "] is taken. Will check next range.")
                                        # }
                                    }
                                }
                            }
                        }
                    } else {
                        Write-Host -ForegroundColor Yellow ("Requested Subnet [/" + $AllowedSubnetCIDRs[$SubnetSize] + "] is larger than the master vnet address space [/" + $MasterPrefixCIDRMask + "]. Trying next address space in vnet (if exists)")
                    }
                }
            }
            Remove-Variable FoundFreeSubnet, AllMasterNets, CurrentVNet, CurrentMasterNet
        } else {
            Write-Host -ForegroundColor Red ("Could not locate VNet [" + $VNetLongName + "]. Cannot create subnet.")
            $KillSmashDestroy = $true
        }
    }

    if ( $KillSmashDestroy ) {
        Break
    }

    $InfoMessage = "-----`nCreating new subnets: "
    $CreateHash.Keys | % {
        $InfoMessage += "`n Subnet [" + $CreateHash[$_]["newsubnetname"] + "] with CIDR [" + $CreateHash[$_]["newsubnet"] + "] will be created in VirtualNetwork [" + $_ + "] at Location [" + $CreateHash[$_]["location"] + "] "
    }

    if ( ! $WhatIf ) {
        if ( ! $Force ) {
            Write-Host ($InfoMessage)

            [String]$ContinueYN = ""
            while ( ($ContinueYN.ToLower() -notcontains "y") -and ($ContinueYN.ToLower() -notcontains "n") ) {
                $ContinueYN = Read-Host -Prompt "Do you want to continue (y/N)"
            } 
            if ( $ContinueYN.ToLower() -notmatch "y" ) { 
                Break 
            }
        } else {
            if ( $Debug ) {
                Write-Debug -Message $InfoMessage
            }
        }
    } else {
        Write-Host -ForegroundColor $whc ($wis + $InfoMessage)
        Break
    }
    Remove-Variable InfoMessage

    if ( ! $WhatIf ) {
        if ( $CreateHash ) {
            $CreateHash.Keys | % {
                Write-Verbose ("Creating subnet [" +  $CreateHash[$_]["newsubnetname"] + "] with CIDR [" + $CreateHash[$_]["newsubnet"] + "]")
                try {
                    $tmpOutput = Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $CreateHash[$_]["vnetobject"] -Name $CreateHash[$_]["newsubnetname"] -AddressPrefix $CreateHash[$_]["newsubnet"]
                    $tmpOutput = Set-AzureRmVirtualNetwork -VirtualNetwork $CreateHash[$_]["vnetobject"]
                    Write-Verbose ("Finished creating subnet [" + $CreateHash[$_]["newsubnetname"] + "]" )
                    Remove-Variable tmpOutput
                } catch {
                    Write-Host -ForegroundColor Red ($_.Exception.Message)
                }
            }
        }
    }
}

    
Function New-AzureIaaSEnvironment {
    #
    # 0: Set the default values and create variables
    #
    Param (
        [String]$VNet,
        [String]$ResourceGroupName,
        [ValidateSet("northeurope", "westeurope")][String]$Location,
        [ValidateSet("large", "big", "medium", "small", "tiny", "minimal")][String]$SubnetSize = "large",
        [ValidateSet("prod", "uat", "test")][String]$Environment = "uat",
        [Switch]$Debug,
        [Switch]$WhatIf,
        [Switch]$Verbose,
        [Switch]$Force
    )

    # Load defaults
    $tmp = (Get-Variable PSCommandPath ).Value -Split "\\"
    $DefaultsPath = $tmp[0] 
    for ($i = 1; $i -lt ($tmp.length -1) ; $i++) {
        $DefaultsPath += "`\" + $tmp[$i]
    }
    $DefaultsPath += "`\Get-AzureDefaults.ps1"
    . $DefaultsPath
    Remove-Variable tmp

    # 
    # Check that the defaults are loaded as expected
    #
    if ( ! $AllowedLocations ) {
        Write-Error ("Could not load defaults [" + $DefaultsPath + "]. Cannot continue.")
        Break
    }
    Remove-Variable DefaultsPath

    #
    # Set resourcegroup location to first instance of the AllowedLocations variable from defaults
    # if not specified as a variable
    #
    # ToDo: set this as random location???
    #
    if ( ! $RGLocation ) {
        $RGLocation = ($AllowedLocations.GetEnumerator() | Select -First 1).Name
    }


    # 
    # First some sanity checks of the parameters
    #
    if ( $VNet ) {
        if ( $VNet.length -lt 2 ) {
             Write-Error ("VNet name is to short. Must be atleast 2 letters long.")
             Break
        }
        $LCVNet = $VNet.ToLower()
    }
    if ( ! $VNet ) {
        Write-Error ("VNet name must be specified. Cannot continue.")
        Break
    }

    if ( ! $Location ) {
        $LocationHash = $AllowedLocations
    } else {
        if ( $AllowedLocations.ContainsKey($Location) ) {
            $LocationHash = @{$Location = $AllowedLocations[$Location]}
        } else {
            Write-Error ("Location is not a part of AllowedLocations: " + $AllowedLocations)
            Write-Host -ForegroundColor Red ($AllowedLocations)
            Break
        }

    }

    #
    # Retrieve some production data from Azure, prompting login if needed.
    #
    Try {
        If ( $Debug ) {
            Write-Debug -Message "Retrieving Azure Resources..."
        }
       $AZResources = Get-AzureRmResource
    } Catch {
       $tmpException = $_.Exception
       if ( $tmpException -match "Run Login-AzureRmAccount to login." ) {
           Login-AzureRmAccount -SubscriptionID $AllowedEnvironment[$Environment]
           $AZResources = Get-AzureRmResource
       } else {
           Write-Error ($tmpException)
           Break
       }
       Remove-Variable tmpException
    }

    if (! $AZResources) {
        # AZResources might be non-existent because no resources exist. Check subscriptions...
        if ( (Get-AzureRMSubscription)) {
            if ( $Debug ) {
                Write-Debug -Message "Azure resources are empty. We will continue and create brand new ones."
            }
        } else {
            Write-Warning ("Could not successfully connect to Azure, or Azure subscription is empty of resources.")
            Break
        }
    }

    #
    # We should now be succesfully connected to Azure
    #
    $VirtualNetworks = Get-AzureRmVirtualNetwork

    #
    # Check if VNet is specified and contains the mandatory "-net" suffix
    #
    if ( $VNet ) {
        if ( $VNet.ToLower().EndsWith($DefaultVNetEnding) ) {
            $LCVNetName = $VNet.ToLower()
            $VNet = $VNet.TrimEnd($DefaultVNetEnding)
        } else {
            $LCVNetName = $VNet.ToLower() + $DefaultVNetEnding
        }
        if ( $LCVNetName -in $VirtualNetworks.Name ) {
            Write-Error ("A VNet with that name ["+$LCVNetName+"] already exists. Cannot continue.")
            Break
        }
        $SubNetName = $VNet.ToLower() + $DefaultSubnetEnding
    }
    $LCSystemName = $VNet.ToLower()

    # Check if ResourceGroup is given as a variable. Else create one
    if ( $ResourceGroupName)  {
        if ( $ResourceGroupName.ToLower().EndsWith($DefaultRGEnding) ) {
            $LCRGName = $ResourceGroupName.ToLower()
        } else {
            $LCRGName = $ResourceGroupName.ToLower() + $DefaultRGEnding
        }
        if ( $LCRGName.length -lt 2 ) {
            Write-Error ("ResourceGroupName is to short.")
            Break
        }
    } else {
        $LCRGName = $LCSystemName + $DefaultRGEnding
    }

    #
    # Now check if RGName exists already
    #
    $AZResourceGroups = Get-AzureRmResourceGroup
    $InfoMessage = "------`n"
    if ( $LCRGName -notin $AZResourceGroups.ResourceGroupName) {
        $NewRG = $True
        $InfoMessage += "Creating new ResourceGroup     : "
    } else {
        $InfoMessage += "Using existing ResourceGroup   : "
    }

    $InfoMessage += $LCRGName + "`n"

    $UsedVirtualNetworkCIDRs = $VirtualNetworks | % { $_.AddressSpace }
    $CreateHash = @{}
    $LocationHash.Keys | % {
        $CreateHash.Add($_, @{})
        $CreateHash[$_].Add("subnetname", "t-"+$LocationHash[$_]+"-"+$LCSystemName+"-subnet")
        $CreateHash[$_].Add("nsg", $CreateHash[$_].subnetname + "-nsg")



        $LCNSG       = $LCSystemName + $DefaultNSGEnding
        # Try to determine the next free VirtualNetwork subnet address spaces
        
        if ( $AddressSpace ) {
            # This should only be used as a manual commandline creation of new VNet
            # when you are absolutely sure the VNet is not already in use. 
            # Otherwise it will fail
            Write-Error ("Input of manual subnet CIDR is not implemented yet. Cannot continue.")
            Break
        } else {
            # Try to determine the next free VirtualNetwork address spaces
            # Keep in mind that this may change if someone adds a VirtualNetwork at the same time
            # $VirtualNetworks = Get-AzureRmVirtualNetwork
            for ( $i=10; $i -lt 240; $i++ ) {
                $tmpCIDR = "10.$i.0.0/16"
                if ( $tmpCIDR -notin $UsedVirtualNetworkCIDRs.AddressPrefixes ) {
                    $tmpObj = New-Object -TypeName Microsoft.Azure.Commands.Network.Models.PSAddressSpace
                    $tmpObj.AddressPrefixes = $tmpCIDR
                    if ( ! $UsedVirtualNetworkCIDRs ) {
                        $UsedVirtualNetworkCIDRs = @()
                    }
                    $UsedVirtualNetworkCIDRs += $tmpObj 
                    Remove-Variable tmpObj
                    $FreeVirtualNetworkCIDR = $tmpCIDR
                    $FreeVirtualNetworkSubnetCIDR = "10.$i.0.0/24"
                    $i = 9999
                }
                Remove-Variable tmpCIDR
            }
        }

        # Produce an error if no available subnets were found
        if ( ( ! $FreeVirtualNetworkCIDR ) -or ( ! $FreeVirtualNetworkSubnetCIDR ) ) {
            Write-Error ("Could not locate an available subnet range for service.")
            Break
        }

        $CreateHash[$_].Add("vnetname", "t-"+$LocationHash[$_]+"-"+$LCVNetName)
        $CreateHash[$_].Add("vnetcidr", $FreeVirtualNetworkCIDR)
        $CreateHash[$_].Add("subnetcidr", $FreeVirtualNetworkSubnetCIDR)

    }

    $CreateHash.Keys | % {
        $InfoMessage += "Creating new VNet network ["+$_+"]:
 New NSG                        : " + $CreateHash[$_]["nsg"] + "`
 New VNet                       : " + $CreateHash[$_]["vnetname"] + "`
 New VNetIPCIDR                 : " + $CreateHash[$_]["vnetcidr"] + "`
  New Subnet                    : " + $CreateHash[$_]["subnetname"] + "`
  New SubnetIPCIDR              : " + $CreateHash[$_]["subnetcidr"] + "`
"
    }


    if ( ! $WhatIf ) {
        if ( ! $Force ) {
            Write-Host ($InfoMessage)

            [String]$ContinueYN = ""
            while ( ($ContinueYN.ToLower() -notcontains "y") -and ($ContinueYN.ToLower() -notcontains "n") ) {
                $ContinueYN = Read-Host -Prompt "Do you want to continue (y/N)"
            } 
            if ( $ContinueYN.ToLower() -notmatch "y" ) { 
                Break 
            }
        } else {
            if ( $Debug ) {
                Write-Debug -Message $InfoMessage
            }
        }
    }
    Remove-Variable InfoMessage
    

    
    #
    # 1: Create Resource Group - if not reusing an existing group
    # 
    if ( $NewRG ) {
        if ( $Verbose -Or $WhatIf ) {
            Write-Host -ForegroundColor $whc ($wis + "Creating Resource Group [" + $LCRGName + "] in location [" + $RGLocation + "]")
        }
        if ( ! $WhatIf ) {
            try {
                $NewRG = New-AzureRmResourceGroup -Name $LCRGName -Location $RGLocation
            } catch {
                Write-Error ("Could not successfully create ResourceGroup. Cannot continue.")
                Break
            }
        }
        Remove-Variable NewRG
    } else {
        if ( $WhatIf ) {
            Write-Host -ForegroundColor $whc ($wis + "Will not create new resource group [" + $LCRGName + "] because it already exists.")
        }
    }

    
    # Run through the CreateHash and create VNets and subnets based on the found attributes
    $CreateHash.Keys | % {
        $loc = $_

        # 
        # Check that virtual network does not already exist
        #

        if ( $CreateHash[$loc]["vnetname"] -notin $VirtualNetworks.Name ) {

            #
            # 2: Create Virtual Network
            #
            Write-Host -ForegroundColor $whc ($wis + "Creating Virtual Network ["+$CreateHash[$loc]["vnetname"]+"] in ["+$loc+"]")
            if ( ! $WhatIf ) {
                try {
                    $NewVNet = New-AzureRmVirtualNetwork -Name $CreateHash[$loc]["vnetname"] -ResourceGroupName $LCRGName -Location $loc -AddressPrefix $CreateHash[$loc]["vnetcidr"]
                } catch {
                    Write-Host -ForegroundColor Red ("Error when trying to create VNet VNet [" + $CreateHash[$loc]["vnetname"] + "]. Details: ")
                    Write-Host -ForegroundColor Red ("VNetname          : " + $CreateHash[$loc]["vnetname"])
                    Write-Host -ForegroundColor Red ("ResourceGroupName : " + $LCRGName)
                    Write-Host -ForegroundColor Red ("Location : " + $loc)
                    Write-Host -ForegroundColor Red ("AddressPrefix : " + $CreateHash[$loc]["vnetcidr"])
                    Write-Host -ForegroundColor Red ($_.Exception.ItemName)
                    Write-Host -ForegroundColor Red ($_.Exception.Message)
                    Write-Host -ForegroundColor Red ($_.Exception.StatusCode)
                    Write-Host -ForegroundColor Red ($_.Exception.ReasonPhrase)
                }
            }


            #
            # 3: Create Virtual Network Gateway Subnet
            #

            Write-Host -ForegroundColor $whc ($wis + "Creating Subnet [" + $CreateHash[$loc]["subnetname"] + "] in VNet [" + $CreateHash[$loc]["vnetname"] + "]")
            if ( ! $WhatIf ) {
                try {
                    $tmpOutput = Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $NewVNET -Name $CreateHash[$loc]["subnetname"] -AddressPrefix $CreateHash[$loc]["subnetcidr"]
                    $tmpOutput = Set-AzureRmVirtualNetwork -VirtualNetwork $NewVNET
                } catch {
                    Write-Host -ForegroundColor Red ("Error when trying to create Subnet in Vnet VNet [" + $CreateHash[$loc]["vnetname"] + "]. Details: ")
                    Write-Host -ForegroundColor Red ("Subnetname        : " + $CreateHash[$loc]["subnetname"])
                    Write-Host -ForegroundColor Red ("ResourceGroupName : " + $LCRGName)
                    Write-Host -ForegroundColor Red ("Location          : " + $loc)
                    Write-Host -ForegroundColor Red ("AddressPrefix     : " + $CreateHash[$loc]["subnetcidr"])
                    Write-Host -ForegroundColor Red ($_.Exception.ItemName)
                    Write-Host -ForegroundColor Red ($_.Exception.Message)
                    Write-Host -ForegroundColor Red ($_.Exception.StatusCode)
                    Write-Host -ForegroundColor Red ($_.Exception.ReasonPhrase)
                    Write-Host -ForegroundColor Cyan ($_.Exception | Select * )
                }
            }
            if ($NewVNet) {
                    Remove-Variable NewVNet
            }

        } else {
            # The VNet already exists. Find the next suitable subnet according to the criteria 
            Write-Host -ForegroundColor Red ("Virtual Network VNet [" + $CreateHash[$_]["vnetname"] + "] already exists.")
        }
    }
}

# # Stuff
# Break
# $start = 0 
# $cidr = 27
# $dostuff = 0
# $amplifier = ( ( (256 / ([Convert]::ToInt32(("1"+("0"*((($cidr +1)-24)-1))), 2)))  ))
# $ampiteration = 1
# $checkit = $amplifier * $ampiteration
# for ($i = 0; $i -lt 256; $i++) {
#     if ( $i -eq 0) { 
#             $i 
#     } else {
#         if ( $i -eq ($checkit) ) {
#             $i
#             $checkit += $amplifier
#         }
#     }
# }
