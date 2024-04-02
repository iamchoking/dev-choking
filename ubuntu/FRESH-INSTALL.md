# Fresh Install Directions for Linux Distros
## Written for
`Ubuntu` (`20.04`/`22.04`)

### 1. update / upgrade `apt`
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. install `terminator`
```bash
sudo apt install terminator
```

### 3. install and configure `git`
```bash
sudo apt-get install git-all
```
* *This takes care of most basic depenencies!*      
```bash
git config --global user.name <your username>
git config --global user.email <your email>
```
#### (Optional) Generate/add an ssh key for the local machine
*This enables accessing github repos through `ssh`* (solves the `git@github.com: Permission denied (publickey)` problem, etc.)*.

For directions, go [here](./GIT-SSH.md)

### 4. Clone `dev-choking` (this repo) to your home
```bash
cd ~ && git clone https://github.com/iamchoking/dev-choking.git && cd ./dev-choking/linux && find . -type f -regex '.*\.sh$' -exec chmod +x {} \ && chmod +x linux_raisimCheckMyMachine;
```
We will operate in this directory (`dev-choking/linux`) henceforth

### 5. Set up bash aliases
**WARNING: this bash alias is highly catored to myself.**
```
./user-alias.sh
```
***
### 6. (Optional) Install Essential Apps
*You can go into `apps-essential.sh` and comment out apps that are not needed.*
**WARNING: Check your cpu architecture! (`amd64`, etc.)**

`amd64` *(installs vscode, chrome)*
```
./apps-essential_amd64.sh
```
TODO: other distros
***
### 7. Install Accessory Apps
Now is a great time to install other accessory apps such as:
* Spotify (Ubuntu Software)
* Clion (If you are planning on using `raisimGymTorch`)
TODO: shell script for accessory apps
***
### 8. Installing important applications
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
#### b. `ros2`
*last updated 2021-11-18*
```
./ros2-foxy.sh
```