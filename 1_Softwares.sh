#!/bin/bash
sudo apt update
sudo apt install --no-install-recommends code libreoffice g++ build-essential
sudo mkdir -p /etc/skel/Desktop
sudo cp /usr/share/applications/libreoffice-startcenter.desktop /etc/skel/Desktop/libreoffice-startcenter.desktop
sudo cp /usr/share/applications/com.microsoft.VSCode.desktop /etc/skel/Desktop/com.microsoft.VSCode.desktop
code --install-extension ms-vscode.cpptools
