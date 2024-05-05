FROM  dustynv/ros:foxy-desktop-l4t-r35.1.0
# FROM dustynv/pytorch:2.1-r36.2.0
# so that installing tzdata will not prompt questions
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1A127079A92F09ED
# RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null

RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh neovim tmux git htop curl wget \
    net-tools iputils-ping\
    # init certificate for curl
    ca-certificates \
    # For x11 forwarding tests (xeyes, xclock etc.)
    x11-apps \
    # TODO: remove `sudo` when published
    build-essential libboost-all-dev libeigen3-dev \
    # For pytorch
    libopenblas-dev \
    cmake sudo

ARG USERNAME=real
ARG USER_UID
ARG USER_GID



# Add the new user with sudo access
# TODO: this should be removed when published
RUN groupadd -g ${USER_GID} ${USERNAME} && \
    useradd ${USERNAME}  -u ${USER_UID} -g ${USER_GID} -m -p "$(openssl passwd -1 real)"
RUN usermod -aG sudo ${USERNAME}
# Give ownership of the user's home directory to the new user
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
USER ${USERNAME}
# Set the user's home directory as the working directory
WORKDIR /home/${USERNAME}


############### Development Tools ###############

# install and setup zsh (with oh-my-zsh and plugins)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 
ARG PLUGIN_DIR=/home/${USERNAME}/.oh-my-zsh/custom/plugins/
RUN git clone https://github.com/marlonrichert/zsh-autocomplete.git $PLUGIN_DIR/zsh-autocomplete && \
    git clone https://github.com/zsh-users/zsh-autosuggestions $PLUGIN_DIR/zsh-autosuggestions  && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $PLUGIN_DIR/zsh-syntax-highlighting

# Set up zsh settings
RUN mv /home/${USERNAME}/.zshrc /home/${USERNAME}/.zshrc.bak && \
    echo 'export ZSH="$HOME/.oh-my-zsh"\nplugins=(\n  git\n  zsh-autosuggestions\n  zsh-autocomplete\n  zsh-syntax-highlighting\n  themes\n)\n' >> /home/${USERNAME}/.zshrc && \
    echo 'ZSH_THEME="eastwood"\nsource $ZSH/oh-my-zsh.sh' >> /home/${USERNAME}/.zshrc && \
    echo 'bindkey -M menuselect "\\r" .accept-line' >> /home/${USERNAME}/.zshrc && \
    echo 'bindkey -M menuselect -s "^R" "^_^_^R" "^S" "^_^_^S"' >> /home/${USERNAME}/.zshrc && \
    echo 'bindkey -M menuselect "\\e[D" .backward-char "\\eOD" .backward-char "\\e[C" .forward-char "\\eOC" .forward-char' >> /home/${USERNAME}/.zshrc && \
    echo 'bindkey '^H' backward-kill-word' >> /home/${USERNAME}/.zshrc

# Setup python env


RUN ARCH=$(uname -m) && wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${ARCH}.sh && \
    bash Miniforge3-Linux-${ARCH}.sh -b -p /home/${USERNAME}/miniforge3 && \
    rm Miniforge3-Linux-${ARCH}.sh && \
    /home/${USERNAME}/miniforge3/bin/conda init zsh && \
    /home/${USERNAME}/miniforge3/bin/mamba init zsh


# pre-install vscode server and helpful plugins
RUN git clone https://gist.github.com/0a16b6645ab7921b0910603dfb85e4fb.git /home/${USERNAME}/vscode-install && \
    chmod +x /home/${USERNAME}/vscode-install/download-vs-code-server.sh && \
    /home/${USERNAME}/vscode-install/download-vs-code-server.sh linux
ENV PATH=/home/${USERNAME}/.vscode-server/bin/default_version/bin:$PATH
RUN code-server --install-extension ms-python.python && \
    code-server --install-extension mhutchie.git-graph && \
    code-server --install-extension eamodio.gitlens && \
    code-server --install-extension github.copilot && \
    code-server --install-extension kevinrose.vsc-python-indent && \
    code-server --install-extension streetsidesoftware.code-spell-checker && \
    code-server --install-extension ms-python.black-formatter

# Enable using `code` command in terminal to open file or attach new window to a folder
RUN echo "export PATH=/home/${USERNAME}/.vscode-server/bin/default_version/bin/remote-cli:\$PATH" >> /home/${USERNAME}/.zshrc


USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		  libssl-dev \
		  libusb-1.0-0-dev \
            libgtk-3-dev \
            libglfw3-dev \
		  libgl1-mesa-dev \
		  libglu1-mesa-dev \
		  qtcreator \
		  udev && \
    if [ $(lsb_release -cs) = "bionic" ]; then \
        apt-get install -y --no-install-recommends python-dev; \
    else \
        apt-get install -y --no-install-recommends python2-dev; \
    fi \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

ARG LIBREALSENSE_VERSION=v2.50.0

RUN git clone --branch ${LIBREALSENSE_VERSION} --depth=1 https://github.com/IntelRealSense/librealsense && \
    cd librealsense && \
    mkdir build && \
    cd build && \
    cmake \
        -DBUILD_EXAMPLES=true \
	   -DFORCE_RSUSB_BACKEND=true \
	   -DBUILD_WITH_CUDA=true \
	   -DCMAKE_BUILD_TYPE=release \
	   -DBUILD_PYTHON_BINDINGS=bool:true \
	#    -DPYTHON_EXECUTABLE=/home/${USERNAME}/miniforge3/bin/python \
	#    -DPYTHON_INSTALL_DIR=$(/home/${USERNAME}/miniforge3/bin/python -c 'import sys; print(f"/usr/lib/python{sys.version_info.major}.{sys.version_info.minor}/dist-packages")') \
	   -DPYTHON_EXECUTABLE=/usr/bin/python3 \
	   -DPYTHON_INSTALL_DIR=$(python3 -c 'import sys; print(f"/usr/lib/python{sys.version_info.major}.{sys.version_info.minor}/dist-packages")') \
	   ../ && \
    make -j$(($(nproc)-1)) && \
    make install && \
    cd ../ && \
    cp ./config/99-realsense-libusb.rules /etc/udev/rules.d/ && \
    rm -rf librealsense

USER ${USERNAME}