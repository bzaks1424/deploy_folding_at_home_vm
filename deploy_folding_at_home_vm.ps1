
###############################################################################################
# Path to OVF
$ovfPath = ".\VMware-FaH-Appliance_1.0.0.ova"
###############################################################################################
## MUST BE A VCENTER - ESXI HOSTS WILL NOT WORK ##
# vCenter Credentials.
$vcenter = "vcenter01.lab.michaelpmcd.com"
$vcenter_user = "administrator@vsphere.local"
$vcenter_password = "VMware1!"
###############################################################################################
# Deployment Environment Details
$datastore_name = "SSD_SHARE"
$vm_deploy_hostname = "esxi01.lab.michaelpmcd.com"
$network_name = "VM Network"
###############################################################################################
# By Default: Guest Hostname and VM will have the same exact name.
$guest_hostname = "vFAH01"
$guest_root_password = "VMware1!"
###############################################################################################
# Folding@Home Details
$fah_username = "MyUser"
$fah_team = "52737"
$fah_passkey = ""
$fah_mode = "medium" # Needs to be light, medium, full
$fah_gpu = $false # Or $true
###############################################################################################
# VM Guest OPTIONAL PARAMETERS
# VM Name if you don't want the guest hostname to match the VM name
$vm_name = ""
# Run Asynchronously
$run_async = $false
# IP Address Details
$guest_ip_address = ""
$guest_netmask = "" # Probably should be "24 (255.255.255.0)" if you'resetting manually
$guest_gateway = ""
# DNS, Domain, and NTP Details
$guest_dns = ""
$guest_domain = ""
$guest_ntp = "pool.ntp.org"
# Proxy Details
$guest_http_proxy = ""
$guest_https_proxy = ""
$guest_no_proxy = ""
$guest_proxy_username = ""
$guest_proxy_password = ""
###############################################################################################
# Folding@Home OPTIONAL PARAMETERS
$fah_web_remote_networks = ""
$fah_remote_networks = ""
$fah_remote_pass = ""
###############################################################################################

###############################################################################################
################################# DO NOT EDIT BELOW THIS LINE #################################
###############################################################################################
# What will this VM actually be named?
$actual_vm_name = ($vm_name.Trim().Length -gt 0) ? $vm_name : $guest_hostname
###############################################################################################
# Double Check that the OVF Actually Exists
if( -not (Test-Path $ovfPath)) {
	throw ("ERROR! Cannot find OVA or OVF in '$ovfPath'")
}
###############################################################################################
# Double Check those Octets!
$octet = '25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}'
if( -not ($guest_netmask -match "\d{1,2} \($octet\.$octet\.$octet\.$octet\)")) {
		throw ("ERROR! Invalid Netmask! '$guest_netmask' is not similar to 24 (255.255.255.0)")
}
###############################################################################################
# Double Check the folding at home Mode
$good_fah_modes = ('light', 'medium', 'full')
if( -not ($good_fah_modes -match $fah_mode)) {
	throw ("ERROR! Invalid Folding@Home Operating Mode ($fah_mode)! Must be 'light', 'medium' or 'full'")
}
###############################################################################################
# Establish Connection to vCenter
$connection = Connect-ViServer -Server $vcenter -User $vcenter_user -Password $vcenter_password
# If the connection is valid
if($connection) {
	# Validate Location of Deployment
	$vmhost = Get-VMHost -Name $vm_deploy_hostname
	$ds = Get-Datastore -Name $datastore_name
	$network = Get-VirtualPortGroup -Name $network_name
	if($vmhost -and $ds -and $network) {
		# Get OVF Config from File (Requires vCenter)
		$ovfConfig = Get-OvfConfiguration $ovfPath
		# Set Networking Details
		$ovfConfig.NetworkMapping.VM_Network.Value = $network_name
		# Set guest Hostname Details:
		$ovfConfig.Common.guestinfo.hostname.Value = $guest_hostname
		$ovfConfig.Common.guestinfo.root_password.Value = $guest_root_password
		
		# Write Out Info
		Write-Host "Deploying Guest: $guest_hostname in VM $actual_vm_name"
		Write-Host "    VMHost: $vm_deploy_hostname"
		Write-Host "    Network: $network_name"
		Write-Host "    Datastore: $datastore_name"
		Write-Host "    Guest Root Password Set"
		
		# DHCP Or Static?
		if($guest_ip_address -ne "") {
			Write-Host "    Static IP Address Set"
			Write-Host "        $guest_ip_address"
			Write-Host "        $guest_netmask"
			Write-Host "        $guest_gateway"
			
			$ovfConfig.Common.guestinfo.ipaddress.Value = $guest_ip_address
			$ovfConfig.Common.guestinfo.netmask.Value = $guest_netmask
			$ovfConfig.Common.guestinfo.gateway.Value = $guest_gateway
		}
		
		# Custom DNS
		if($guest_dns -ne "") {
			Write-Host "    Custom DNS: $guest_dns"
			$ovfConfig.Common.guestinfo.dns.Value = $guest_dns
		}
		
		# Custom Domain
		if($guest_domain -ne "") {
			Write-Host "    Domain: $guest_domain"
			$ovfConfig.Common.guestinfo.domain.Value = $guest_domain
		} 
		
		# NTP
		if($guest_domain -ne "") {
			Write-Host "    NTP: $guest_ntp"
			$ovfConfig.Common.guestinfo.ntp.Value = $guest_ntp
		} 
		
		# Proxy Info
		if(($guest_http_proxy -ne "") -or ($guest_https_proxy -ne "")) {
			Write-Host "    Http Proxy: $guest_http_proxy"
			Write-Host "    Https Proxy: $guest_https_proxy"
			$ovfConfig.Common.guestinfo.http_proxy.Value = $guest_http_proxy
			$ovfConfig.Common.guestinfo.https_proxy.Value = $guest_https_proxy
			if($guest_proxy_username -ne "") {
				Write-Host "    Http(s) Proxy Username: $guest_proxy_username"
				Write-Host "    Http(s) Proxy Password set"
				$ovfConfig.Common.guestinfo.proxy_username.Value = $guest_proxy_username
				$ovfConfig.Common.guestinfo.proxy_password.Value = $guest_proxy_password
			}
			if($guest_no_proxy -ne "") {
				Write-Host "    Http No Proxy: $guest_no_proxy"
				$ovfConfig.Common.guestinfo.no_proxy.Value = $guest_no_proxy
			}
		}
		
		Write-Host ""
		Write-Host "Setting Folding@Home Details:"
		Write-Host "    F@H Username: $fah_username"
		Write-Host "    F@H Team: $fah_team"
		Write-Host "    F@H Passkey Set"
		Write-Host "    F@H Mode: $fah_mode"
		Write-Host "    F@H Using GPU? $fah_gpu"
		$ovfConfig.Common.guestinfo.fah_username.Value = $fah_username
		$ovfConfig.Common.guestinfo.fah_team.Value = $fah_team
		$ovfConfig.Common.guestinfo.fah_passkey.Value = $fah_passkey
		$ovfConfig.Common.guestinfo.fah_mode.Value = $fah_mode
		$ovfConfig.Common.guestinfo.fah_gpu.Value = $fah_gpu
		
		# Remote FAH Web Client
		if($fah_web_remote_networks -ne "") {
			Write-Host "    Allowed Networks to access F@H web: $fah_web_remote_networks"
			$ovfConfig.Common.guestinfo.fah_web_remote_networks.Value = $fah_web_remote_networks
		}
		
		# Remote FAHControl
		if($fah_remote_networks -ne "") {
			Write-Host "    Allowed Networks to access FAHControl: $fah_remote_networks"
			$ovfConfig.Common.guestinfo.fah_remote_networks.Value = $fah_remote_networks
			
			# Remote Passkey
			if($fah_remote_pass -ne "") { 
				Write-Host "    F@H Remote Passkey Set"
				$ovfConfig.Common.guestinfo.fah_remote_pass.Value = $fah_remote_pass
			}
		}

		# Actual OVA Import Command
		$vapp_import = Import-VApp $ovfPath -OvfConfiguration $ovfConfig -VMHost $vmhost -Name $actual_vm_name -RunAsync:$run_async
	}

	Disconnect-ViServer -Server $connection -Confirm:$false
}