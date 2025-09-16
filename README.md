# 🌐 Remote Monitoring Automation Script

## 📋 Overview

This PowerShell script automates the setup of:

- 🖥️ Logging configuration
- 🔍 Sysmon installation
- 📡 Splunk Universal Forwarder deployment

It is designed to run remotely on target machines where you have administrative access.

---

### ⚠️ Script Assumptions / Prerequisites

- PowerShell remoting is enabled on the remote system.
- You have administrative access on the target machine.
- This script assumes all required files are present and correctly placed. Missing files will cause deployment to fail.

---

## 📂 Required Files

Before running this script, place all required files in a single folder (`SourceFolder`).

| **File**                           | **Source / Instructions**                                                                 |
|------------------------------------|---------------------------------------------------------------------------------------|
| **Sysmon.exe**                     | Microsoft Sysinternals: [Download here](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon) |
| **sysmonconfig-export.xml**        | Example configuration from SwiftOnSecurity: [GitHub link](https://github.com/SwiftOnSecurity/sysmon-config) |
| **YamatoSecurityConfigureWinEventLogs.bat** | Get it directly from YamatoSecurity: [GitHub link](https://github.com/Yamato-Security/EnableWindowsLogSettings) |
| **outputs.conf**                   | Splunk UF config file – see notes below |
| **inputs.conf**                    | Splunk UF config file – see notes below |
| **SplunkForwarder.msi**            | Official Splunk: [Download here](https://www.splunk.com/en_us/download/universal-forwarder.html) |

💡 **Tip:** Instead of downloading files manually, you can run the helper script to fetch dependencies automatically:

```powershell
.\FetchDependencies.ps1 -Destination "C:\Path\To\SourceFolder"
```
👉 You’ll still need to manually download Splunk Forwarder from the official link above.

---

## 🚀 Setup

1. 🛠️ Enable PowerShell remoting on the target machine (if not already enabled).
2. 🔐 Ensure you have administrative rights on the remote machine.
3. 📂 Copy all required files into one folder (your `SourceFolder`).
4. ▶️ Run the deployment script:

```powershell
.\DeployMonitoring.ps1 -ComputerName TARGET -SourceFolder "C:\Path\To\SourceFolder"
```
---

## 📝 Configuration Notes
**inputs.conf**: Replace <YOUR_INDEX> with your desired Splunk index for logs.
Example:
```
index = <YOUR_INDEX>
```
**outputs.conf**: Replace <SPLUNK_INDEXER_IP> with your Splunk server IP.
These files act as templates; you can adjust as needed for your environment.
Example:
```
server = <SPLUNK_INDEXER_IP>:9997
```
These files act as templates; adjust them as needed for your environment.

---

## ✅ Expected Output
If the deployment succeeds, your console should show something like:
```
=== Starting deployment on <REMOTE-COMPUTER> ===
Step: CreateRemoteFolder, Status: Success
Step: SanityCheck, Status: Success
Step: LoggingScript, Status: Success
Step: SysmonInstallation, Status: Success
Step: SplunkForwarderInstallation, Status: Success
Step: Deploy_outputs.conf, Status: Success
Step: Deploy_inputs.conf, Status: Success
Cleaning up session...
```

---

## 🛠️ Notes

- The script automatically adjusts Sysmon event log permissions so SplunkForwarder can read them without manual intervention.
- Ensure all required files are present in `SourceFolder` before running.
- Missing or misnamed files will stop the deployment.
