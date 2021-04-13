<#
.SYNOPSIS
This is a simple Powershell script to update PRTG SSL certificate with a LetsEncrypt cert

.DESCRIPTION
This script uses the Posh-Acme module to RENEW a LetsEncrypt certificate, and then applies it to PRTG. This is designed to be ran consistently, and will not update the cert if Posh-Acme hasn't been setup previously.

.EXAMPLE
./Update-PRTGLECert.ps1 -MainDomain prtg.example.com

.NOTES
This requires Posh-Acme to be preconfigured. The easiest way to do so is with the following command:
    New-PACertificate -Domain fg.example.com,fgt.example.com,vpn.example.com -AcceptTOS -Contact me@example.com -DnsPlugin Cloudflare -PluginArgs @{CFAuthEmail="me@example.com";CFAuthKey='xxx'}

.LINK
https://github.com/northeastnebraskanetworkconsortium/Update-PRTGLECert
#>

Param(
    [string]$MainDomain,
    [switch]$UseExisting,
    [switch]$ForceRenew
)

function Logging {
    param([string]$Message)
    Write-Host $Message
    $Message >> $LogFile
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module PKI
Import-Module Posh-Acme
$LogFile = '.\UpdatePRTG.log'
Get-Date | Out-File $LogFile -Append

# Get Posh version, account number and FQDN of certificate, which will build the path to the new certificates
$PoshVersion = (Get-ChildItem -Path ~\AppData\Local\Posh-ACME -Attributes Directory).Name
$AccountNumber = (Get-ChildItem -Path ~\AppData\Local\Posh-ACME\$PoshVersion -Attributes Directory).Name
$Domain  = (Get-ChildItem -Path ~\AppData\Local\Posh-ACME\$PoshVersion\$AccountNumber -Attributes Directory).Name
Logging -Message "PoshVersion:$PoshVersion, AccountNumber:$AccountNumber, Domain:$Domain"

# Sets the domain if not previously passed and verifies that if previously passed it matches what actually exists on the server
if(!$MainDomain) {
    Logging -Message "MainDomain parameter not passed.  Setting based on directory structure: $($Domain)"
    $MainDomain = $Domain
}elseif($MainDomain -ne $Domain){
    Logging -Message "ERROR--Passed FQDN does not match computed FQDN. Exiting script"
    Exit
}

# Tests if to use an existing certificate.  If not, tests if a renewal is forced.  If not, a standard renew occurs.
if($UseExisting) {
    Logging -Message "Using Existing Certificate"
    $cert = get-pacertificate -MainDomain $MainDomain
}
else {
    if($ForceRenew) {
        Logging -Message "Starting Forced Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain -Force
    }
    else {
        Logging -Message "Starting Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain
    }
    Logging -Message "...Renew Complete!"
}

if($cert){
    #Imports certificate for easy access for the future. This step is actually not required
    Logging -Message "Importing certificate to Cert:\LocalMachine\My"
    Import-PfxCertificate -FilePath $cert.PfxFullChain -CertStoreLocation Cert:\LocalMachine\My -Password ('poshacme' | ConvertTo-SecureString -AsPlainText -Force)

    # In PRTG, removes previous backed up certificate values
    Logging -Message "Remove previous old cert information"
    Remove-Item 'C:\Program Files (x86)\PRTG Network Monitor\cert\*original*.*'

    # In PRTG, creates new backups by moving the previous certificate values to become the new backups    
    Logging -Message "Rename previous cert to old"
    Rename-Item 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.crt' 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg-original.crt'
    Rename-Item 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.key' 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg-original.key'
    Rename-Item 'C:\Program Files (x86)\PRTG Network Monitor\cert\root.pem' 'C:\Program Files (x86)\PRTG Network Monitor\cert\root-original.pem'
    
    # Copies and renames the certificate generated by Let's Encrypt to the PRTG folder
    Logging -Message "Copy new cert info to PRTG"
    Copy-Item ~\AppData\Local\Posh-ACME\$PoshVersion\$AccountNumber\$Domain\cert.cer 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.crt'
    Copy-Item ~\AppData\Local\Posh-ACME\$PoshVersion\$AccountNumber\$Domain\cert.key 'C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.key'
    Copy-Item ~\AppData\Local\Posh-ACME\$PoshVersion\$AccountNumber\$Domain\fullchain.cer 'C:\Program Files (x86)\PRTG Network Monitor\cert\root.pem'    

    # Restarts the PRTG service to apply the new certificates
    Logging -Message "Restarting PRTG"
    Restart-Service PRTGCoreService
    
    # Remove old certs out of the certificate store
    ls Cert:\LocalMachine\My | ? Subject -eq "CN=$MainDomain" | ? NotAfter -lt $(get-date) | remove-item -Force
}else{
    # If no certificate was passed, then Posh determined the current certificate was not subject to renewal and the process is completed
    Logging -Message "No need to update PRTG certifcate" 
}

