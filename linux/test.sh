#!/bin/bash

UBUNTU_VERSION=$(lsb_release -sr)

if [ $UBUNTU_VERSION="22.04" ]
then
  echo 'Ubuntu 22.04 Detected. Running special symlink command'
fi

echo $(lsb_release -sr)