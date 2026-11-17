#!/bin/bash
sudo apt install --no-install-recommends code libreoffice g++ build-essential
sudo mkdir -p /etc/skel/Desktop
sudo cp /usr/share/applications/libreoffice-startcenter.desktop /etc/skel/Desktop/
