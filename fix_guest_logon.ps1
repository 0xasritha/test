$source = @"
using System;
using System.Runtime.InteropServices;

public static class LsaUtil {
    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_OBJECT_ATTRIBUTES {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public int Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct LSA_UNICODE_STRING {
        public ushort Length;
        public ushort MaximumLength;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string Buffer;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern uint LsaOpenPolicy(
        IntPtr systemName,
        ref LSA_OBJECT_ATTRIBUTES objectAttributes,
        int desiredAccess,
        out IntPtr policyHandle
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern long LsaAddAccountRights(
        IntPtr policyHandle,
        byte[] accountSid,
        LSA_UNICODE_STRING[] userRights,
        int countOfRights
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern long LsaRemoveAccountRights(
        IntPtr policyHandle,
        byte[] accountSid,
        bool allRights,
        LSA_UNICODE_STRING[] userRights,
        int countOfRights
    );

    [DllImport("advapi32.dll")]
    public static extern long LsaClose(IntPtr policyHandle);

    [DllImport("advapi32.dll")]
    public static extern int LsaNtStatusToWinError(long status);
}
"@

Add-Type -TypeDefinition $source | Out-Null

function New-LsaString([string]$value) {
    $right = New-Object LsaUtil+LSA_UNICODE_STRING
    $right.Buffer = $value
    $right.Length = [uint16]($value.Length * 2)
    $right.MaximumLength = [uint16](($value.Length * 2) + 2)
    return $right
}

$sid = New-Object System.Security.Principal.SecurityIdentifier(
    'S-1-5-21-1009846605-3753786792-3241561228-501'
)
$sidBytes = New-Object byte[] ($sid.BinaryLength)
$sid.GetBinaryForm($sidBytes, 0)

$oa = New-Object LsaUtil+LSA_OBJECT_ATTRIBUTES
$oa.Length = [Runtime.InteropServices.Marshal]::SizeOf($oa)
$handle = [IntPtr]::Zero
$POLICY_ALL_ACCESS = 0x00F0FFF
$openStatus = [LsaUtil]::LsaOpenPolicy([IntPtr]::Zero, [ref]$oa, $POLICY_ALL_ACCESS, [ref]$handle)
if ($openStatus -ne 0) {
    throw "LsaOpenPolicy failed: $([LsaUtil]::LsaNtStatusToWinError($openStatus))"
}

$removeRights = @(
    (New-LsaString 'SeDenyInteractiveLogonRight'),
    (New-LsaString 'SeDenyNetworkLogonRight')
)
$removeStatus = [LsaUtil]::LsaRemoveAccountRights(
    $handle,
    $sidBytes,
    $false,
    $removeRights,
    $removeRights.Count
)
if ($removeStatus -ne 0 -and [LsaUtil]::LsaNtStatusToWinError($removeStatus) -ne 2) {
    [void][LsaUtil]::LsaClose($handle)
    throw "LsaRemoveAccountRights failed: $([LsaUtil]::LsaNtStatusToWinError($removeStatus))"
}

$addRights = @(
    (New-LsaString 'SeRemoteInteractiveLogonRight'),
    (New-LsaString 'SeNetworkLogonRight')
)
$addStatus = [LsaUtil]::LsaAddAccountRights($handle, $sidBytes, $addRights, $addRights.Count)
[void][LsaUtil]::LsaClose($handle)
if ($addStatus -ne 0) {
    throw "LsaAddAccountRights failed: $([LsaUtil]::LsaNtStatusToWinError($addStatus))"
}

Write-Host 'Updated Guest logon rights'
