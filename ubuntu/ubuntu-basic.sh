#!/bin/bash

### 1. update / upgrade `apt`
sudo apt update
sudo apt upgrade -y

echo '<dev-choking> apt update / upgrade complete'

### 2. install essential apps
sudo apt install terminator htop gedit -y

sudo add-apt-repository ppa:danielrichter2007/grub-customizer
sudo apt-get update
sudo apt-get install grub-customizer -y

echo '<dev-choking> installed essential apps'

### 3. configure git

git config --global user.name iamchoking
git config --global user.email iamchoking247@gmail.com

echo '<dev-choking> configured git'

### 4. install gh
sudo apt install gh -y

echo '<dev-choking> installed gh'