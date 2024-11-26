#!/bin/bash

CONDA_VERSION="2024.06-1"
CONDA_CHECKSUM="539bb43d9a52d758d0fdfa1b1b049920ec6f8c6d15ee9fe4a423355fe551a8f7"
CONDA_DIR=$HOME/anaconda3

# NOTES
# - As of 2024-11-25 version [2024.10-1] has a bad checksum, and the installation crashes in Ubuntu 22.04

sudo echo "Install / Setup for raisimGymTorch environment"

# Check if the directory exists
if [ -d "$CONDA_DIR" ]; then
    echo "Directory $CONDA_DIR exists. Skipping conda installation"
else
    echo "Directory $CONDA_DIR does not exist. Installing conda first..."

    while true; do
        read -p "[IMPORTANT] Conda does not provide the api for accessing latest installers. If you continue, you will proceed with [${CONDA_VERSION}] Is this okay? (Y/n) >> " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Please check [https://repo.anaconda.com/archive/] and edit the CONDA_VERSION and CONDA_CHECKSUM variable in this script [dev-choking/ubuntu/raisim-gym-torch-env.sh]...
            
            (exited without installing anything)";
                    exit;;
            *     ) echo "Please answer yes or no.";;
        esac
    done

    echo "Installing Conda ${CONDA_VERSION}"

    cd ~/Downloads/
    wget https://repo.anaconda.com/archive/Anaconda3-${CONDA_VERSION}-Linux-x86_64.sh

    # Checking Hash value
    sudo echo "${CONDA_CHECKSUM}" Anaconda3-${CONDA_VERSION}-Linux-x86_64.sh | sha256sum --check

    # bash ~/Anaconda3-${CONDA_VERSION}-Linux-x86_64.sh -b -p $HOME/anaconda3

    sudo rm -rf $CONDA_DIR

    bash Anaconda3-${CONDA_VERSION}-Linux-x86_64.sh -p $CONDA_DIR

    # If you'd prefer that conda's base environment not be activated on startup:
    # conda config --set auto_activate_base false
    # You can undo this by running `conda init --reverse $SHELL`

    conda config --set auto_activate_base false
fi

# other (non-python) tools (most should have been done with [raisim.sh])
sudo apt update 
sudo apt install -y git terminator libeigen3-dev doxygen mercurial valgrind liburdfdom-dev curl minizip ffmpeg libyaml-cpp-dev neofetch
sudo snap install nvtop
# (optional) Jetbrains IDE's
# sudo snap install cmake --classic
# sudo snap install rider --classic 
# sudo snap install clion --classic 


# installing cuda toolkit [12.4.1]

if command -v nvcc >/dev/null 2>&1; then
    echo "CUDA is installed:"
    nvcc --version
else
    echo -e "/nCUDA is not detected. Installing CUDA [12.4]"
    # .run file route (tried and failed)
    # wget https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run
    # sudo sh cuda_12.4.1_550.54.15_linux.run
    # sudo sh cuda_12.4.1_550.54.15_linux.run --override --silent --toolkit

    # apt repo (deb-local) route
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2204-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-12-4

    rm ~/dev-choking/ubuntu/cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
    
    if command -v nvcc >/dev/null 2>&1; then
        echo "CUDA installation complete"
        nvcc --version
    else
        echo "NVCC cannot detect cuda. Adding explicit PATH into [profile.d]"
        sudo cp -f ~/dev-choking/ubuntu/assets/cuda_path.sh /etc/profile.d/
        sudo chmod +x /etc/profile.d/cuda_path.sh

        source /etc/profile.d/cuda_path.sh

        echo "\n\n CUDA installation complete!"
        nvcc --version
    fi

fi

# creating conda env
if [ -d "$CONDA_DIR/envs/raisim" ]; then
    echo -e "\nConda env [raisim] already exists."
else
    echo -e "\nCreating new conda env [raisim]..."
    conda create -n raisim python=3.9
    # as of 2024-11-25, python 3.10 and higher is not supported by pybind
fi

source $CONDA_DIR/etc/profile.d/conda.sh
conda activate raisim
pip install numpy tensorboard ruamel.yaml==0.17.40
# ruamel.yaml 0.17.40 supports methods that are depricated today (0.18.*)

# installing cudnn and torch
# conda install -y -c nvidia cudnn
# torch [compatible with 12.4]
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124
# can omit torchaudio (since it isn't used often)

# building raisimGymTorch for the first time
cd ~/raisim_ws/raisimLib/raisimGymTorch
conda activate raisim && python setup.py develop

# adding user aliases to bashrc
echo "

# raisimGymTorch aliases (from [dev-choking])
alias car='conda activate raisim'
alias setup='python setup.py develop --CMAKE_PREFIX_PATH \$RAISIM_PREFIX_PATH'

" >> ~/.bashrc

# running the builtin example
echo "<dev-choking> running example. Exit to finish installation"
echo "(run raisim_monitor/nvtop in another terminal)"

python raisimGymTorch/env/envs/rsg_anymal/runner.py

