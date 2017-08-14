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


#
# 0: Set the default values and create variables
#
#
$SystemName = "Puppet"
$LCSystemName = $SystemName.ToLower()
$Location   = "ne"                                      # North Europe
$RGName = "rg-"+$LCSystemName
$NSGName    = "nsg-"+$LCSystemName


#
# Check that 1-6 does not already exist
#


#
# 1: Create Resource Group
#
#
# This command is relatively quick
New-AzureRmResourceGroup -Name RGName -Location $Location

#
# 2: Create Virtual Network
#
#
New-AzureRmVirtualNetwork -Name "net-puppet" -ResourceGroupName "rg-puppet" -Location "northeurope" -AddressPrefix 10.0.0.0/16

#
# 2.1: Create subnet
#
New-AzureRmVirtualNetworkSubnetConfig -Name "subnet-puppet" -AddressPrefix "10.0.0.0/24"


#
# 5: Create Network Security Group
#
#
# This command takes a few seconds
New-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $RGName -Location $Location

# Documentation:
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/tutorial-manage-vm

