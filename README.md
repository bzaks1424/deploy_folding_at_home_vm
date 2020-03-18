# Deploy Folding@Home VM PowerCLI Script

This is a basic script designed around deploying the VMware custom-made [Folding@Home PhotonOS OVA](http://veducate.co.uk/VMware-FaH-Appliance_1.0.0.ova)

Depending on how you want to deploy your appliance - you have a plethora of options. This README.md will take you through the various editable sections of the script.

## Path to OVF
The Path to the OVF is largely relative to the script. Just like any file - if can reference something directly in the directory its in.
**Example 1** - OVA is in same directory as deployment script:
> $ovfPath = "VMware-FaH-Appliance_1.0.0.ova" 

**Example 2** - OVA is in another directory all together.
> $ovfPath = "C:\my_magic_dir\VMware-FaH-Appliance_1.0.0.ova"

## vCenter Credentials
Due to the nature of one of our most important commands in the script [Get-OvfConfiguration]([https://code.vmware.com/docs/10197/cmdlet-reference/doc/Get-OvfConfiguration.html](https://code.vmware.com/docs/10197/cmdlet-reference/doc/Get-OvfConfiguration.html)), we have to connect to a vCenter.  As of today - that's a username and password. *Future revisions may make using Credentials easier.*

## Basic Deployment Environment Details
There are 3 primary deployment considerations to use when deploying an OVA / OVF.
 - Datastore
 - Deploy Host
The code will require you to specifically call out the appropriate Deploy Host (the host doing the work) and attached Datastore. 
*The code currently does not check your network name. Please confirm that manually.*
```
$esxi_deployer_hostname = "esxi01.lab.corp.local" # esxi host FQDN or IP
$datastore_name = "SHARE"
$network_name = "VM Network"
```
## Basic Guest Details
By default - giving a guest a hostname will also name that VM the same thing. You can modify the VM name in the Optional Deployment Environment Details. You also will want to set a default root password for your VM.
```
$guest_hostname = "vFAH01"
$guest_root_password = "VMware1!"
```

## Basic Folding@Home Details
These are your **personal** details for your Folding@Home. 

 - **$fah_username** is your personal username.
 - **$fah_team** is the team you're trying to Fold with. Obviously you want VMware: 52737
 - **$fah_passkey** is your [private passkey]([https://foldingathome.org/support/faq/points/passkey/](https://foldingathome.org/support/faq/points/passkey/)) provided to you by Folding@Home
 - **$fah_mode** is the mode at which you want to run your Folding@Home Client. It has 3 distinct options:
	 - light - Low CPU Utilization
	 - medium - Middling CPU Utilization
	 - full - 100% CPU whenever operating on a workload.
 - **$fah_gpu** asks if you want the VM to autodetect and utilize an attached GPU.
```
$fah_username = "MyUser"
$fah_team = "52737"
$fah_passkey = ""
$fah_mode = "medium" # Needs to be light, medium, full
$fah_gpu = $false # Or $true
```

## Optional Deployment Environment Details
If you don't want the guest hostname to match the VM name you can set that as an override right here.
```
$vm_name = ""
```
And if you want the deployment to run asynchronously
```
$run_async = $false
```

## Optional Guest Details
Leaving any of these details empty will just use defaults. (DHCP, DNS, NTP, and Proxy)
### IP Address Details
The only field worth calling out is the guest_netmask variable. If you're going to set that - it needs to be very specific. It needs to follow a standard format:
```
"<CIDR Number> (<NETMASK>)"
```
*The script does not check if the netmask matches the CIDR. That's up to you. [You can use a cheat sheet to help]([https://www.aelius.com/njh/subnet_sheet.html](https://www.aelius.com/njh/subnet_sheet.html))*

```
$guest_ip_address = "192.168.1.10"
$guest_netmask = "24 (255.255.255.0)"
$guest_gateway = "192.168.1.1"
```
### DNS, Domain, and NTP Details
```
$guest_dns = "1.1.1.1"
$guest_domain = "corp.local"
$guest_ntp = "pool.ntp.org"
```
### Proxy Details
```
$guest_http_proxy = "http://my_magic_proxy:8080/"
$guest_https_proxy = "https://my_magic_proxy:8443/"
$guest_no_proxy = "localhost, 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8"
$guest_proxy_username = "bzaks1424"
$guest_proxy_password = "VMware1!"
```


## Optional Folding@Home Details
Leaving any of these details empty will just use defaults. (No remote client connectivity, or web server)
Folding at home has some great built in security measures. 
You have the ability to limit web server from communicating directly with the VM. That webserver is hosted on port 7396.
```
$fah_web_remote_networks = "192.168.1.0/24, 10.1.1.2"
```
You also have the ability to prevent FAH control from communicating directly to the VMs over port 36330
```
$fah_remote_networks = "192.168.1.0/24, 10.1.1.2"
```
Finally - if you want to be ultra secure within your network - you can even limit who can communicate with a given client (VM). You can set a password for communication.
```
$fah_remote_pass = "VMware1!"
```
