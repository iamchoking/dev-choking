# Set locale

locale  # check for UTF-8

sudo apt update && sudo apt install locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

locale  # verify settings

# Setup Sources
sudo apt update && sudo apt install -y curl gnupg2 lsb-release
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS2 packages
sudo apt update && sudo apt install -y ros-foxy-desktop
source /opt/ros/foxy/setup.bash

# Install Development packages
sudo apt update && sudo apt install -y \
  build-essential \
  cmake \
  git \
  libbullet-dev \
  python3-colcon-common-extensions \
  python3-flake8 \
  python3-pip \
  python3-pytest-cov \
  python3-rosdep \
  python3-setuptools \
  python3-vcstool \
  wget

python3 -m pip install -U \
  argcomplete \
  flake8-blind-except \
  flake8-builtins \
  flake8-class-newline \
  flake8-comprehensions \
  flake8-deprecated \
  flake8-docstrings \
  flake8-import-order \
  flake8-quotes \
  pytest-repeat \
  pytest-rerunfailures \
  pytest

sudo apt install --no-install-recommends -y \
  libasio-dev \
  libtinyxml2-dev \
  libcunit1-dev

# Set up a workspace 
source /opt/ros/foxy/setup.bash
mkdir -p ~/dev_ws/src
cd ~/dev_ws/
colcon build --symlink-install

# Add useful scripts to bashrc
echo "
# ROS2 basics
source /opt/ros/foxy/setup.bash
source ~/dev_ws/install/local_setup.bash
source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
source /usr/share/colcon_cd/function/colcon_cd.sh

export _colcon_cd_root=~/dev_ws

export ROS_DOMAIN_ID=1
export ROS_NAMESPACE=robot0

# ROS2 command aliases
# alias cw='cd ~/dev_ws'
# alias cs='cd ~/dev_ws/src'
# alias ccd='colcon_cd'
# alias cb='cd ~/dev_ws && colcon build --symlink-install'
# alias cbs='colcon build --symlink-install'
# alias cbp='colcon build --symlink-install --packages-select'
# alias cbu='colcon build --symlink-install --packages-up-to'
# alias ct='colcon test'
# alias ctp='colcon test --packages-select'
# alias ctr='colcon test-result'
# alias rt='ros2 topic list'
# alias re='ros2 topic echo'
# alias rn='ros2 node list'
# alias testpub='ros2 run demo_nodes_cpp talker'
# alias testsub='ros2 run demo_nodes_cpp listener'
# alias testpubimg='ros2 run image_tools cam2image'
# alias testsubimg='ros2 run image_tools showimage'
" >> ~/.bashrc

source ~/.bashrc

echo "ros2-foxy install finished"
echo "make sure to change ROS_DOMAIN_ID and ROS_NAMESPACE correctly in .bashrc"