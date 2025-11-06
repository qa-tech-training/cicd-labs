#!/bin/bash
installAnsible() {
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo apt-add-repository --update --yes ppa:ansible/ansible
    sudo apt-get install -y ansible
}

which ansible \
  && echo "Nothing to do, ansible already installed" \
  || installAnsible

# Adds installation script to bashrc, to ensure that ansible installation persists
cat - <<EOF | tee -a ~/.bashrc
installAnsible() {
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo apt-add-repository --update --yes ppa:ansible/ansible
    sudo apt-get install -y ansible
}

which ansible \
  && echo "Nothing to do, ansible already installed" \
  || installAnsible
EOF