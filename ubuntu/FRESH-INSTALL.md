# Fresh Install Directions for Ubuntu
## Written for
`Ubuntu` (`20.04`/`22.04`)

### 0. Install git

```bash
sudo apt-get install git-all -y
```

### 1. Clone `dev-choking` (this repo) to your home
(+ Give appropriate ```chmod``` permissions)
```bash
cd ~ && git clone https://github.com/iamchoking/dev-choking.git && cd ./dev-choking/ubuntu && find . -type f -regex '.*\.sh$' -exec chmod +x {} \; && chmod +x linux_raisimCheckMyMachine;
```
We will operate in this directory (`dev-choking/ubuntu`) henceforth

### 2. install basic dependencies and aliases

#### Set up user alises

**WARNING: this bash alias is highly catored to myself.**
```
./user-alias.sh
```

#### Basic apps / dependencies

```bash
./ubuntu-basic.sh
```

* update / upgrade apt
* install terminator
* configures git
* installs ```gh``` (git CLI)

For Windows + Ubuntu dual boot, follow [the Ubuntu dual-boot guide](../dual-boot/UBUNTU.md)
and see the [Windows clock notes](../dual-boot/WINDOWS.md). Windows clock handling
is already included in the normal Windows settings script.
GRUB Customizer installation has moved there from `ubuntu-basic.sh`.

***TODO: pass ```user.name``` and ```user.email``` as arguments***

After this part, close and re-open the terminal (should open ```terminator```)

#### Korean / English input (Ubuntu 24.04 GNOME)

From a terminal in your GNOME desktop, run as your normal user:

```bash
bash ./setup-korean-input.sh
```

This automates the [Korean input setup guide](https://andrewpage.tistory.com/390):
install Korean language support, fonts, and `ibus-hangul`; select IBus; and set
the input source to **Korean (Hangul)** (`ibus`, `hangul`). It replaces the
existing input source list with Hangul, which supports both Korean and English.
Your desktop display language stays unchanged.

Log out and back in, or reboot, after it completes. In a text editor, press
**Shift+Space** or the **한/영** key to switch between Korean and English.
The engine starts in English mode. The script saves previous settings and prints
a `bash .../restore.sh` command to undo its configuration; installed packages remain.
Log out and back in after restoring, too.

To also use Right Alt for the toggle:

```bash
bash ./setup-korean-input.sh --switch-keys 'Hangul,Shift+space,Alt_R'
```

`Alt_R` applies when Right Alt emits that keysym; some keyboards already emit
`Hangul`, while layouts using AltGr may emit a different keysym.
Use `--skip-install` to reconfigure an existing installation without running APT.
If `im-config` reports a custom `~/.xinputrc`, edit that file to select IBus or
use the printed restore command; the script does not overwrite a custom file.

### 3. (Optional) Generate/add an ssh key for the local machine
*This enables accessing github repos through `ssh`* (solves the `git@github.com: Permission denied (publickey)` problem, etc.)*.

First, try:
```bash
gh auth login
```

And choose `SSH` as the ***preferred protocol for Git operations***

Check if the key was successfully added with
```bash
ssh git@github.com
```
You should get a message ending with `Hi (user)! You've successfully authenticated, ...`

To try manually adding an ssh key, go [here](./GIT-SSH.md)

### 4. (Optional) Install Essential Apps
*You can go into `apps-essential.sh` and comment out apps that are not needed.*
**WARNING: Check your cpu architecture! (`amd64`, etc.)**

```
./apps-essential_amd64.sh
```

`_amd64` installs:
* vscode
* chrome

TODO: other distros

***
### 5. Install Accessory Apps
Now is a great time to install other accessory apps such as:
* Spotify (Ubuntu Software)
* Clion (If you are planning on using `raisimGymTorch`)
TODO: shell script for accessory apps
***
### 6. Installing important applications
Now, install important apps / API's into your computer
#### a. `raisim`  / `raisimGymTorch`
*last updated 2024-04-02*

If needed, get a fresh license key from [here](https://forms.gle/4bcS2GByKYdeKxmn7)

*(If you need a machine ID, run `./linux_raisimCheckMyMachine`)*

Download your licence as `~/Downloads/activation.raisim`

Finally, 
```
./raisim.sh
```

Now, setup the environment for ```raisimGymTorch```
```
./raisim-gym-torch-env.sh
```
**Note: This script is very unstable. If this script fails, look into its source and [this page](https://github.com/5sik/Linux-setting) for debugging**

Alternatively, you can try looking into YouTube tutorials ([linux](https://youtu.be/0yj61G_ge-0), [windows](https://youtu.be/RlseqQPEo_4)).

#### b. `ros2`
*last updated 2021-11-18*
```
./ros2-foxy.sh
```
