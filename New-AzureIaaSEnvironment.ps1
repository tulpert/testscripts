#
# Steps: 
# 
# 1: Create Resource Group
# 2: Create Virtual Network
# 2.1: Create Subnet
# 3: Create Public IP address (if applicable)
# 4: Create NIC
# 5: Create Network Security Group (NSG)
# 6: Create Virtual Machine
# Next steps: 
# * Encrypting disks
    
    
Function New-AzureIaaSEnvironment {
    #
    # 0: Set the default values and create variables
    #
    Param (
        [String]$SystemName,
        [ValidateSet("northeurope", "westeurope")][String]$Location,
        [String]$TwoCharacterSystemName,
        [String]$Spoke,
        [Switch]$Prompt
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


    # $AllowedLocations = @{"westeurope" = "weu"; "northeurope" = "neu"}

    # 
    # First some sanity checks of the parameters
    #
    if ( $SystemName ) {
        if ( $SystemName.length -lt 2 ) {
             Write-Error ("SystemName is to short. Must be atleast 2 letters long.")
             Break
        }
        $LCSystemName = $SystemName.ToLower()
    }
    if ( ! $SystemName ) {
        Write-Error ("SystemName must be specified. Cannot continue.")
        Break
    }

    if ( ! $Spoke ) {
        Write-Error ("Spoke must be specified. Cannot continue.")
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
            break
            # Write-Debug ($AllowedLocations)
        }

    }

    if ( ! $TwoCharacterSystemName ) {
        $TwoCharacterSystemName = $LCSystemName.substring(0,2)
    }
    if ( $TwoCharacterSystemName ) {
        if ( $TwoCharacterSystemName.length -ne 2 ) {
            Write-Error ("TwoCharacterSystemName must be a string of two (2) characters only.")
            Break
        }
    } else {}

    #
    # Retrieve some production data from Azure, prompting login if needed.
    #
    Try {
       $AZResources = Get-AzureRmResource
    } Catch {
       $tmpException = $_.Exception
       if ( $tmpException -match "Run Login-AzureRmAccount to login." ) {
           Login-AzureRmAccount
           $AZResources = Get-AzureRmResource
       } else {
           Write-Error ($tmpException)
           Break
       }
       Remove-Variable tmpException
    }

    if (! $AZResources) {
        Write-Warning ("Could not successfully connect to Azure, or Azure subscription is empty of resources.")
        return
    }

    $AZVirtualNetworks = Get-AzureRmVirtualNetwork

    if ( $Spoke ) {
        if ( $Spoke.ToLower() -notin $AZVirtualNetworks.Name ) {
            Write-Error ("A spoke with that name does not exist. Must quit.")
            break
        }
        
    } else {
        Write-Error ("Spoke must be specified and must exist.")
        break
    }

    #
    # We should now be succesfully connected to Azure
    #
    $AZResourceGroups = Get-AzureRmResourceGroup


    # Run through the locationhash and generate all metadata for creation of new subnets
    $CreateHash = @{}
    $LocationHash.Keys | % {
        $CreateHash.Add($_, @{})
        $CreateHash[$_].Add("subnetname", "t-"+$LocationHash[$_]+"-"+$LCSystemName+"-subnet")
        $CreateHash[$_].Add("nsg", $CreateHash[$_].subnetname + "-nsg")

    }
    $CreateHash
    Break
    # Try to determine the next free VirtualNetwork subnet address spaces
    

    # # Try to determine the next free VirtualNetwork address spaces
    # # Keep in mind that this may change if someone adds a VirtualNetwork at the same time
    # $VirtualNetworks = Get-AzureRmVirtualNetwork
    # $UsedVirtualNetworkCIDRs = $VirtualNetworks | % { $_.AddressSpace }
    # for ( $i=10; $i -lt 255; $i++ ) {
    #     $tmpCIDR = "10.$i.0.0/16"
    #     if ( $tmpCIDR -notin $UsedVirtualNetworkCIDRs.AddressPrefixes ) {
    #         $FreeVirtualNetworkCIDR = $tmpCIDR
    #         $FreeVirtualNetworkSubnetCIDR = "10.$i.0.0/24"
    #         $i = 9999
    #     }
    #     Remove-Variable tmpCIDR
    # }

#     # Produce an error if no available subnets were found
#     if ( ( ! $FreeVirtualNetworkCIDR ) -or ( ! $FreeVirtualNetworkSubnetCIDR ) ) {
#         Write-Error ("Could not locate an available subnet range for service.")
#                 Break
#    }
    
    # Write-Debug ("Found new CIDR range: " + $FreeVirtualNetworkCIDR )

    

    $RGName         = $LCSystemName+"-rg"
    $NSGName        = $LCSystemName+"-nsg"
    $VNetName       = $Spoke
    $VNetNetwork    = ($AZVirtualNetworks | ? -Property Name -contains $Spoke) #  | Select AddressSpace).AddressSpace.AddressPrefixes
    $SubNetName     = $VNetName + "-subnet"
    $PlaceHolder    = "<--- FILL IN HERE --->"

    #
    # Check that no current NGS or RG or Vnet exists with the same name
    #
    if ( $RGName -in ($AZResourceGroups.ResourceGroupName.tolower() | Get-Unique) ) {
        Write-Error ("A ResourceGroup by that name already exists: " + $RGName)
        Break 
    }
    # These do not matter. Two NSGs and VNets can have the same name as long as they are in separate ResourceGroups
    # if ( $NSGName -in (($azresource | ? -Property ResourceType -Contains "Microsoft.Network/networkSecurityGroups").name) )  {
    #     Write-Error ("A NetworkSecurityGroup by that name already exists: " + $NSGName)
    #     Return
    # }
    # if ( $VNetName -in (($azresource | ? -Property ResourceType -Contains "Microsoft.Network/virtualNetworks").name) )  {
    # if ( $VNetName -in () ) {
    #     Write-Error ("A Virtual Network by that name already exists: " + $VNetName)
    #     Return 
    # }

    if ( $Prompt ) {
        $LocationOutput = ""
        $LocationHash.Keys | % {
            $LocationOutput = $LocationOutput + ", " + ($_)
        }
        $LocationOutput = $LocationOutput -Replace "^,\s*", ""
        Write-Host ("This will continue to create a new environment based on the following: `
Systemname              : " + $SystemName + " (" + $TwoCharacterSystemName + ")`
ResourceGroupName       : " + $RGName + "`
Location                : " + $LocationOutput + "`
NetworkSecurityGroup    : " + $NSGName + "`
Virtual Network Name    : " + $VNetName + "`
Virtual Network Range   : " + ($VNetNetwork | Select AddressSpace).AddressSpace.AddressPrefixes + "`
Subnet Name             : " + $SubNetName + "`
Subnet Range            : " + $FreeVirtualNetworkSubnetCIDR + "")

        [String]$ContinueYN = ""
        while ( ($ContinueYN.toLower() -notcontains "y") -and ($ContinueYN.toLower() -notcontains "n") ) {
            $ContinueYN = Read-Host -Prompt "Do you want to continue (y/N)"
        
        } 
        if ( $ContinueYN.toLower() -notmatch "y" ) { 
            Break 
        }
        
    }

    "-------------- THIS SHOULD NOT HAPPEN ON n -------------------"
break
    
    #
    # 1: Create Resource Group
    # 
    Write-Host -ForegroundColor green ("Creating Resource Group")
    Write-Host -ForegroundColor green ("Sleeping to allow for ctrl-c")
    Sleep 2
    Write-Host -ForegroundColor green ("Finished sleeping")
    $newRG = New-AzureRmResourceGroup -Name $RGName -Location $Location

    #
    # 2: Create Virtual Network
    #
    Write-Host -ForegroundColor green ("Creating Virtual Network")
    $NewVNet = New-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $RGName -Location $Location -AddressPrefix $FreeVirtualNetworkCIDR

    #
    # 3: Create Virtual Network Subnet
    Write-Host -ForegroundColor green ("Creating Subnet")
    $tmpOutput = Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $NewVNet -Name $SubNetName -AddressPrefix $FreeVirtualNetworkSubnetCIDR
    $tmpOutput = Set-AzureRmVirtualNetwork -VirtualNetwork $NewVNET
    if ($NewVNet) {
        Remove-Variable NewVNet
    }


#    #
#    # 4: Create NIC
#    # 
#    $nic = New-AzureRmNetworkInterface -Name "nic-puppetmaster-01" -ResourceGroupName "rg-puppet" -Location "northeurope" -SubnetId (Get-AzureRmVirtualNetworkSubnetConfig -Name "subnet-puppet-net-puppet" -VirtualNetwork (Get-AzureRmVirtualNetwork -Name "net-puppet" -ResourceGroupName "rg-puppet")).id
#    
#    
#    #
#    # 5: Create Network Security Group
#    #
#    #
#    # This command takes a few seconds
#    New-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $RGName -Location $Location
#    
#    #
#    # 5.1: Create NSG rules
#    #
#    # Example with RDP tcp port 3389 inbound
#    #
#    $nsg = Get-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $RGName 
#    # $newrule = New-AzureRmNetworkSecurityRuleConfig -Name "AllowRDPInBound" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
#    Add-AzureRmNetworkSecurityRuleConfig -Name "AllowRDPInBound" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow -NetworkSecurityGroup $nsg
#    Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
#    
#    
#    #
#    # 6: Create Virtual Machine
#    #
#    $username = tmphakon
#    $password = "Dette er en test!" | ConvertTo-SecureString
#    $cred = New-Object -Typename System.Management.Automation.PSCredential -argumentlist $username, $password
#    $newvm = New-AzureRmVMConfig -VMName "puppet-wintest-01" -VMSize Standard_D1
#    $newvm = Set-AzureRmVMOperatingSystem -VM $newvm -Windows -ComputerName 
#    
#    
#    # Documentation:
#    # https://docs.microsoft.com/en-us/azure/virtual-machines/windows/tutorial-manage-vm
}

    
#    #
#    # Check that 1-6 does not already exist
#    #
#    
#    
#    #
#    # 1: Create Resource Group
#    #
#    #
#    # This command is relatively quick
#    New-AzureRmResourceGroup -Name RGName -Location $Location
#    
#    #
#    # 2: Create Virtual Network
#    #
#    #
#    New-AzureRmVirtualNetwork -Name "net-puppet" -ResourceGroupName "rg-puppet" -Location "northeurope" -AddressPrefix 10.0.0.0/16
#    
#    #
#    # 2.1: Create subnet
#    #
#    $tmpVNET = Get-AzureRmVirtualNetwork -Name "net-puppet" -ResourceGroupName "rg-puppet"
#    Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $tmpVNET -Name "subnet-puppet-net-puppet" -AddressPrefix "10.0.0.0/24"
#    Set-AzureRmVirtualNetwork -VirtualNetwork $tmpVNET
#    if ($tmpVNET) {
#        Remove-Variable tmpVNET
#    }
#    
#    
#    # 
#    # 3: Create Public IP Address
#    #
#    $pubip = New-AzureRmPublicIpAddress -Name "publicip-puppetmaster" -ResourceGroupName "rg-puppet" -Location "northeurope" -AllocationMethod Dynamic
#    if ($pubip)  {
#        Remove-Variable pubip
#    }
#    
