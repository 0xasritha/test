$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$programData = [Environment]::GetFolderPath('CommonApplicationData')
$phonebookPath = Join-Path $programData 'Microsoft\Network\Connections\Pbk\rasphone.pbk'
$defaultVpnName = 'LpeLabVpn'
$defaultVpnServer = '10.37.1.208'
$defaultVpnUser = 'guestlab'
$defaultVpnPassword = 'Passw0rd!'

$rasSource = @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct RASCREDENTIALSW {
    public int dwSize;
    public int dwMask;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 257)]
    public string szUserName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 257)]
    public string szPassword;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 16)]
    public string szDomain;
}

public static class RasApi32Native {
    public const int RASCM_UserName = 0x00000001;
    public const int RASCM_Password = 0x00000002;

    [DllImport("rasapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int RasSetCredentialsW(
        string phonebook,
        string entry,
        ref RASCREDENTIALSW credentials,
        bool clearCredentials
    );

    [DllImport("rasapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int RasGetCredentialsW(
        string phonebook,
        string entry,
        ref RASCREDENTIALSW credentials
    );

    [DllImport("rasapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int RasQuerySharedConnectionW(out uint value);
}
"@

Add-Type -TypeDefinition $rasSource | Out-Null

function Write-Step([string]$Message) {
    Write-Host "[+] $Message"
}

function Read-Value([string]$Prompt, [string]$Default = '') {
    if ($Default) {
        $value = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }
        return $value
    }
    return (Read-Host $Prompt).Trim()
}

function Read-RequiredValue([string]$Prompt) {
    while ($true) {
        $value = (Read-Host $Prompt).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
        Write-Host "[!] $Prompt cannot be blank"
    }
}

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw 'Run this script from an elevated PowerShell window.'
    }
}

function Ensure-PhonebookDirectory {
    $directory = Split-Path -Path $phonebookPath -Parent
    if (-not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

function Ensure-SharedAutoDial {
    Write-Step 'Setting SharedAutoDial=1'
    New-ItemProperty `
        -Path 'HKLM:\System\CurrentControlSet\Services\SharedAccess\Parameters' `
        -Name 'SharedAutoDial' `
        -Value 1 `
        -PropertyType DWord `
        -Force | Out-Null
}

function Ensure-ServiceRunning([string]$Name) {
    $service = Get-Service -Name $Name -ErrorAction Stop
    if ($service.StartType -eq 'Disabled') {
        Write-Step "Setting $Name startup type to Manual"
        Set-Service -Name $Name -StartupType Manual
        $service = Get-Service -Name $Name -ErrorAction Stop
    }
    if ($service.Status -eq 'Running') {
        Write-Step "$Name is already running"
        return
    }

    Write-Step "Starting $Name"
    Start-Service -Name $Name
    $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(15))
}

function Ensure-VpnConnection(
    [string]$Name,
    [string]$ServerAddress
) {
    $existing = Get-VpnConnection `
        -Name $Name `
        -AllUserConnection `
        -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Step "Removing existing all-users VPN entry '$Name'"
        Remove-VpnConnection `
            -Name $Name `
            -AllUserConnection `
            -Force | Out-Null
    }

    Write-Step "Creating all-users PPTP VPN entry '$Name'"
    Add-VpnConnection `
        -Name $Name `
        -ServerAddress $ServerAddress `
        -TunnelType Pptp `
        -AuthenticationMethod MSChapv2 `
        -EncryptionLevel Optional `
        -RememberCredential `
        -AllUserConnection `
        -Force | Out-Null
}

function Connect-Vpn(
    [string]$Name,
    [string]$UserName,
    [string]$Password
) {
    Write-Step "Connecting VPN entry '$Name' once with rasdial"
    $arguments = @(
        $Name,
        $UserName,
        $Password,
        "/PHONEBOOK:$phonebookPath"
    )
    $output = & rasdial.exe @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $text = ($output | Out-String).Trim()
        throw "rasdial failed with $LASTEXITCODE: $text"
    }
}

function Update-PhonebookEntry(
    [string]$EntryName,
    [hashtable]$Values
) {
    Ensure-PhonebookDirectory
    if (-not (Test-Path -Path $phonebookPath)) {
        throw "Phonebook not found: $phonebookPath"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -Path $phonebookPath -Encoding ASCII) {
        $lines.Add($line)
    }

    $sectionHeader = "[$EntryName]"
    $start = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -eq $sectionHeader) {
            $start = $index
            break
        }
    }
    if ($start -lt 0) {
        throw "VPN entry '$EntryName' not found in $phonebookPath"
    }

    $end = $lines.Count
    for ($index = $start + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].StartsWith('[')) {
            $end = $index
            break
        }
    }

    foreach ($key in $Values.Keys) {
        $matchIndex = -1
        for ($index = $start + 1; $index -lt $end; $index++) {
            if ($lines[$index].StartsWith("$key=")) {
                $matchIndex = $index
                break
            }
        }
        $newLine = "$key=$($Values[$key])"
        if ($matchIndex -ge 0) {
            $lines[$matchIndex] = $newLine
            continue
        }

        $lines.Insert($end, $newLine)
        $end++
    }

    Set-Content -Path $phonebookPath -Value $lines -Encoding ASCII
}

function Set-RasCredentials(
    [string]$EntryName,
    [string]$UserName,
    [string]$Password
) {
    $credentials = New-Object RASCREDENTIALSW
    $credentials.dwSize = [Runtime.InteropServices.Marshal]::SizeOf($credentials)
    $credentials.dwMask = `
        [RasApi32Native]::RASCM_UserName -bor [RasApi32Native]::RASCM_Password
    $credentials.szUserName = $UserName
    $credentials.szPassword = $Password
    $result = [RasApi32Native]::RasSetCredentialsW(
        $phonebookPath,
        $EntryName,
        [ref]$credentials,
        $false
    )
    if ($result -ne 0) {
        throw "RasSetCredentialsW failed with $result"
    }
}

function Get-RasCredentialsSummary([string]$EntryName) {
    $credentials = New-Object RASCREDENTIALSW
    $credentials.dwSize = [Runtime.InteropServices.Marshal]::SizeOf($credentials)
    $result = [RasApi32Native]::RasGetCredentialsW(
        $phonebookPath,
        $EntryName,
        [ref]$credentials
    )
    return [pscustomobject]@{
        Result = $result
        UserName = $credentials.szUserName
        PasswordLength = $credentials.szPassword.Length
        Domain = $credentials.szDomain
    }
}

function Get-SharingManager {
    return New-Object -ComObject HNetCfg.HNetShare
}

function Get-ShareConnectionByName(
    $SharingManager,
    [string]$Name
) {
    foreach ($connection in @($SharingManager.EnumEveryConnection())) {
        $properties = $SharingManager.NetConnectionProps($connection)
        if ($properties.Name -eq $Name) {
            return $connection
        }
    }
    throw "Connection '$Name' was not found by HNetCfg.HNetShare."
}

function Disable-ExistingSharing($SharingManager) {
    foreach ($connection in @($SharingManager.EnumEveryConnection())) {
        $configuration = $SharingManager.INetSharingConfigurationForINetConnection(
            $connection
        )
        if (-not $configuration.SharingEnabled) {
            continue
        }
        $properties = $SharingManager.NetConnectionProps($connection)
        Write-Step "Disabling existing ICS on '$($properties.Name)'"
        $configuration.DisableSharing()
    }
}

function Enable-Ics(
    [string]$PublicName,
    [string]$PrivateName
) {
    $sharingManager = Get-SharingManager
    Disable-ExistingSharing -SharingManager $sharingManager

    $publicConnection = Get-ShareConnectionByName `
        -SharingManager $sharingManager `
        -Name $PublicName
    $privateConnection = Get-ShareConnectionByName `
        -SharingManager $sharingManager `
        -Name $PrivateName

    $publicConfiguration = $sharingManager.INetSharingConfigurationForINetConnection(
        $publicConnection
    )
    $privateConfiguration = $sharingManager.INetSharingConfigurationForINetConnection(
        $privateConnection
    )

    Write-Step "Enabling ICS public sharing on '$PublicName'"
    $publicConfiguration.EnableSharing(0)
    Write-Step "Enabling ICS private sharing on '$PrivateName'"
    $privateConfiguration.EnableSharing(1)
}

function Get-IcsSummary([string[]]$Names) {
    $sharingManager = Get-SharingManager
    foreach ($name in $Names) {
        $connection = Get-ShareConnectionByName -SharingManager $sharingManager -Name $name
        $properties = $sharingManager.NetConnectionProps($connection)
        $configuration = $sharingManager.INetSharingConfigurationForINetConnection(
            $connection
        )
        [pscustomobject]@{
            Name = $properties.Name
            SharingEnabled = [bool]$configuration.SharingEnabled
            SharingType = $configuration.SharingConnectionType
        }
    }
}

function Get-SharedConnectionSummary {
    [uint32]$value = 0
    $result = [RasApi32Native]::RasQuerySharedConnectionW([ref]$value)
    return [pscustomobject]@{
        Result = $result
        Value = $value
    }
}

Assert-Admin

Write-Step 'Preparing shared autodial prerequisites'
Write-Step "All-users phonebook: $phonebookPath"

$vpnName = Read-Value -Prompt 'VPN entry name' -Default $defaultVpnName
$vpnServer = Read-Value -Prompt 'VPN server or IP' -Default $defaultVpnServer
$vpnUser = Read-Value -Prompt 'VPN username' -Default $defaultVpnUser
$vpnPassword = Read-Value -Prompt 'VPN password' -Default $defaultVpnPassword

Write-Step 'Available network connection names'
Get-NetAdapter | Sort-Object Name | Format-Table -AutoSize Name, InterfaceDescription, Status
Write-Host
$privateAdapter = Read-RequiredValue -Prompt 'Private ICS adapter name'

Ensure-ServiceRunning -Name 'MpsSvc'
Ensure-ServiceRunning -Name 'SharedAccess'
Ensure-ServiceRunning -Name 'RasMan'
Ensure-SharedAutoDial
Ensure-VpnConnection -Name $vpnName -ServerAddress $vpnServer
Update-PhonebookEntry `
    -EntryName $vpnName `
    -Values @{
        VpnStrategy = '1'
        PreferredDevice = 'WAN Miniport (PPTP)'
        PreferredPort = 'VPN4-0'
        CustomAuthKey = '0'
    }
Set-RasCredentials -EntryName $vpnName -UserName $vpnUser -Password $vpnPassword
Connect-Vpn -Name $vpnName -UserName $vpnUser -Password $vpnPassword
try {
    Enable-Ics -PublicName $vpnName -PrivateName $privateAdapter
} catch {
    Write-Host
    Write-Host '[!] Failed to enable ICS'
    Write-Host "[!] SharedAccess state: $((Get-Service -Name 'SharedAccess').Status)"
    Write-Host "[!] MpsSvc state: $((Get-Service -Name 'MpsSvc').Status)"
    throw
}

$sharedAutoDial = Get-ItemPropertyValue `
    -Path 'HKLM:\System\CurrentControlSet\Services\SharedAccess\Parameters' `
    -Name 'SharedAutoDial'
$credentialSummary = Get-RasCredentialsSummary -EntryName $vpnName
$sharedConnection = Get-SharedConnectionSummary
$icsSummary = Get-IcsSummary -Names @($vpnName, $privateAdapter)

Write-Host
Write-Step 'Verification'
Write-Host "[+] SharedAutoDial = $sharedAutoDial"
Write-Host "[+] RasGetCredentialsW -> err=$($credentialSummary.Result) " `
    "user='$($credentialSummary.UserName)' passlen=$($credentialSummary.PasswordLength) " `
    "domain='$($credentialSummary.Domain)'"
$sharedConnectionHex = '{0:X8}' -f $sharedConnection.Value
Write-Host "[+] RasQuerySharedConnectionW -> err=$($sharedConnection.Result) " `
    "value=$($sharedConnection.Value) (0x$sharedConnectionHex)"
$icsSummary | Format-Table -AutoSize Name, SharingEnabled, SharingType
Write-Host
Write-Step 'Prerequisite setup complete'
