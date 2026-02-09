#!/bin/bash
set -ouex pipefail

# https://github.com/ublue-os/bluefin/discussions/3414#discussioncomment-14722867
# to evaluate whether necessary or not, /boot meant to be immutable and configured by bootc image builder itself
# assessed to waive - because not a lot of people have physical access to the vm itself

chmod 600 /boot/grub2/grub.cfg
