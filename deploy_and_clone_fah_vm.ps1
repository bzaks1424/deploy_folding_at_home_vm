. .\VMW_FAH_LIB.ps1

function Main {
	###############################################################################################
	# Path to OVF
	$ovfPath = "VMware-Appliance-FaH_1.0.0.ova"
	$csvPath = "multi-fah-deploy.csv"
	###############################################################################################
	## MUST BE A VCENTER - ESXI HOSTS WILL NOT WORK ##
	# vCenter Credentials
	$viserver = @{
			"Server" = "vcenter01.lab.michaelpmcd.com"
			"User" = "administrator@vsphere.local"
			"Password" = "VMware1!"
			# "Credentials" = $myCreds
	}
	###############################################################################################
	# Basic Deployment Environment Details
	$esxi_deployer_hostname = "esxi01.lab.michaelpmcd.com" # esxi host FQDN or IP
	$datastore_name = "SSD_SHARE"
	$network_name = "VM Network"
	$vm_num_cpu = "MATCH" # Needs to be MATCH or a number
	$vm_memory_gb = 1 # Needs to be match or a number (will max @ 4 GB)
	## What the template will be named at deploy
	$template_name = "VMW_FAH Template"
	###############################################################################################
	# Basic Guest Details
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
	# Optional Guest Details
	## DNS, Domain, and NTP Details
	$guest_dns = "192.168.1.254"
	$guest_domain = "lab.michaelpmcd.com"
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

	###############################################################################################
	# Validate the existence of the CSV
	if( -not (Test-Path $csvPath)) {
		throw ("ERROR! Cannot find CSV in '$csvPath'")
	}
	# Double Check the folding at home Mode
	$good_fah_modes = ('light', 'medium', 'full')
	if( -not ($good_fah_modes -match $fah_mode)) {
		throw ("ERROR! Invalid Folding@Home Operating Mode ($fah_mode)! Must be 'light', 'medium' or 'full'")
	}
	###############################################################################################
	# Establish Connection to vCenter
	$connection = Connect-ViServer @viserver
	# If the connection is valid
	if($connection) {
		Write-Host ("Connected to " + $viserver["Server"])
		try {
			Write-Host "Deploying Template: ${template_name} to ${esxi_deployer_hostname}"
			$template = Get-VM ${template_name} -ea SilentlyContinue
			if(!$template){
				$template = Deploy-FAH -OvfPath ${ovfPath} -VMName ${template_name} -EsxiHostName ${esxi_deployer_hostname} -DatastoreName ${datastore_name} -NumCpu ${vm_num_cpu} -MemoryGB ${vm_memory_gb}
			}
			$vms_to_deploy = Import-Csv -Path $csvPath
			foreach($vtd in $vms_to_deploy){
				if($vtd.Hostname -eq $null) { throw "ERROR! Cannot have a VM without a Hostname!" }
				$actual_vm_name = $vtd.Hostname
				if($vtd."[VM Name]" -ne $null) { $actual_vm_name =  $vtd."[VM Name]" }

				# Don't reclone the VM if you don't have to - fix the data and pick up where you left off.
				$vm = Get-VM -Name $actual_vm_name -ea SilentlyContinue
				if(!$vm) {
					$vm = New-VM -VM $template -Name $actual_vm_name -VMHost ${esxi_deployer_hostname}
				}
				if($vm.PowerState -eq "PoweredOn") { continue }
				#
				# Collect all of the necessary changes to the VM before power-on
				Write-Host "Customizing VM: $actual_vm_name"
				Write-Host ("    Guest Hostname: " + $vtd.Hostname)
				Write-Host "    Guest Root Password Set"
				$ovfPropertyChanges = @{
				  "guestinfo.hostname" = $vtd.Hostname
				  "guestinfo.root_password" = $guest_root_password
				}
				# Customize the appliance!
				if($vtd."[IP Address]" -ne $null -and $vtd."[IP Address]".Trim().Length -gt 0) {
					$guest_ip_address = $vtd."[IP Address]"
					$guest_netmask = $vtd."[CIDR (Netmask)]"
					$guest_gateway = $vtd."[Gateway]"
				  Write-Host "    Static IP Address Set"
				  Write-Host ("        $guest_ip_address")
				  Write-Host ("        $guest_netmask")
				  Write-Host ("        $guest_gateway")
				  # Double Check those Octets!
					Validate-CIDR-Mask -CIDRMask $guest_netmask
				  $ovfPropertyChanges["guestinfo.ipaddress"] = ${guest_ip_address}
				  $ovfPropertyChanges["guestinfo.netmask"] = ${guest_netmask}
				  $ovfPropertyChanges["guestinfo.gateway"] = ${guest_gateway}

				  if(${guest_dns}.Trim().Length -eq 0) { throw "Error! You need to provide DNS if you specify an IP" }
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
				#
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
				$ovfset = Set-VMOvfProperty -VM $vm -ovfChanges $ovfPropertyChanges
				$netset = Set-VMNetwork -VM $vm -NetworkName $network_name
				$startvm = Start-VM -VM $vm -Confirm:$false
			}
		}
		finally {
			Disconnect-ViServer -Server $connection -Confirm:$false
		}
	}
}


Main
