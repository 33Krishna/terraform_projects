#!/bin/bash
# A simple script copied to the instance during the file+remote-exec project

set -e

echo "Welcome to the Provisioner Project" | sudo tee /tmp/welcome_msg.txt
uname -a | sudo tee -a /tmp/welcome_msg.txt
cat /tmp/welcome_msg.txt