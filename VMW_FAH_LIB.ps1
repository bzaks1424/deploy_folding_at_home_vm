Function Deploy-FAH {
<#
	.NOTES
	===========================================================================
	 Created by:    Michael McDonnell
	 Organization:  VMware
	 Twitter:       @bzaks1424
	===========================================================================
	.DESCRIPTION
			This function will deploy the FoldingAtHome OVA to your ESXi Host or vCenter
	.PARAMETER OvfPath
			The path to the OVA on your filesystem
	.PARAMETER VMName
			The name you'd like your OVA deployed as.
	.PARAMETER EsxiHostName
			The Name of the VMHost that will be used to deploy. Should have the appropriate storage and network attached.
	.PARAMETER DatastoreName
			The Datastore that will be used to deploy. Should be attached to the aforementioned EsxiHostName
	.PARAMETER NumCpu
			The number of CPUs this VM will have.
	.PARAMETER MemoryGB
			The amount of RAM allocated to this VM (Will Max at 4 GB - anything more is unnecessary)
	.EXAMPLE
			Deploy-FAH-VM -OvfPath "C:\VMware-Appliance-FaH_1.0.0.ova" -VMName "MyFAHVM" -EsxiHostName "esxi01.corp.local" -DatastoreName "mydatastore" -NumCpu "MATCH" -MemoryGB 1
#>
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$OvfPath,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$VMName,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$EsxiHostName,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$DatastoreName,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$NumCpu,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$MemoryGB
	)
	# Double Check that the OVF Actually Exists
	if( -not (Test-Path $OvfPath)) {
		throw ("ERROR! Cannot find OVA or OVF in '$OvfPath'")
	}
	# Doublecheck we can find the VMHost
	$vmhost = Get-VMHost -Name $EsxiHostName
	# Doublecheck we can find the Datastore and that its attached to VMHost
	$ds = Get-Datastore -Name $DatastoreName -VMHost $vmhost -ea SilentlyContinue
	if(!$ds) {
		throw "Cannot find $DatastoreName attached to $EsxiHostName"
	}
	Write-Host "Deploying VM $VMName"
	Write-Host "    VMHost: $EsxiHostName"
	Write-Host "    Datastore: $DatastoreName"
	# Import the vm
	$vm = Get-VM -Name $VMName -ea SilentlyContinue
	if(!$vm){
		$vm = Import-VApp $OvfPath -VMHost $vmhost -Datastore $ds -Name $VMName -Confirm:$false
	}
	elseif($vm.PowerState -eq "PoweredOn") {
		throw "Error! $VMName already exists and is Powered On in inventory!"
	}

	return Set-VMSize -VM $vm -NumCpu $NumCpu -MemoryGB $MemoryGB

}

Function Set-VMSize
{
	<#
		.NOTES
		===========================================================================
		 Created by:    Michael McDonnell
		 Organization:  VMware
		 Twitter:       @bzaks1424
		===========================================================================
		.DESCRIPTION
				This function will deploy the FoldingAtHome OVA to your ESXi Host or vCenter
		.PARAMETER VM
				VM object returned from Get-VM
		.PARAMETER NumCpu
				The number of CPUs this VM will have.
		.PARAMETER MemoryGB
				The amount of RAM allocated to this VM (Will Max at 4 GB - anything more is unnecessary)
		.EXAMPLE
				Set-VMSize -VMName $myVM -NumCpu "MATCH" -MemoryGB 1
	#>
		[CmdletBinding()]
		Param
		(
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			$VM,

			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			$NumCpu,

			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			$MemoryGB
		)
		# Validate VM Sizing Parameters
		$max_num_cpu = $vmhost.NumCpu
		if($vmhost.HyperthreadingActive) {
			$max_num_cpu = $max_num_cpu * 2
		}
		$NumCpu = Set-HWValue $NumCpu $max_num_cpu $max_num_cpu
		if($NumCpu -lt 16){
			$max_memory_gb = 1
		}
		else {
			$max_memory_gb = 4
		}
		$MemoryGB = Set-HWValue $MemoryGB  $vmhost.MemoryTotalGB $max_memory_gb
		Write-Host "Sizing VM: $VMName"
		Write-Host "    CPUs: $NumCpu"
		Write-Host "    MemoryGB: $MemoryGB"
		# Size the VM
		return Set-VM -VM $vm -MemoryGB $MemoryGB -NumCpu $NumCpu -Confirm:$false
}

Function Set-VMNetwork {
	<#
		.NOTES
		===========================================================================
		 Created by:    Michael McDonnell
		 Organization:  VMware
		 Twitter:       @bzaks1424
		===========================================================================
		.DESCRIPTION
				This function will deploy the FoldingAtHome OVA to your ESXi Host or vCenter
		.PARAMETER VM
				VM object returned from Get-VM
		.PARAMETER NetworkName
				The Datastore that will be used to deploy. Should be attached to the aforementioned EsxiHostName
		.EXAMPLE
			Set-VMNetwork -VM $myVM -NetworkName "My VM Network"

	#>
		[CmdletBinding()]
		Param
		(
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			$VM,

			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			$NetworkName
		)

		$net = Get-VirtualNetwork -Name $NetworkName
		if($net.Length -ne 1) {
			throw ("ERROR! Invalid number of networks found when searching $NetworkName (" + $net.Length + ") should be 1!")
		}
		$setSplat = @{}
		if($net.NetworkType -eq "Distributed") {
			$setSplat["Portgroup"] = (Get-VDPortgroup -Name $NetworkName)
		}
		else{
			$setSplat["NetworkName"] = $NetworkName
			$setSplat["StartConnected"] = $true
		}
		$set = Set-NetworkAdapter -NetworkAdapter (Get-NetworkAdapter -VM $VM) @setSplat -Confirm:$false

		return Get-VM $VM
}

Function Set-HWValue($Value, $Comparator, $Max){
	if($Max -gt $Comparator) {
		$Max = $Comparator
	}
	if(($Value -like "MATCH") -or ($Value -gt $Max)) {
		$Value = $Max
	}
	else {
		$Value = 1
	}
	return $Value
}

Function Set-VMOvfProperty {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function updates the OVF Properties (vAppConfig Property) for a VM
    .PARAMETER VM
        VM object returned from Get-VM
    .PARAMETER ovfChanges
        Hashtable mapping OVF property ID to Value
    .EXAMPLE
        $VMNetwork = "sddc-cgw-network-1"
        $VMDatastore = "WorkloadDatastore"
        $VMNetmask = "255.255.255.0"
        $VMGateway = "192.168.1.1"
        $VMDNS = "192.168.1.254"
        $VMNTP = "50.116.52.97"
        $VMPassword = "VMware1!"
        $VMDomain = "vmware.local"
        $VMSyslog = "192.168.1.10"

        $ovfPropertyChanges = @{
            "guestinfo.syslog"=$VMSyslog
            "guestinfo.domain"=$VMDomain
            "guestinfo.gateway"=$VMGateway
            "guestinfo.ntp"=$VMNTP
            "guestinfo.password"=$VMPassword
            "guestinfo.hostname"=$VMIPAddress
            "guestinfo.dns"=$VMDNS
            "guestinfo.ipaddress"=$VMIPAddress
            "guestinfo.netmask"=$VMNetmask
        }

        Set-VMOvfProperty -VM (Get-VM -Name "vesxi65-1-1") -ovfChanges $ovfPropertyChanges
#>
    param(
        [Parameter(Mandatory=$true)]$VM,
        [Parameter(Mandatory=$true)]$ovfChanges
    )

    # Retrieve existing OVF properties from VM
    $vappProperties = $VM.ExtensionData.config.vAppConfig.Property

    # Create a new Update spec based on the # of OVF properties to update
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.vAppConfig = New-Object VMware.Vim.VmConfigSpec
    $propertySpec = New-Object VMware.Vim.VAppPropertySpec[]($ovfChanges.count)

    # Find OVF property Id and update the Update Spec
    foreach ($vappProperty in $vappProperties) {
        if($ovfChanges.ContainsKey($vappProperty.Id)) {
            $tmp = New-Object VMware.Vim.VAppPropertySpec
            $tmp.operation = "edit"
            $tmp.info = New-Object VMware.Vim.VAppPropertyInfo
            $tmp.info.key = $vappProperty.Key
            $tmp.info.value = $ovfChanges[$vappProperty.Id]
            $propertySpec+=($tmp)
        }
    }
    $spec.VAppConfig.Property = $propertySpec

    Write-Host "Updating OVF Properties ..."
    $task = $vm.ExtensionData.ReconfigVM_Task($spec)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task
		return Get-VM $VM
}

Function Validate-CIDR-Mask {
  param(
      [Parameter(Mandatory=$true)]
      $CIDRMask
  )
  $octet = '25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}'
  if(($CIDRMask -ne $null) -and ($CIDRMask.Trim().Length -gt 0) -and ( -not ($CIDRMask -match "\d{1,2} \(($octet)\.($octet)\.($octet)\.($octet)\)"))) {
      throw ("ERROR! Invalid Netmask! '$CIDRMask' is not similar to 24 (255.255.255.0)")
  }
}
