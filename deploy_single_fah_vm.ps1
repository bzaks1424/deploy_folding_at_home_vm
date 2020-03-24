. .\VMW_FAH_LIB.ps1

function Main {
	###############################################################################################
	# Path to OVF
	$ovfPath = "VMware-Appliance-FaH_1.0.0.ova"
	###############################################################################################
	## MUST BE A VCENTER - ESXI HOSTS WILL NOT WORK ##
	# vCenter Credentials
	$viserver = @{
			"Server" = "vcenter01.lab.corp.local"
			"User" = "administrator@vsphere.local"
			"Password" = "VMware1!"
			# "Credentials" = $myCreds
	}
	###############################################################################################
	# Basic Deployment Environment Details
	$esxi_deployer_hostname = "esxi01.lab.corp.local" # esxi host FQDN or IP
	$datastore_name = "SSD_SHARE"
	$network_name = "VM Network"
	$vm_num_cpu = "MATCH" # Needs to be MATCH or a number
	$vm_memory_gb = 1 # Needs to be match or a number (will max @ 4 GB)
	###############################################################################################
	# Basic Guest Details
	## By Default: Guest Hostname and VM will have the same exact name.
	$guest_hostname = "fahclient0"
	$guest_root_password = "VMware1!"
	###############################################################################################
	# Basic Folding@Home Details
	$fah_username = "user"
	$fah_team = "52737"
	$fah_passkey = ""
	$fah_mode = "full" # Needs to be light, medium, full
	$fah_gpu = $false # Or $true
	###############################################################################################
	### OPTIONAL PARAMETERS ###
	###############################################################################################
	# Optional Deployment Environment Details
	## VM Name if you don't want the guest hostname to match the VM name
	$vm_name = ""
	###############################################################################################
	# Optional Guest Details
	## IP Address Details - Leave Empty for DHCP
	$guest_ip_address = "192.168.1.242"
	$guest_netmask = "24 (255.255.255.0)" # Probably should be "24 (255.255.255.0)" if you'resetting manually
	$guest_gateway = "192.168.1.254"
	## DNS, Domain, and NTP Details
	$guest_dns = "192.168.1.254"
	$guest_domain = "lab.corp.local"
	$guest_ntp = "pool.ntp.org"
	## Proxy Details
	$guest_http_proxy = ""
	$guest_https_proxy = ""
	$guest_no_proxy = ""
	$guest_proxy_username = ""
	$guest_proxy_password = ""
	###############################################################################################
	# Optional Folding@Home Details
	## What networks can you view this specific client on (https://<ip>:7396)
	$fah_web_remote_networks = "192.168.1.0/24"
	## Which Networks can a FAHControl see this specific Client? (Port: 36330)
	$fah_remote_networks = "192.168.1.0/24"
	## What password do you want to limit network communication with?
	$fah_remote_pass = "VMware1!"
	###############################################################################################

	###############################################################################################
	################################# DO NOT EDIT BELOW THIS LINE #################################
	###############################################################################################
	# What will this VM actually be named?
	if($vm_name.Trim().Length -gt 0) {
		$actual_vm_name =  $vm_name
	}
	else {
		$actual_vm_name =  $guest_hostname
	}
	###############################################################################################
	# Double Check those Octets!
	Validate-CIDR-Mask -CIDRMask $guest_netmask
	###############################################################################################
	# Double Check the folding at home Mode
	Validate-FAH-Mode -FahMode $fah_mode
	###############################################################################################
	# Establish Connection to vCenter
	$singleton = Disconnect-VIServer $viserver['Server'] -Confirm:$false
	$connection = Connect-ViServer @viserver
	# If the connection is valid
	if($connection) {
		Write-Host ("Connected to " + $viserver["Server"])
		try {
			# Collect all of the necessary changes to the VM before power-on
			Write-Host "Customizing VM: $actual_vm_name"
			Write-Host "    Guest Hostname: $guest_hostname"
			Write-Host "    Guest Root Password Set"
			$ovfPropertyChanges = @{
				"guestinfo.hostname" = $guest_hostname
				"guestinfo.root_password" = $guest_root_password
			}

			# Customize the appliance!
			if($guest_ip_address -ne "") {
				Write-Host "    Static IP Address Set"
				Write-Host "        $guest_ip_address"
				Write-Host "        $guest_netmask"
				Write-Host "        $guest_gateway"
				$ovfPropertyChanges["guestinfo.ipaddress"] = ${guest_ip_address}
				$ovfPropertyChanges["guestinfo.netmask"] = ${guest_netmask}
				$ovfPropertyChanges["guestinfo.gateway"] = ${guest_gateway}

				if(${guest_dns}.Trim().Length -eq 0){ throw "Error! You need to provide DNS if you specify an IP" }
			}
			if($guest_dns -ne "") {
				Write-Host "    Custom DNS: $guest_dns"
				$ovfPropertyChanges["guestinfo.dns"] = ${guest_dns}
			}

			# Custom Domain
			if($guest_domain -ne "") {
				Write-Host "    Domain: $guest_domain"
				$ovfPropertyChanges["guestinfo.domain"] = ${guest_domain}
			}

			# NTP
			if($guest_domain -ne "") {
				Write-Host "    NTP: $guest_ntp"
				$ovfPropertyChanges["guestinfo.ntp"] = ${guest_ntp}
			}

			# Proxy Info
			if(($guest_http_proxy -ne "") -or ($guest_https_proxy -ne "")) {
				Write-Host "    Http Proxy: $guest_http_proxy"
				Write-Host "    Https Proxy: $guest_https_proxy"
				$ovfPropertyChanges["guestinfo.http_proxy"] = ${guest_http_proxy}
				$ovfPropertyChanges["guestinfo.https_proxy"] = ${guest_https_proxy}
				if($guest_proxy_username -ne "") {
					Write-Host "    Http(s) Proxy Username: $guest_proxy_username"
					Write-Host "    Http(s) Proxy Password set"
					$ovfPropertyChanges["guestinfo.proxy_username"] = ${guest_proxy_username}
					$ovfPropertyChanges["guestinfo.proxy_password"] = ${guest_proxy_password}
				}
				if($guest_no_proxy -ne "") {
					Write-Host "    Http No Proxy: $guest_no_proxy"
					$ovfPropertyChanges["guestinfo.no_proxy"] = ${guest_no_proxy}
				}
			}

			Write-Host ""
			Write-Host "Setting Folding@Home Details:"
			Write-Host "    F@H Username: $fah_username"
			Write-Host "    F@H Team: $fah_team"
			Write-Host "    F@H Passkey Set"
			Write-Host "    F@H Mode: $fah_mode"
			Write-Host "    F@H Using GPU? $fah_gpu"
			$ovfPropertyChanges["guestinfo.fah_username"] = ${fah_username}
			$ovfPropertyChanges["guestinfo.fah_team"] = ${fah_team}
			$ovfPropertyChanges["guestinfo.fah_passkey"] = ${fah_passkey}
			$ovfPropertyChanges["guestinfo.fah_mode"] = ${fah_mode}

			# $gpu = Get-VMHostPciDevice -VMHost $esxi_deployer_hostname -DeviceClass "DisplayController"
			# $gpu.VendorName
			$ovfPropertyChanges["guestinfo.fah_gpu"] = ${fah_gpu}

			# Remote FAH Web Client
			if($fah_web_remote_networks -ne "") {
				Write-Host "    Allowed Networks to access F@H web: $fah_web_remote_networks"
				$ovfPropertyChanges["guestinfo.fah_web_remote_networks"] = ${fah_web_remote_networks}
			}

			# Remote FAHControl
			if($fah_remote_networks -ne "") {
				Write-Host "    Allowed Networks to access FAHControl: $fah_remote_networks"
				$ovfPropertyChanges["guestinfo.fah_remote_networks"] = ${fah_remote_networks}

				# Remote Passkey
				if($fah_remote_pass -ne "") {
					Write-Host "    F@H Remote Passkey Set"
					$ovfPropertyChanges["guestinfo.fah_remote_pass"] = ${fah_remote_pass}
				}
			}
			# Deploy the actual appliance.
			$vm = Deploy-FAH -OvfPath ${ovfPath} -VMName ${actual_vm_name} -EsxiHostName ${esxi_deployer_hostname} -DatastoreName ${datastore_name} -NumCpu ${vm_num_cpu} -MemoryGB ${vm_memory_gb}
			$ovfset = Set-VMOvfProperty -VM $vm -ovfChanges $ovfPropertyChanges
			$netset = Set-VMNetwork -VM $vm -NetworkName $network_name
			$startvm = Start-VM -VM $vm -Confirm:$false
		}
		finally {
			Disconnect-ViServer -Server $connection -Confirm:$false
		}
	}
}
Main
