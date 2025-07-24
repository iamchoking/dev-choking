#!/bin/bash

### 1. update / upgrade `apt`
sudo apt update
sudo apt upgrade -y

echo '<dev-choking> apt update / upgrade complete'

### 2. install `terminator`
sudo apt install terminator

echo '<dev-choking> installed terminator'

### 3. configure git

git config --global user.name iamchoking
git config --global user.email iamchoking247@gmail.com

echo '<dev-choking> configured git'

### 4. install gh
sudo apt install gh 

echo '<dev-choking> installed gh'