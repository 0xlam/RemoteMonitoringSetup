param(
	[Parameter(Mandatory)]
	[string]$ComputerName,
	
	[Parameter(Mandatory)]
	[string]$SourceFolder #Folder containing all scripts and executables
	)

#Remote folder on target where deployment files will be staged	
$RemoteFolder = "C:\Windows\Temp\MonitoringSetup"
	
#Create a remote session to the target machine
$session = New-PSSession -ComputerName $ComputerName

try {
    Write-Host "=== Starting deployment on $ComputerName ==="

	# Step 1: Ensure the target folder exists on the remote system
	try {
	    $result = Invoke-Command -Session $session -ScriptBlock {
		param($folder)
		try {
		    if (-not (Test-Path -Path $folder)) {
		        #Create folder if missing
		        New-Item -Path $folder -ItemType Directory | Out-Null
		    }
		    return @{ Step="CreateRemoteFolder"; Status="Success" }
		} 
		catch {
		    # If folder creation fails, return error details
		    return @{ Step="CreateRemoteFolder"; Status="Failed"; Error=$_.Exception.Message }
		}

	    } -ArgumentList $RemoteFolder
	    
	    Write-Host "Step: $($result.Step), Status: $($result.Status)"
	    if ($result.Status -eq "Failed") {
			Write-Error $result.Error
			exit 1
	    	}
	} 
    
	catch {
	    # If Invoke-Command itself fails, stop immediately
	    Write-Error "Failed to create remote folder: $_"
	    exit 1
	}


	#Step 2: Copy all files from the local $SourceFolder into the remote $RemoteFolder (recursively, via session)
	Copy-Item -Path "$SourceFolder\*" -Destination $RemoteFolder -ToSession $session 

	# Sanity check: verify all required files exist on the remote machine before proceeding.
	# Uses exact filenames for static files, and a wildcard match for Splunk installer (splunkforwarder*.msi).
	# If any file is missing, the script stops here to avoid partial/broken setup.

	try {
	    $result = Invoke-Command -Session $session -ScriptBlock {
		param($folder)

		$expectedFiles = @(
		    "YamatoSecurityConfigureWinEventLogs.bat",
		    "Sysmon.exe",
		    "sysmonconfig-export.xml",
		    "outputs.conf",
		    "inputs.conf"
		)

		$missing = @()
		
		#Check Splunk installer (allow wildcard match)
		if (-not (Get-ChildItem -Path $folder -Filter "splunkforwarder*.msi" -File )) {
		    $missing += "splunkforwarder*.msi"
		}
		
		foreach ($file in $expectedFiles) {
		    $path = Join-Path $folder $file
		    if (-not (Test-Path $path)) {
		        $missing += $file
		    }
		}


		if ($missing.Count -eq 0) {
		    return @{ Step="SanityCheck"; Status="Success" }
		} 
		else {
		    return @{ Step="SanityCheck"; Status="Failed"; Missing=$missing -join ", " }
		}
		
		
	    } -ArgumentList $RemoteFolder

	    Write-Host "Step: $($result.Step), Status: $($result.Status)"
	    if ($result.Status -eq "Failed") {
			Write-Error "Missing files: $($result.Missing)"
			exit 1   # stop script if files aren’t all there
	    }

	} 

	catch {
	    Write-Error "Sanity check failed to run: $_"
	    exit 1
	}


	#Step 3: Run logging configuration script 
	try {
	    $result = Invoke-Command -Session $session -ScriptBlock {
		param($folder)
		try {
		    Start-Process "$folder\YamatoSecurityConfigureWinEventLogs.bat" -Wait 
		    return @{ Step="LoggingScript"; Status="Success" }
		} 
		catch {
		    return @{ Step="LoggingScript"; Status="Failed"; Error=$_.Exception.Message }
		}

	    } -ArgumentList $RemoteFolder
	    
	    Write-Host "Step: $($result.Step), Status: $($result.Status)"
	    if ($result.Status -eq "Failed") {
			Write-Error $result.Error
			exit 1
	    }

	}

	catch {
	    Write-Error "Invoke-Command itself failed (LoggingScript): $_"
	    exit 1
	}

	#Step 4: Install Sysmon
	try {
	    $result = Invoke-Command -Session $session -ScriptBlock {
		param($folder)
		try {
		    # Install Sysmon silently, accept EULA, and apply provided config
		    Start-Process "$folder\Sysmon.exe" -ArgumentList "-accepteula -i $folder\sysmonconfig-export.xml" -Wait
		    return @{ Step="SysmonInstallation"; Status="Success" }
		} 
		catch {
		    # Catch installation errors (e.g. missing exe/config or process launch failure)
		    return @{ Step="SysmonInstallation"; Status="Failed"; Error=$_.Exception.Message }
		}

	    } -ArgumentList $RemoteFolder # pass remote folder path into scriptblock
	     
	    Write-Host "Step: $($result.Step), Status: $($result.Status)"
	    if ($result.Status -eq "Failed") {
			Write-Error $result.Error
			exit 1
	    }
	}

	catch {
	    Write-Error "Invoke-Command itself failed (SysmonInstallation): $_"
	    exit 1
	}


	#Step 4: Install SplunkForwarder silently
	try {
	    $result = Invoke-Command -Session $session -ScriptBlock {
		param($folder)
		try {
		    $msi = Get-ChildItem -Path $folder -Filter "splunkforwarder*.msi" | Select-Object -First 1
		    if (-not $msi) { throw "SplunkForwarder MSI not found in $folder" }

		    Start-Process msiexec.exe -ArgumentList "/i `"$($msi.FullName)`" AGREETOLICENSE=YES /quiet /norestart" -Wait
		    return @{ Step="SplunkForwarderInstallation"; Status="Success" }
		} 

		catch {
		    return @{ Step="SplunkForwarderInstallation"; Status="Failed"; Error=$_.Exception.Message }
		}

	    } -ArgumentList $RemoteFolder

	    Write-Host "Step: $($result.Step), Status: $($result.Status)"
	    if ($result.Status -eq "Failed") {
			Write-Error $result.Error
			exit 1
	    }
	} 

	catch {
	    Write-Error "Invoke-Command itself failed (SplunkForwarderInstallation): $_"
	    exit 1
	}


	#Step 5: Deploy Splunk configuration files
	foreach ($conf in @("outputs.conf", "inputs.conf")) {
	    try {
			$result = Invoke-Command -Session $session -ScriptBlock {
			    param($folder, $file)
			    $possiblePaths = @(
	    				"C:\Program Files\SplunkUniversalForwarder",
	    				"C:\Program Files (x86)\SplunkUniversalForwarder"
					)

			    $installPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

	                    if (-not $installPath) {
	                        throw "Could not determine SplunkUniversalForwarder install path."
	                    }

			    $dest = Join-Path $installPath "etc\system\local"
			    Copy-Item -Path (Join-Path $folder $file) `
			            -Destination $dest -Force
			    return @{ Step="Deploy_$file"; Status="Success" }

		catch {
		    return @{ Step="Deploy_$file"; Status="Failed"; Error=$_.Exception.Message }
		}

		} -ArgumentList $RemoteFolder, $conf


		Write-Host "Step: $($result.Step), Status: $($result.Status)"
		if ($result.Status -eq "Failed") {
		    Write-Error $result.Error
		    exit 1
		}

	    }

	    catch {
			Write-Error "Invoke-Command itself failed (Deploy $conf): $_"
			exit 1
	    }
	}

	#Step 6: Adjust Sysmon event log permissions so SplunkForwarder can read them
	Invoke-Command -Session $session -ScriptBlock { 
	       $service = $null
	       for ($i = 0; $i -lt 5; $i++) {
                   $service = Get-Service -Name "SplunkForwarder" -ErrorAction SilentlyContinue
                   if ($service) { break }
                   Start-Sleep -Seconds 3
            }
            
            if (-not $service) { throw "SplunkForwarder service not found after retries." }
	        
	        if ($service) {
    		    $sid = (sc.exe showsid $service.Name | Where-Object {$_ -match "SERVICE SID"}) -replace "SERVICE SID:\s+",""
			}
		
			$ace = "(A;;0x1;;;$sid)"
			# Get current SDDL
			$oldSDDL = (wevtutil gl Microsoft-Windows-Sysmon/Operational | Select-String "channelAccess").ToString()
			# Append new ACE
			$newSDDL = ($oldSDDL + $ace) -replace "channelAccess:\s+",""
			# Apply it
			wevtutil sl Microsoft-Windows-Sysmon/Operational /ca:"$newSDDL"
			
			Restart-Service SplunkForwarder
			}
}

finally {
	if ($session){
	    Write-Host "Cleaning up session..."
            Remove-PSSession $session
	}
}
