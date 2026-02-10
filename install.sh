#!/bin/bash

# Dotfiles installation script for GitHub Codespaces
# This script sets up the development environment for the Rover project

set -e

echo "Setting up Rover development environment..."

# Copy personal.py settings to the web project
echo "Copying personal.py to web project..."
cp /workspaces/.codespaces/.persistedshare/dotfiles/personal.py /workspaces/web/src/aplaceforrover/rover/settings/personal.py

# Set up Stripe webhook environment variable for automatic webhook listening
echo "Setting up Stripe webhook environment..."
echo 'export DC_PARAMS="--profile stripe"' >> ~/.bashrc
source ~/.bashrc
