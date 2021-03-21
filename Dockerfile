# Author: Satish Gaikwad <satish@satishweb.com>
FROM     ubuntu:20.04
LABEL MAINTAINER "Satish Gaikwad <satish@satishweb.com>"

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

# Disable auto installation of recommended packages, too many unwanted packages gets installed without this 
RUN apt-config dump | grep -we Recommends -e Suggests | sed s/1/0/ | tee /etc/apt/apt.conf.d/999norecommend

# Install basic system packages
RUN apt-get install -y \
    ca-certificates \
    software-properties-common \
    && apt-get clean

# Install desktop environment and other system tools
RUN apt-get update && apt-get -y install \
    xrdp \
    xorg \
    xfce4 \
    supervisor \
    vim \
    openssh-server \
    nano \
    xserver-xorg-video-all \
    xserver-xorg-video-dummy \
    xfonts-cyrillic \
    xfonts-100dpi \
    xfonts-75dpi \
    mesa-utils \
    mesa-utils-extra \
    xfonts-scalable \
    xorgxrdp \
    dbus-x11 \
    kmod \
    procps \
    firefox \
    xfce4-appmenu-plugin \
    xfce4-datetime-plugin \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-taskmanager \
    desktop-file-utils \
    fonts-dejavu \
    less \
    multitail \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-ubuntu \
    menu \
    menu-xdg \
    net-tools \
    xdg-utils \
    xfce4-statusnotifier-plugin \
    xfce4-whiskermenu-plugin \
    xfonts-base \
    xfpanel-switch \
    xinput \
    xutils \
    xz-utils \
    zenity \
    zip \
    bash \
    bash-completion \
    binutils \
    file \
    iputils-ping \
    pavucontrol \
    pciutils \
    psmisc \
    fakeroot \
    command-not-found \
    fuse \
    xfonts-base \
    xterm \
    sudo \
    wget \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*deb

## XRDP Config
RUN printf '%s\n' 'session required pam_env.so readenv=1' >> /etc/pam.d/xrdp-sesman
# send xrdp services output to stdout
RUN ln -sf /dev/stdout /var/log/xrdp.log
RUN ln -sf /dev/stdout /var/log/xrdp-sesman.log

# Disable forking, new cursors and enable high tls ciphers for xrdp
RUN sed -i "\
  s/fork=true/fork=false/g; \
  s/\#tls_ciphers=HIGH/tls_ciphers=HIGH/g; \
  s/^new_cursors=true/new_cursors=false/g \
" /etc/xrdp/xrdp.ini

# Disable root login and syslog logging for xrdp-sesman
RUN sed -i "\
  s/AllowRootLogin=true/AllowRootLogin=false/g; \
  s/EnableSyslog=1/EnableSyslog=0/g \
" /etc/xrdp/sesman.ini

# Disable light-locker
RUN ln -s /usr/bin/true /usr/bin/light-locker
COPY files/supervisor.xrdp.conf /etc/supervisor/conf.d/
# Remove annoying multiple auth popups after rdp login
COPY files/46-allow-update-repo.pkla /etc/polkit-1/localauthority/50-local.d/46-allow-update-repo.pkla
# Allow all users to start xserver
RUN echo 'allowed_users=anybody' > /etc/X11/Xwrapper.config
RUN chmod g+w /etc/xrdp
RUN chmod u+s /usr/sbin/xrdp-sesman
RUN chmod u+s /usr/sbin/xrdp

## User Config
RUN groupadd -g 1000 guest
RUN useradd -u 1000 -g 1000 -d /home/guest -s /bin/bash -c "Guest User" guest
# Add xrdp user to ssl-cert to allow access to cert files generated by system
RUN usermod -a -G ssl-cert xrdp
# Allow guest to be sudo to install any new packages
RUN usermod -a -G sudo guest
RUN mkdir /home/guest
RUN echo 'guest:guest' | chpasswd
# Copy xsessionrc file as template inside.
# Docker entrypint script will copy this file into guest home dir.
COPY files/xsessionrc /xsessionrc
RUN chown -Rf guest:guest /home/guest/

# DBus config
RUN mkdir -p /var/run/dbus
RUN chown messagebus:messagebus /var/run/dbus
RUN dbus-uuidgen > /var/lib/dbus/machine-id

COPY docker-entrypoint /docker-entrypoint

EXPOSE 3389

ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n" ]
