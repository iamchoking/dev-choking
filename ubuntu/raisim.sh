#!/bin/bash
UBUNTU_VERSION=$(lsb_release -sr)

cd ~

# basic tools
sudo apt update 
sudo apt install -y \
  git terminator \
  libeigen3-dev \
  doxygen \
  mercurial \
  valgrind \
  liburdfdom-dev \
  curl \
  minizip \
  ffmpeg \
  libyaml-cpp-dev \
  build-essential\
  htop\
  cmake\
  gcc

# sudo snap install cmake --classic
# sudo snap install clion --classic
# sudo snap install rider --classic

# locate / move activation key
mkdir -p ~/.raisim
cp ~/Downloads/activation.raisim ~/.raisim

# make workspace directory

mkdir -p raisim_ws
cd raisim_ws

# git clone https://github.com/raisimTech/raisimLib.git
git clone git@github.com:raisimTech/raisimLib.git

cd raisimLib

rm -rf build && mkdir build && cd build

cmake .. -DCMAKE_BUILD_TYPE=RELEASE
# change according to hardware specs
make -j
# make -j4

# setting important env.variables in bashrc
echo "
# raisim environment varaibles
RAISIMLIB_DIR=\"~/raisim_ws/raisimLib\"
LOCAL_INSTALL=\"TODO\"
RAISIM_PREFIX_PATH=\"~/raisim_ws/raisimLib/raisim/linux\"
# location of config files (for_cmake)
raisim_DIR_cmake=\"~/raisim_ws/raisimLib/raisim/linux/lib/cmake/raisim\"

# raisim command aliases
alias raisim_monitor='~/raisim_ws/raisimLib/raisimUnity/linux/raisimUnity.x86_64 & htop'
" >> ~/.bashrc

source ~/.bashrc

if [ $UBUNTU_VERSION="22.04" ]
then
  echo 'Ubuntu 22.04 Detected. Running special symlink command'
  sudo ln -s /usr/lib/x86_64-linux-gnu/libdl.so.2 /usr/lib/x86_64-linux-gnu/libdl.so
fi

echo "<dev-choking> raisim installation complete"

echo "<dev-choking> running example. Exit to finish installation"
echo "(run raisim_monitor in another terminal)"
# run an example for verification
# currently in ~/raisim_ws/raisimLib/build
# ./examples/atlas
# TODO: run raisimUnity alongside
~/raisim_ws/raisimLib/raisimUnity/linux/raisimUnity.x86_64 & ./examples/atlas