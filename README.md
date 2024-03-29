# Update-PRTGLECert
This script uses Posh-ACME and Let's Encrypt to update the SSL certificate used in PRTG
## How To Use:

### First Time Setup

If running Windows 2012 / Windows 2012 R2, you must first install PowerShell 5.1, available at [https://aka.ms/WMF5Download](https://aka.ms/WMF5Download). Also make sure .NET Framework 4.7.1 or greater is installed (available at [https://www.microsoft.com/en-us/download/details.aspx?id=56116](https://www.microsoft.com/en-us/download/details.aspx?id=56116)).  If installed, a reboot is required.

For Windows 2012 R2 and Windows 2016, set TLS to 1.2.  
Run command 
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

#### PowerShell version

This script is designed to run on PowerShell 5.1 or greater.  There have been issues on some PowerShell Core, so it is recommended not to use PowerShell Core at this time.  

#### Install Posh-ACME module

Run command to install Posh-ACME:
```powershell
Install-Module -Name Posh-ACME -Scope AllUsers -AcceptLicense
```

#### Request initial certificate
The script is designed to handle the renewals automatically, so you need to request the initial certificate manually.  In PowerShell:

```powershell
New-PACertificate -Domain sts.example.com -AcceptTOS -Contact me@example.com -DnsPlugin Cloudflare -PluginArgs @{CFAuthEmail="me@example.com";CFAuthKey='xxx'}

# After the above completes, run the following
$MainDomain = 'prtg.example.com'

# the '-UseExisting' flag is useful when the certifcate is not yet expired
./Update-PRTGLECert.ps1 -MainDomain $MainDomain -UseExisting
```
### Normal Use
To normally run it with the '-MainDomain' parameter:

```powershell
./Update-PRTGLECert.ps1 -MainDomain $MainDomain
```
or run it without the '-MainDoman' parameter:
```powershell
./Update-PRTGLECert.ps1
```

### Force Renewals

You can force a renewal with the '-ForceRenew' switch and with the '-MainDomain' parameter:

```powershell
./Update-PRTGLECert.ps1 -MainDomain $MainDomain -ForceRenew
```
or you can force a renewal with the '-ForceRenew' switch and without the '-MainDomain' parameter:
```powershell
./Update-PRTGLECert.ps1 -ForceRenew
```
### Other Notes

#### Single Posh-ACME account required on the server

This script makes the assumption that there will only be one Posh-ACME account installed on the server.  If for some reason more than one account exists, then the logic will break and the script will not complete.  If more than one Posh-ACME account exists, please manually remove non-relevant accounts until only a single Posh-ACME account directory exists on the system.

#### MainDomain option parameter

The '-MainDomain' parameter is optional.  The script will parse the directory to determine FQDN and the Posh-ACME account number and version.  If '-Main Domain' is included, then a consistency check is performed to verify the FQDN matches the value provided.

#### Switch Mutual Exclusivity

The '-ForceRenew' and '-UseExisting' switches are mutually exclusive, with '-UseExisting' superceeding '-ForceRenew'.

#### Logging

This script is set to automatically log the process and create a persistent log file in the same directory the script is located.  The name of the log file is UpdatePRTG.log

### PRTG-LetsEncrypt-Renewal.xml

To use the provided Task Scheduler XML file, you will need to create the folder in C:\Scripts and place the file Update-PRTGCert.ps1 inside it.  If you choose to locate the Update-PRTGCert.ps1 file elsewhere, then modify the scheduled task location 'Start in'.

This XML file is a sample scheduled task that can be imported into the Windows Task Scheduler to handle the automatic renewal process.  There are a few modifications that will need to be made following the import:
- General Tab
    - Change User or Group
        - Use administrator account, either local or domain
- Triggers
    - Change date / time (optional)
- Actions
    - Edit Task
        - Add arguments
            - Change prtg.example.com to FQDN of PRTG server
        - Start in
            - Replace with path of actual location of the script

