# Guest Path Package

This directory contains the built-in `Guest` trigger path for the RasAuto/RasMan LPE.

The current payload in `pwn.c` does this when the exploit lands:

- loads `pwn.dll` in the SYSTEM `rasauto` process
- runs `net localgroup Administrators <helper-user> /add`
- writes `group_add.txt`
- writes `system.txt` with `whoami`

## Contents

- `admin_setup.cmd`: run this once from an elevated administrator shell
- `guest_trigger.cmd`: run this while logged in as built-in `Guest`
- `exploit_host2.cpp`: fake RasMan host
- `pwn.c`: DLL payload
- `pwn.pbk`: custom PBK used on the hangup path
- `signal_event.c`: sets `RasAutoDialSharedConnectionEvent`
- `launch_guest.c`: starts a process as the chosen low-priv helper account
- `launch_builtin_guest.c`: helper source for the built-in `Guest` launcher
- `list_sessions.c`: WTS session dump helper
- `probe_console_token.c`: checks whether the active console user token is queryable
- `prepare_shared_autodial.ps1`: creates the shared VPN / ICS / saved-creds state
- `query_shared_connection.c`: shared-connection environment check
- `fix_guest_logon.ps1`: Guest logon-rights repair script
- `the-vulnerable-rasmans.dll`: vulnerable RasMan image loaded by `exploit_host2.exe`

## Intended State

This package is for the built-in `Guest` path only.

Known-good runtime shape:

- built-in `Guest` is the active console user
- no admin GUI session is active
- a low-priv helper account is used to own the fake RasMan endpoint
- the shared-autodial / ICS / shared-VPN prerequisites are in place

## Copy To The VM

Copy the contents of this directory to:

```cmd
C:\Users\Public\Desktop\EXPLOIT
```

The scripts assume that exact path.

## Step 1: Run The Administrative Setup

On a fresh machine, first prepare the shared VPN / ICS state:

```powershell
powershell -ExecutionPolicy Bypass -File .\prepare_shared_autodial.ps1
```

That script prompts for the machine-specific values:

- VPN entry name
- VPN server/IP
- VPN username
- VPN password
- private ICS adapter name

It then:

- sets `SharedAutoDial=1`
- creates an all-users PPTP VPN entry
- normalizes the phonebook entry to `WAN Miniport (PPTP)`
- stores saved RAS credentials in the all-users phonebook
- enables ICS with the VPN as the public shared connection
- prints `RasGetCredentialsW` and `RasQuerySharedConnectionW` verification

After that, run the exploit setup:

Open an elevated `cmd.exe` and run:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
admin_setup.cmd
```

What `admin_setup.cmd` does:

- prints each step with `[+]`
- prompts for:
  - low-priv helper username
  - low-priv helper password
  - built-in `Guest` password, which can be left blank
- finds `VsDevCmd.bat` from common Visual Studio locations, then prompts for the path if autodiscovery fails
- enables built-in `Guest`
- updates the built-in `Guest` password to the value you entered
- creates the helper account automatically if it does not already exist
- adds `Guest` to `Remote Desktop Users`
- runs `fix_guest_logon.ps1`
- builds all required binaries
- bakes the chosen helper username into `pwn.dll`
- removes the helper account from `Administrators`
- clears old proof files
- stops `RasMan`
- starts `RasAuto`
- starts the fake RasMan host as the chosen low-priv helper account
- verifies that `exploit_host2.exe` is still running and that `squatter.log` was created
- prints the current session and console-token state

If the script prompts for `VsDevCmd.bat`, paste the full path from your machine.

## Step 2: Log In As Built-in Guest

After `admin_setup.cmd` completes:

1. Log out of any GUI admin session.
2. Log in manually as built-in `Guest`.
3. Make sure this is the visible console session.

The package is written for the built-in `Guest` account, not `guestlab`.

## Step 3: Run The Guest Trigger

While logged in as built-in `Guest`, open `cmd.exe` and run:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
guest_trigger.cmd
```

What `guest_trigger.cmd` does:

- prints each step with `[+]`
- shows `whoami`
- runs `signal_event.exe`
- waits for the SYSTEM cleanup path
- prints:
  - `squatter.log`
  - `load.txt`
  - `group_add.txt`
  - `system.txt`
  - final `Administrators` membership

## Success Criteria

Successful output should include:

- `squatter.log` contains `SubmitRequestLocal code=101`
- `load.txt` contains `loaded`
- `group_add.txt` shows the `net localgroup Administrators <helper-user> /add` result
- `system.txt` contains `nt authority\system`
- `net localgroup Administrators` now lists the helper account you chose during `admin_setup.cmd`

## Notes

- On a fresh machine, the full flow is:
  - `prepare_shared_autodial.ps1`
  - `admin_setup.cmd`
  - `guest_trigger.cmd`
- After the prerequisites are in place, the exploit itself is still the same two-step flow:
  - `admin_setup.cmd`
  - `guest_trigger.cmd`
- `admin_setup.cmd` must be run first.
- `guest_trigger.cmd` must be run while logged in as built-in `Guest`.
