# Guest Path Package

This directory contains the built-in `Guest` trigger path for the RasAuto/RasMan LPE.

The current payload in `pwn.c` does this when the exploit lands:

- loads `pwn.dll` in the SYSTEM `rasauto` process
- runs `net localgroup Administrators guestlab /add`
- writes `group_add.txt`
- writes `system.txt` with `whoami`

## Contents

- `admin_setup.cmd`: run this once from an elevated administrator shell
- `guest_trigger.cmd`: run this while logged in as built-in `Guest`
- `exploit_host2.cpp`: fake RasMan host
- `pwn.c`: DLL payload
- `pwn.pbk`: custom PBK used on the hangup path
- `signal_event.c`: sets `RasAutoDialSharedConnectionEvent`
- `launch_guest.c`: starts a process as low-priv `guestlab`
- `launch_builtin_guest.c`: helper source for the built-in `Guest` launcher
- `list_sessions.c`: WTS session dump helper
- `probe_console_token.c`: checks whether the active console user token is queryable
- `query_shared_connection.c`: shared-connection environment check
- `fix_guest_logon.ps1`: Guest logon-rights repair script

## Intended State

This package is for the built-in `Guest` path only.

Known-good runtime shape:

- built-in `Guest` is the active console user
- no admin GUI session is active
- `guestlab` exists and has password `password`
- the lab already has the shared-autodial / ICS / shared-VPN prerequisites in place

## Copy To The VM

Copy the contents of this directory to:

```cmd
C:\Users\Public\Desktop\EXPLOIT
```

The scripts assume that exact path.

## Step 1: Run The Administrative Setup

Open an elevated `cmd.exe` and run:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
admin_setup.cmd
```

What `admin_setup.cmd` does:

- prints each step with `[+]`
- finds `VsDevCmd.bat` from common Visual Studio locations
- enables built-in `Guest`
- sets:
  - `Guest` password to `password`
  - `guestlab` password to `password`
- adds `Guest` to `Remote Desktop Users`
- runs `fix_guest_logon.ps1`
- builds all required binaries
- removes `guestlab` from `Administrators`
- clears old proof files
- stops `RasMan`
- starts `RasAuto`
- starts the fake RasMan host as low-priv `guestlab`
- prints the current session and console-token state

If the script says it cannot find `VsDevCmd.bat`, install the Visual Studio C++ build tools or edit the script with the correct path.

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
- `group_add.txt` shows the `net localgroup Administrators guestlab /add` result
- `system.txt` contains `nt authority\system`
- `net localgroup Administrators` now lists `guestlab`

## Notes

- The full flow is now exactly two scripts:
  - `admin_setup.cmd`
  - `guest_trigger.cmd`
- `admin_setup.cmd` must be run first.
- `guest_trigger.cmd` must be run while logged in as built-in `Guest`.
