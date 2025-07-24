# Fresh Install Directions for Ubuntu
## Written for
`Ubuntu` (`20.04`/`22.04`)

### 0. Install git

```bash
sudo apt-get install git-all
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

***TODO: pass ```user.name``` and ```user.email``` as arguments***

After this part, close and re-open the terminal (should open ```terminator```)

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
