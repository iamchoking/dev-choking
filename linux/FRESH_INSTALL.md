# Fresh Install Directions for Linux Distros
## Written for
`Ubuntu` (`20.04`/`22.04`)

1. update / upgrade apt
```bash
sudo apt update
sudo apt upgrade
```

2. install terminator
```bash
sudo apt install terminator
```

3. install and configure git
```bash
sudo apt-get install git-all
```
* This takes care of most basic depenencies!      
```bash
git config --global user.name <your username>
git config --global user.email <your email>
```

4. install chrome
```bash
sudo apt-get install libxss1 libappindicator1 libindicator7
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome*.deb
```

5. Clone this directory to your home
```bash
cd ~ && git clone https://github.com/iamchoking/dev-choking.git && cd ./dev-choking/linux
```

6. 