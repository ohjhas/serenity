#!/bin/bash
# OmegaLinux NEXT Fixup script that runs before finishing calamares installation, hopefully i can do better after release.
# 15 February 2026

# Populate arch keyrings, without this the average user wouldnt be able to even use OLN at all.
pacman-key --init
pacman-key --populate archlinux
pacman -Sy