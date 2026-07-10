# Guest Demo Package

This directory contains the final two-script demo flow for the working
`Guest -> rasauto -> fake RasMan -> ReferenceCustomCount -> pwn.dll` LPE path.

The package is designed around:

- one administrator-run setup script: `admin_setup.cmd`
- one built-in `Guest` trigger script: `guest_trigger.cmd`

## What The Demo Proves

The final payload in `pwn.c` does two things when `rasauto` loads `pwn.dll` as SYSTEM:

- adds the chosen low-priv helper user to `Administrators`
- writes `system.txt` containing `whoami`

On a successful run you should see:

- `load.txt` contains `loaded`
- `group_add.txt` shows the `Administrators` add succeeded
- `system.txt` contains `nt authority\system`

## Required Local State

Before the exploit can work, the machine must already be in the shared-autodial state:

- `SharedAutoDial=1`
- ICS configured so the shared/public connection is the VPN entry
- the shared connection is a RAS/VPN entry
- saved credentials exist for that shared VPN entry

This package includes `prepare_shared_autodial.ps1` to build that state.

## End-To-End Local Demo

### 1. Copy The Folder

Copy this directory to:

```cmd
C:\Users\Public\Desktop\EXPLOIT
```

The scripts assume that exact path.

### 2. Prepare The Shared VPN / ICS State

From an elevated PowerShell:

```powershell
cd C:\Users\Public\Desktop\EXPLOIT
powershell -ExecutionPolicy Bypass -File .\prepare_shared_autodial.ps1
```

What it does:

- starts the real `MpsSvc`, `SharedAccess`, and `RasMan` services
- sets `SharedAutoDial=1`
- creates or normalizes the all-users PPTP VPN entry
- stores saved credentials for that VPN entry
- enables ICS with the VPN as public and your chosen adapter as private
- verifies `RasQuerySharedConnection`

Defaults currently baked into the script:

- entry name: `LpeLabVpn`
- VPN server: `10.37.1.208`
- VPN username: `guestlab`
- VPN password: `Passw0rd!`

You still need to provide the private ICS adapter name for the local machine.

### 3. Run The Administrator Setup

From an elevated `cmd.exe`:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
admin_setup.cmd
```

What `admin_setup.cmd` does:

- enables the built-in `Guest` account
- creates or updates the low-priv helper account
- repairs `Guest` logon rights with `fix_guest_logon.ps1`
- builds the required binaries with MSVC
- verifies `RasQuerySharedConnection` is `err=0` with a nonzero value
- creates a second phonebook entry named `pwn` in the real all-users phonebook
- clears `CustomDialDll` / `CustomRasDialDll` from the live shared VPN entry
- sets `CustomDialDll` / `CustomRasDialDll` on the cloned `pwn` entry
- removes the helper account from `Administrators`
- clears old proof files
- stops the real `RasMan`
- starts the fake low-priv `RasMan` host
- restarts `RasAuto` so it binds against the fake endpoint
- fails if `RasAuto` does not rebind and produce the expected `code=113` and `code=55`
- prints current session state

Prompts you will see:

- helper username
- helper password
- built-in `Guest` password
- shared VPN entry name
- `VsDevCmd.bat` path if autodiscovery fails

### 4. Log In As Built-in Guest

After `admin_setup.cmd` completes:

- log out of any GUI admin desktop
- log in as the built-in `Guest`
- make sure `Guest` is the active `console` session

This package is for the built-in `Guest` path, not for a normal low-priv user session.

### 5. Run The Guest Trigger

From a `cmd.exe` running as built-in `Guest`:

```cmd
cd C:\Users\Public\Desktop\EXPLOIT
guest_trigger.cmd
```

What `guest_trigger.cmd` does:

- prints the current `Guest` session state
- signals `RasAutoDialSharedConnectionEvent`
- waits for the cleanup / hang-up path
- prints:
  - `squatter.log`
  - `load.txt`
  - `group_add.txt`
  - `system.txt`

## Expected Successful Output

The run is successful when all of these are true:

- `squatter.log` contains `SubmitRequestLocal code=101`
- `load.txt` contains `loaded`
- `group_add.txt` contains `The command completed successfully.`
- `system.txt` contains `nt authority\system`

The setup step is only considered healthy if `admin_setup.cmd` itself succeeds.
If it fails before the Guest step, do not run `guest_trigger.cmd`.

If you want a final admin-side verification after the demo:

```cmd
net localgroup Administrators
```

The helper user should now be listed.

## File Guide

### Entry Scripts

- `admin_setup.cmd`
  Performs the full administrator-side preparation and starts the fake low-priv
  `RasMan` server.
- `guest_trigger.cmd`
  Runs from the built-in `Guest` session and signals `rasauto`.

### Exploit Core

- `exploit_host2.cpp`
  The fake low-priv `RasMan` RPC server. This is the main exploit logic.
- `the-vulnerable-rasmans.dll`
  The vulnerable `rasmans.dll` image loaded and patched by `exploit_host2.exe`.
- `pwn.c`
  The SYSTEM payload DLL source. Builds to `pwn.dll`.

### Phonebook / Payload Helpers

- `fix_phonebook_entry.ps1`
  Clones the real shared VPN entry to a second `pwn` entry in the all-users
  phonebook and assigns the custom DLL path there.
- `pwn.pbk`
  Legacy custom phonebook artifact from earlier iterations. The final demo uses
  the real all-users phonebook plus the `pwn` clone entry instead.

### Environment Setup

- `prepare_shared_autodial.ps1`
  Builds the shared VPN / ICS / saved-creds prerequisite state.
- `fix_guest_logon.ps1`
  Repairs built-in `Guest` logon rights.
- `query_shared_connection.c`
  Source for `query_shared_connection.exe`, which checks whether Windows sees a
  shared RAS/VPN connection.

### Trigger / Session Helpers

- `signal_event.c`
  Source for `signal_event.exe`, which signals
  `RasAutoDialSharedConnectionEvent`.
- `launch_guest.c`
  Launches a process as the chosen low-priv helper user.
- `launch_builtin_guest.c`
  Launch helper source for the built-in `Guest` account.
- `list_sessions.c`
  Dumps WTS session state in a compact format.
- `probe_console_token.c`
  Probes the active console session token state.
- `launch_active_console.c`
  Earlier helper source for launching in the active console session.

### Debug / Lab Files

- `make_pwn_pbk.c`
  Experimental phonebook-generation helper from earlier debugging.
- `test_pbook_lpe.c`
  Phonebook validation helper used while debugging the final `code=101` path.
- `talk-outline.md`
  Notes for presenting or explaining the exploit chain.

## Notes

- The final proven path does not require editing the live shared VPN entry to
  point at the payload DLL.
- The shared VPN entry stays clean for dialing.
- The DLL path lives on the cloned `pwn` entry, and `ReferenceCustomCount`
  redirects the hang-up path there.
