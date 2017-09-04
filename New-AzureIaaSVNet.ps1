Function New-AzureIaaSVNet {

    #
    # Function to create new VNet
    # 
    # -Name                 Name of new VirtualNetwork (duh...)
    # -ResourceGroupName    Name of new or excisting RG. Will add "-rg" suffix if not specified
    # -Location             Deprecated: Meant to create VNET in a specific location only. Should not be used.
    # -SubnetSize           If specified, the primary subnet will be using this CIDR. Requires SubnetName
    # -SubnetName           If specified, the primary subnet will be using this name. Sets Subnetsize=24 if not otherwise specified
    # -Environment          Specify environment / subscription. Usually "uat" or "prod"
    # -WhatIf               Will only tell what is to be done. Not actually do it
    # -Force                Will not prompt. Only do! Use with caution. 

    Param (
        [Parameter(Mandatory = $True)][String]$Name,
        [String]$ResourceGroupName,
        [String]$Location,
        [String]$SubnetSize,
        [String]$SubnetName,
        [String]$Environment = "uat",
        [PSCredential]$Cred,
        [Switch]$WhatIf,
        [Switch]$Force
    )


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
    # Set resourcegroup location to first instance of the AllowedLocations variable from defaults
    # if not specified as a variable
    #
    # ToDo: set this as random location???
    #
    if ( ! $RGLocation ) {
        $RGLocation = ($AllowedLocations.GetEnumerator() | Select -First 1).Name
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
           Login-AzureRmAccount -Credential $Cred
       } else {
           Write-Error ($tmpException)
           Break
       }
       Remove-Variable tmpException
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

    try {
           $AZResources = Get-AzureRmResource
    } catch {
        Write-Host -ForegroundColor Red ("Could not retrieve Azure Resources.")
        Write-Host -ForegroundColor Red ($_.Exception.Message)
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
    $Vnet = $Name
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
        # $SubNetName = $VNet.ToLower() + $DefaultSubnetEnding
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
        # $CreateHash[$_].Add("subnetname", $EnvironmentShortform[$Environment]+"-"+$LocationHash[$_]+"-"+$LCSystemName+"-subnet")
        # $CreateHash[$_].Add("nsg", $CreateHash[$_].subnetname + "-nsg")



        # $LCNSG       = $LCSystemName + $DefaultNSGEnding
        # Try to determine the next free VirtualNetwork subnet address spaces
        
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
                # $FreeVirtualNetworkSubnetCIDR = "10.$i.0.0/24"
                $i = 9999
            }
            Remove-Variable tmpCIDR
        }

        # # Produce an error if no available subnets were found
        # if ( ( ! $FreeVirtualNetworkCIDR ) -or ( ! $FreeVirtualNetworkSubnetCIDR ) ) {
        #     Write-Error ("Could not locate an available subnet range for service.")
        #     Break
        # }

        $CreateHash[$_].Add("vnetname", $EnvironmentShortform[$Environment]+"-"+$LocationHash[$_]+"-"+$LCVNetName)
        $CreateHash[$_].Add("vnetcidr", $FreeVirtualNetworkCIDR)
        # $CreateHash[$_].Add("subnetcidr", $FreeVirtualNetworkSubnetCIDR)

    }

    $CreateHash.Keys | % {
        $InfoMessage += "Creating new VNet network ["+$_+"]:
 New VNet                       : " + $CreateHash[$_]["vnetname"] + "`
 New VNetIPCIDR                 : " + $CreateHash[$_]["vnetcidr"] + "`
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

    
    # Run through the CreateHash and create VNets based on the found attributes
    $CreateCounter = 0          # A counter for the progress bar
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
                Write-Progress -Activity "Creating VNets" -Status ("Creating VirtualNetwork [" + $CreateHash[$loc]["vnetname"] + "]/[" + $CreateHash[$loc]["vnetcidr"] + "]") -PercentComplete (100/($CreateHash.Count - $CreateCounter)) 
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



            # Write-Host -ForegroundColor $whc ($wis + "Creating Subnet [" + $CreateHash[$loc]["subnetname"] + "] in VNet [" + $CreateHash[$loc]["vnetname"] + "]")
            # if ( ! $WhatIf ) {
            #     try {
            #         $tmpOutput = Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $NewVNET -Name $CreateHash[$loc]["subnetname"] -AddressPrefix $CreateHash[$loc]["subnetcidr"]
            #         $tmpOutput = Set-AzureRmVirtualNetwork -VirtualNetwork $NewVNET
            #     } catch {
            #         Write-Host -ForegroundColor Red ("Error when trying to create Subnet in Vnet VNet [" + $CreateHash[$loc]["vnetname"] + "]. Details: ")
            #         Write-Host -ForegroundColor Red ("Subnetname        : " + $CreateHash[$loc]["subnetname"])
            #         Write-Host -ForegroundColor Red ("ResourceGroupName : " + $LCRGName)
            #         Write-Host -ForegroundColor Red ("Location          : " + $loc)
            #         Write-Host -ForegroundColor Red ("AddressPrefix     : " + $CreateHash[$loc]["subnetcidr"])
            #         Write-Host -ForegroundColor Red ($_.Exception.ItemName)
            #         Write-Host -ForegroundColor Red ($_.Exception.Message)
            #         Write-Host -ForegroundColor Red ($_.Exception.StatusCode)
            #         Write-Host -ForegroundColor Red ($_.Exception.ReasonPhrase)
            #         Write-Host -ForegroundColor Cyan ($_.Exception | Select * )
            #     }
            # }
            # if ($NewVNet) {
            #         Remove-Variable NewVNet
            # }

        } else {
            # The VNet already exists. Find the next suitable subnet according to the criteria 
            Write-Host -ForegroundColor Red ("Virtual Network VNet [" + $CreateHash[$_]["vnetname"] + "] already exists.")
        }
        $CreateCounter++
    }

    if ( $SubnetName ) {
        $SubnetName = $SubnetName.ToLower()
        if ( ! $SubnetSize ) {
            $SubnetSize = 24
        } 

        Write-Verbose ("Will create a default subnet [" + $SubnetName + "] with CIDR size [" + $SubnetSize + "] in each VNet.")
        $ModuleNewSubnet = ($CommonScriptsPath + "`\New-AzureIaaSSubnet.ps1")

        if ( ! $WhatIf ) {

            #
            # 3: Create Virtual Network Gateway Subnet
            #
            try {
                if ( $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ) {
                    Write-Verbose ("Calling extrenal New-AzureIaaSSubnet function")
                    New-AzureIaaSSubnet -Name $SubnetName -VNet ($Name.ToLower()) -SubnetSize $SubnetSize -Force -Verbose
                } else {
                    New-AzureIaaSSubnet -Name $SubnetName -VNet ($Name.ToLower()) -SubnetSize $SubnetSize -Force
                }

            } catch {
                Write-Host -ForegroundColor Red ("Error when trying to create Subnet [" + $SubnetName + "]. Details: ")
                Write-Host -ForegroundColor Red ($_.Exception.Message)
            }
        }
    }
}


