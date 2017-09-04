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
        [int32]$PreferredCNet,
        [String]$SubnetSize = "large",
        [String]$Environment = "uat",
        [Switch]$ForceLegacyNamingConvention,       # This will allow subnet to be "netne-$VNet" and "netwe-$VNet"
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
    # If $PreferredCNet is enforced, then do enforce!
    #
    if ( $PreferredCNet ) {
        $LowestNetworkSegment = $PreferredCNet
        $HighestNetworkSegment = $PreferredCNet
    }

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

    # Ensure we are using the correct subscription
    try {
       $AZSubscriptions = Select-AzureRmSubscription -SubscriptionId $AllowedEnvironments[$environment]
        Write-Verbose ("Using subscription [" + ($AZSubscriptions.Subscription.Name) + "] with ID ["+$AZSubscriptions.Subscription.Id+"]")
    } catch {
        Write-Host -ForegroundColor Red ("Could not access specified SubscriptionID ["+$AZSubscriptions[$Environment]+"]. Check that you are logged in and that SubscriptionID is available.")
        Write-Host -ForegroundColor Red ($_.Exception.Message)
        $KillSmashDestroy = $true
        Break
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
        if ( $ForceLegacyNamingConvention ) {
            #
            # This will allow $VNet to follow the legacy format. I.e. net<shortSHORTlocation>-$VNet. Example: netne-vnet0
            # This is basically a work around because of manual setup of the primary virtual networks
            # before naming convention was established
            $VNetLongName = ("net" + $ThisLocationShort.Substring(0,2) + "-" + $VNet.ToLower())
        } else {
            if ( $VNet.EndsWith($DefaultVNetEnding) ) {
                Write-Debug ("vnet is LONG with ending")
                $VNetLongName = ($EnvironmentShortform[$Environment] + "-" + $ThisLocationShort + "-"+$VNet)
            } else {
                $VNetLongName = ($EnvironmentShortform[$Environment] + "-" + $ThisLocationShort + "-"+$VNet+$DefaultVNetEnding)
            }
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
            $UsedVirtualNetworkSubnetCIDRs = @()
            $UsedVirtualNetworkSubnetCIDRs += $CurrentVNet.Subnets.AddressPrefix

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

                        for ( $i = $LowestNetworkSegment; $i -le $HighestNetworkSegment; $i++ ) {
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
                                        Write-Debug ("Found subnet with same submask, but this range [" + $tmpCIDR + "] is taken. Will check next range.")
                                        Write-Verbose ("Found subnet with same submask, but this range [" + $tmpCIDR + "] is taken. Will check next range.")
                                    }
                                }
                            }
                        }
                    } else {
                        Write-Host -ForegroundColor Yellow ("Requested Subnet [/" + $AllowedSubnetCIDRs[$SubnetSize] + "] is larger than the master vnet address space [/" + $MasterPrefixCIDRMask + "]. Trying next address space in vnet (if exists)")
                    }
                }
            }

            $FoundFreeSubnet = $false
            Remove-Variable FoundFreeSubnet, AllMasterNets, CurrentVNet, CurrentMasterNet
        } else {
            Write-Host -ForegroundColor Red ("Could not locate VNet [" + $VNetLongName + "]. Cannot create subnet.")
            $KillSmashDestroy = $true
        }
    }


    #
    # Do some sanity checks to make sure all VNets have been delegated a subnet
    if ( ($CreateHash.Values.Keys -match "^newsubnet$").count -ne $LocationHash.count ) {
        Write-Host -ForegroundColor $whc ("One or more VNets could not provision the requested subnet")
        $CreateHash.Keys | %  {
            if ( $CreateHash[$_]["newsubnet"] ) {
                Write-Host -ForegroundColor $whc (" VNet [" + $_ + "] in location [" + $CreateHash[$_]["location"] + "] was delegated subnet [" + $CreateHash[$_]["newsubnet"] + "] with name [" + $CreateHash[$_]["newsubnetname"] + "]")
            } else {
                Write-Host -ForegroundColor Red (" VNet [" + $_ + "] in location [" + $CreateHash[$_]["location"] + "] could not delegate subnet.")
            }
        }
        $KillSmashDestroy = $true
        Break
    } else {
        # 
        # All VNets have been delegated a free subnet.
        # Make sure all subnets are in the same logical range. Else prompt user
        #

        $CreateHash.Keys | % {
            if ( ! $CheckSubnet ) {
                $CheckSubnet = ($CreateHash[$_]["newsubnet"]) -Replace "^\d+\.\d+", ""
            }
            if ( $CheckSubnet -ne (($CreateHash[$_]["newsubnet"]) -Replace "^\d+\.\d+", "") ) {
                $NotAllSubnetsAreTheSame = $true
            }
        }
    }

    if ( $NotAllSubnetsAreTheSame ) {
        Write-Host -ForegroundColor Yellow (" *** Warning *** : Not all networks are the same. Please review before continuing.")
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
            $VNetCounter = 0
            $CreateHash.Keys | % {
                Write-Progress -Activity "Creating subnet" -Status ("Creating subnet [" + $CreateHash[$_]["newsubnetname"] + "]/[" + $CreateHash[$_]["newsubnet"] + "] in VNet [" + $_ + "]") -PercentComplete (100/($CreateHash.Count - $VNetCounter)) 
                Write-Verbose ("Creating subnet [" +  $CreateHash[$_]["newsubnetname"] + "] with CIDR [" + $CreateHash[$_]["newsubnet"] + "]")
                # Create the Subnet
                try {
                    $tmpOutput = Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $CreateHash[$_]["vnetobject"] -Name $CreateHash[$_]["newsubnetname"] -AddressPrefix $CreateHash[$_]["newsubnet"]
                    $tmpOutput = Set-AzureRmVirtualNetwork -VirtualNetwork $CreateHash[$_]["vnetobject"]
                    Write-Verbose ("Finished creating subnet [" + $CreateHash[$_]["newsubnetname"] + "]" )
                    Remove-Variable tmpOutput
                } catch {
                    Write-Host -ForegroundColor Red ($_.Exception.Message)
                }
                $VNetCounter++
            }
        }
    }
}

    
