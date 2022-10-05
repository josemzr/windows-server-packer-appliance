# William Lam
# www.virtuallyghetto.com
# Sample Network Customization script for Windows Server 2016 + Active Directory Domain join

$customizationRanFile = "C:\ran_customization"
$customizationLogFile = "C:\customization-log.txt"

if(! (Test-Path -LiteralPath $customizationRanFile)) {
    "Customization Started @ $(Get-Date)" | Out-File -FilePath $customizationLogFile

    $EthernetInterfaceAliasName = "Ethernet0"
    $VMwareToolsExe = "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe"

    [xml]$ovfEnv = & $VMwareToolsExe --cmd "info-get guestinfo.ovfEnv" | Out-String
	
	$vmIP = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*ipaddress*' } | select -expand value
    $vmNetmask = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*netmask*' } | select -expand value
    $vmGW = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*gateway*' } | select -expand value
    $vmHostname = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*hostname*' } | select -expand value
    $vmDNS = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*dns*' } | select -expand value
	$vmAdminPass = $ovfEnv.Environment.PropertySection.Property | ?{ $_.key -like '*adminpass*' } | select -expand value
	
	$vmADDomain = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*ad_domain*' } | select -expand value
	$vmADUsername = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*ad_username*' } | select -expand value
	$vmADPassword = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*ad_password*' } | select -expand value
	
	# Sanitized inputs
	# VM IP Address will have the slash removed (it is specified later as netmask)
	# VM Netmask prefix will get the two caracters from the ovfEnv guestinfo.netmask string
	# VM DNS will replace spaces with commas, to later feed it to the Set-DnsClientServerAddress powershell command.
	
	$vmIP_SAN = $vmIP.split('/')[0]
	$vmNetmaskPrefix_SAN = $vmNetmask.split('(')[0]
	$vmGW_SAN = $vmGW.split('/')[0]
	$vmDNS_SAN = $vmDNS -replace(" ",",")
	$vmADUsername_SAN = $vmADUsername.split('\')[1]
	
	Write-Host $vmIP_SAN
	Write-Host $vmNetmaskPrefix_SAN
	Write-Host $vmHostname
	Write-Host $vmGW_SAN
	Write-Host $vmDNS_SAN
	Write-Host $vmAdminPass
	Write-Host $vmADUsername_SAN
	Write-Host $vmADDomain
	Write-Host $vmADPassword
	
	# If hostname is not specified, VM will use DHCP. If it is specified, then it is mandatory to use static IP.
	# vCenter OVFEnv will leave a blank ("") string when not specifying a parameter. However, ESXi leaves the parameter as null. Therefore it is necessary to consider that case as well.
    if(($vmHostname -ne "") -and ($vmHostname -ne "null")){

        # Rename Computer & Description to match Hostname
        "Renaming Computer Name and Description to $vmHostname" | Out-File -FilePath $customizationLogFile -Append
        Rename-Computer -NewName $vmHostname | Out-File -FilePath $customizationLogFile -Append
        Get-CimInstance -ClassName Win32_OperatingSystem | Set-CimInstance -Property @{Description = $vmHostname} | Out-File -FilePath $customizationLogFile -Append

        # Configure Networking
        "Configuring IP Address to $vmIP_SAN" | Out-File -FilePath $customizationLogFile -Append
        "Configuring Netmask Prefix to $vmNetmaskPrefix_SAN" | Out-File -FilePath $customizationLogFile -Append
        "Configuring Gateway to $vmGW_SAN" | Out-File -FilePath $customizationLogFile -Append
        New-NetIPAddress –InterfaceAlias $EthernetInterfaceAliasName -AddressFamily IPv4 –IPAddress $vmIP_SAN –PrefixLength $vmNetmaskPrefix_SAN_SAN | Out-File -FilePath $customizationLogFile -Append
        New-NetRoute -DestinationPrefix 0.0.0.0/0 -InterfaceAlias $EthernetInterfaceAliasName -NextHop $vmGW_SAN | Out-File -FilePath $customizationLogFile -Append

        # Configure DNS
        "Configuring DNS to $vmDNS_SAN" | Out-File -FilePath $customizationLogFile -Append
        Set-DnsClientServerAddress -InterfaceAlias $EthernetInterfaceAliasName -ServerAddresses $vmDNS_SAN | Out-File -FilePath $customizationLogFile -Append
        # Sleep to ensure DNS changes go into effect for AD Join
        Start-Sleep -Seconds 5
		
		
		# Change local Administrator password
		if($vmAdminPass -ne "" -and $vmAdminPass -ne "null"){
			"Changing Administrator Password..." | Out-File -FilePath $customizationLogFile -Append
			$SecurevmAdminPass = ConvertTo-SecureString -AsPlainText -Force $vmAdminPass
			Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $SecurevmAdminPass
			
			#Configure auto-login for the provided credentials
			$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
			Set-ItemProperty $RegistryPath 'AutoAdminLogon' -Value "1" -Type String 
			Set-ItemProperty $RegistryPath 'DefaultUsername' -Value "Administrator" -type String 
			Set-ItemProperty $RegistryPath 'DefaultPassword' -Value "$vmAdminPass" -type String
		}
		
        # Configure Active Directory. All properties must be filled in (and they must not be blank or null, to account for ESXi. See note above)
        if($vmADDomain -ne "" -and $vmADDomain -ne "null" -and $vmADUsername_SAN -ne "" -and $vmADUsername_SAN -ne "null" -and $vmADPassword -ne "" -and $vmADPassword -ne "null") {
            $joinCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
                UserName = $vmADUsername_SAN + "@" + $vmADDomain
                Password = (ConvertTo-SecureString -String $vmADPassword -AsPlainText -Force)[0]
            })
            "Joining Active Directory Domain $vmADDomain" | Out-File -FilePath $customizationLogFile -Append
            Add-Computer -NewName $vmHostname -Domain $vmADDomain -Credential $joinCred -Restart | Out-File -FilePath $customizationLogFile -Append
        }
		
		# Reboot system to apply hostname changes
		#shutdown /r /t 5 /c "Rebooting system to apply guest customizations..."
    } else {
        "No OVF Properties were found, defaulting to DHCP for networking" | Out-File -FilePath $customizationLogFile -Append
    }

    # Create ran file to ensure we do not run again
	Out-File -FilePath $customizationRanFile
}
