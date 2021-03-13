FROM amd64/ubuntu:18.04

# install python reqs & things to build bossac
RUN apt-get update && apt-get install -y \
    build-essential \
    libwxgtk3.0-gtk3-dev \
    libwxgtk3.0-gtk3 \
    git \
    python \
    python3 \
    python-pip

RUN pip install pyserial

WORKDIR /workdir/
