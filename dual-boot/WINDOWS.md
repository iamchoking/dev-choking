# Windows + Ubuntu dual boot: Windows notes

**No additional Windows-side dual-boot setup is needed after running
[`windows/settings.cmd`](../windows/settings.cmd) and restarting during normal
[Windows setup](../windows/FRESH-INSTALL.md).**

That script sets this registry value:

```text
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation
RealTimeIsUniversal = 1 (REG_DWORD)
```

Windows then interprets the hardware clock as UTC, matching Ubuntu's default.
This prevents the recurring time-zone offset when switching operating systems,
including offline boots. Displayed time still follows your local time zone.
See the [UTC hardware-clock configuration](https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows).

Keep normal Windows time synchronization enabled to correct ordinary clock drift.
There is no additional startup task or forced resynchronization routine.

This is included in the settings script on both Windows 10 and Windows 11.

## Ubuntu's hardware-clock convention

Ubuntu should use its default UTC hardware clock. In Ubuntu, `timedatectl status`
should report **`RTC in local TZ: no`**.

If a previous workaround changed Ubuntu to local RTC time, first ensure its
system time is correct, then restore UTC:

```bash
sudo timedatectl set-ntp true
timedatectl status
# Wait until the displayed time is correct and the system clock is synchronized.
sudo timedatectl set-local-rtc 0
```

[`set-local-rtc 0`](https://manpages.ubuntu.com/manpages/noble/man1/timedatectl.1.html)
also writes the current system time to the hardware clock. Both operating systems
must use the same UTC convention.
