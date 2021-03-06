FROM osrf/ros:noetic-desktop-full

###
### PROXY
###

# ENV HTTP_PROXY="http://172.17.0.1:10809"
# ENV HTTPS_PROXY="http://172.17.0.1:10809"
# ENV http_proxy="http://172.17.0.1:10809"
# ENV https_proxy="http://172.17.0.1:10809"

# RUN sudo touch /etc/apt/apt.conf.d/proxy.conf \ 
#     && sudo echo "Acquire::http::Proxy \"http://172.17.0.1:10809\";" > /etc/apt/apt.conf.d/proxy.conf \ 
#     && sudo echo "Acquire::http::Proxy \"http://172.17.0.1:10809\";" >> /etc/apt/apt.conf.d/proxy.conf \ 
#     && sudo cat /etc/apt/apt.conf.d/proxy.conf

###
### VNC
###

ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD ./src/common/xfce/ $HOME/

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

RUN ln /bin/python2 /usr/bin/python

###
### Development Tools
###

WORKDIR /root/ws
ENV HOME=/root

RUN echo "deb http://packages.ros.org/ros/ubuntu trusty main" > /etc/apt/sources.list.d/ros-latest.list
RUN apt-key adv --keyserver "hkp://ha.pool.sks-keyservers.net" --recv-key "0xB01FA116" \
    || { wget "https://raw.githubusercontent.com/ros/rosdistro/master/ros.key" -O - | sudo apt-key add -; }
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -cs` main" > /etc/apt/sources.list.d/ros-latest.list' \ 
    && apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# install build dependency
RUN sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list \ 
    && apt-get update \ 
    && apt-get install --no-install-recommends -y \
    apt-utils \
    wget \
    ca-certificates \
    git \
    sudo \
    nano \
    less \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-catkin \
    build-essential \
    python3-colcon-common-extensions \
    python3-catkin-tools \
    python3-osrf-pycommon \
    python3-rosdep \
    python3-wstool \
    ros-${ROS_DISTRO}-catkin

WORKDIR /root/build

# install tilix
RUN sudo apt-get install -y \
    tilix

# install zsh
RUN git clone https://github.com/tccoin/easy-linux.git \
    && cd easy-linux \
    && ./zsh.sh \
    && touch /root/.z

ADD src/.zshrc /headless

# install gitstatus
# https://github.com/romkatv/gitstatus/releases/tag/v1.3.1
RUN mkdir -p /root/.cache/gitstatus \
    && wget https://github.com/romkatv/gitstatus/releases/download/v1.3.1/gitstatusd-linux-x86_64.tar.gz -O - \
    | tar -zx -C /root/.cache/gitstatus/

# install conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && bash ~/miniconda.sh -b -p $HOME/miniconda \
    && rm ~/miniconda.sh

###
### Program Dependency
###

WORKDIR /root/build

RUN wget https://github.com/tccoin/container-static-files/releases/download/Galaxy_Linux/Galaxy_Linux-x86_Gige-U3_32bits-64bits_1.2.1911.9122.tar.gz -O - \
    | tar -zx \
    && cd Galaxy_Linux-x86_Gige-U3_32bits-64bits_1.2.1911.9122/ \
    && echo '\n' | ./Galaxy_camera.run

RUN wget https://github.com/tccoin/container-static-files/releases/download/Galaxy_Linux/Galaxy_Linux_Python_2.0.2008.9111.tar.gz -O - \
    | tar -zx

WORKDIR /root

SHELL ["/bin/bash", "-l", "-c"]

RUN mkdir -p catkin_ws/src \
    && cd catkin_ws \
    && git clone https://github.com/tccoin/galaxy_camera.git src/galaxy_camera \
    && source /opt/ros/noetic/setup.bash \
    && catkin_make

RUN PATH="$HOME/miniconda/bin:$PATH" conda install -y numpy opencv=3.4.2 python=3.7 -c menpo

RUN PATH="$HOME/miniconda/bin:$PATH" conda clean -afy

RUN /root/miniconda/bin/pip3 install opencv-contrib-python pyserial toolz

RUN cd ~/build/Galaxy_Linux_Python_2.0.2008.9111/api/ \
    && /root/miniconda/bin/pip3 install .

ENTRYPOINT ["/bin/zsh"]