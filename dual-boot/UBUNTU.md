# Windows + Ubuntu dual boot: Ubuntu setup

Windows clock handling is already included in `windows/settings.cmd` during normal
Windows setup. No additional Windows-side dual-boot step is needed; see the
[Windows notes](WINDOWS.md).

## Setup in Ubuntu

After installing Windows on another SSD or partition, boot into **Ubuntu**.
These instructions assume Ubuntu LTS, a working GRUB installation, and both
operating systems installed in UEFI mode.

With this repository at `~/dev-choking`, run:

```bash
sudo ~/dev-choking/dual-boot/setup.sh
```

Then reboot. Select Ubuntu or Windows in GRUB; press Enter to boot immediately.
If Windows starts directly, put **Ubuntu** first in the firmware boot order.

The script installs GRUB Customizer from its
[maintainer's PPA](https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer),
plus `os-prober` and `efibootmgr`. It backs up the GRUB configuration, applies
the settings below, and runs `update-grub`:

```ini
GRUB_DEFAULT="saved"
GRUB_SAVEDEFAULT="true"
GRUB_TIMEOUT_STYLE="menu"
GRUB_TIMEOUT="300"
GRUB_DISABLE_OS_PROBER="false"
```

This shows the menu, detects Windows, and boots the previously selected entry
after a five-minute countdown. **Pressing a key cancels the countdown**; it
does not restart a five-minute idle timer.
See the [GNU GRUB manual](https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html).

GRUB Customizer installation has moved here from
[`ubuntu/ubuntu-basic.sh`](../ubuntu/ubuntu-basic.sh). Open it from Ubuntu's
application menu to change appearance or entry order. To reapply these settings
after editing them in the GUI, run only:

```bash
sudo ~/dev-choking/dual-boot/configure-grub.sh
```

## Checks after setup

In Ubuntu, check Windows detection, firmware entries, and the generated menu:

```bash
sudo os-prober
sudo efibootmgr -v
sudo grub-script-check /boot/grub/grub.cfg
sudo grep -n -E 'menuentry |set timeout|set default=' /boot/grub/grub.cfg
sudo grub-editenv /boot/grub/grubenv list
```

Expect Windows Boot Manager in `os-prober`, Ubuntu and Windows entries in
`efibootmgr`, and both OSes in GRUB. The syntax check should finish without
errors. After selecting an entry, `saved_entry` should appear in `grubenv`.

Boot each OS once and confirm that the next GRUB menu highlights the previous
selection. Press Enter during testing instead of waiting five minutes.
The setup script already checks menu syntax and the presence of a Windows
entry; if either check or `update-grub` fails, it restores the previous defaults
and generated menu.

## Troubleshooting

### Windows starts directly, or Ubuntu is missing

Select Ubuntu from the motherboard's boot menu and put it first in the firmware
boot order. On the MSI MAG B860 TOMAHAWK WIFI, **F11** opens the boot menu and
**Delete** opens BIOS setup.

If Ubuntu's firmware entry or GRUB is missing, recover it with an Ubuntu live
USB using [Ubuntu's UEFI guide](https://help.ubuntu.com/community/UEFI), then
rerun the setup script.

### Windows is missing from GRUB

Check `sudo os-prober` and `sudo efibootmgr -v`, then inspect the disk layout:

```bash
test -d /sys/firmware/efi && echo 'UEFI mode'
findmnt /boot/efi
lsblk -o NAME,MODEL,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS
```

Ubuntu's `/boot/efi` should be a mounted FAT EFI System Partition. Windows can
share it or have its own EFI partition on another SSD. Its boot file normally
ends in `/EFI/Microsoft/Boot/bootmgfw.efi`; the large NTFS partition is not the
EFI partition. The scripts do not hardcode SSD names.

If Windows Boot Manager is missing, repair Windows' UEFI bootloader first.
Then rerun `configure-grub.sh`.

### Timeout or remembered selection is wrong

Check `/etc/default/grub` and any `/etc/default/grub.d/*.cfg` overrides.
Remembering selections requires a writable GRUB environment block; this worked
on our ext4 Ubuntu installation. For a different countdown, edit `GRUB_TIMEOUT`
in `configure-grub.sh`, then rerun it.

For manual changes, edit `/etc/default/grub` and run `sudo update-grub`.
`/boot/grub/grub.cfg` is generated.

### Ubuntu hangs during shutdown or restart

Check the previous Ubuntu shutdown:

```bash
journalctl -b -1 --no-pager -o short-monotonic
```

If it reports `session-1.scope: Stopping timed out. Killing.`, optionally apply
the 15-second session limit used during our troubleshooting:

```bash
sudo ~/dev-choking/dual-boot/configure-session-timeout.sh
```

This limits **all login-session scopes**, including graphical and SSH sessions,
to 15 seconds when they stop. Save work first: remaining processes are forcibly
closed after the limit. It does not fix the underlying hang and is not applied
by `setup.sh`. To remove it:

```bash
sudo ~/dev-choking/dual-boot/configure-session-timeout.sh --remove
```

A brief Ubuntu splash before GRUB when restarting from Ubuntu can be its
shutdown screen. In our final tests on 2026-10-08, shutdown took about 3.15
seconds and the session limit was not reached.

When comparing Windows shutdown behavior, save work and run `shutdown /s /t 0`
in Windows for a full shutdown. Windows Restart also bypasses Fast Startup.
[Microsoft's explanation](https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/fast-startup-causes-system-hibernation-shutdown-fail)

### Restore a GRUB backup

Use the backup directory printed by the script:

```bash
grub_backup=/var/backups/dev-choking-dual-boot/REPLACE-WITH-ACTUAL-DIRECTORY
sudo cp -a "$grub_backup/default-grub" /etc/default/grub
sudo cp -a "$grub_backup/grub.cfg" /boot/grub/grub.cfg
sudo grub-script-check /boot/grub/grub.cfg
```

Each backup also includes `/etc/grub.d` for recovery from later GRUB Customizer
changes. The commands above restore the two files changed by the setup script.
