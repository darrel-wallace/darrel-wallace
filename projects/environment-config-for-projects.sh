#!/bin/bash
#
# === New Laptop Setup Script for AI/Cloud Projects ===
# This script will install all required tools:
# 1. Git (Source Control)
# 2. NVM / Node.js / NPM (For AI CLIs)
# 3. GitHub SSH Authentication
# 4. Google Gemini CLI & Anthropic Claude CLI
# 5. Clones your project repositories

echo "--- 1. Installing Dependencies (Git & Node.js/NPM) ---"

# This assumes a Debian-based system (like Ubuntu/WSL).
# For other systems, use your package manager (e.g., brew, yum).
sudo apt update
sudo apt install -y git curl

# Install nvm (Node Version Manager) to get Node.js
echo "--- Installing nvm (Node Version Manager)... ---"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# This next part is critical. nvm needs to be sourced by your shell.
echo "---"
echo "!!============================================================!!"
echo "!!  ACTION REQUIRED: Please CLOSE and REOPEN your terminal now  !!"
echo "!!  to activate nvm. Then, re-run this script, OR              !!"
echo "!!  manually run the rest of the commands below.               !!"
echo "!!============================================================!!"
echo "   (This script will exit in 10 seconds...)"
sleep 10
exit 0

# --- (After reopening terminal, continue from here) ---

echo "--- (Re-opened terminal) Installing Node.js v20 ---"
nvm install 20
nvm use 20
echo "--- Node.js version: $(node -v) ---"
echo "--- NPM version: $(npm -v) ---"

# --- 2. Configure Git Identity ---
echo "--- 2. Configuring Git Identity ---"
# Use the same name and email you use for GitHub
git config --global user.name "Darrel Wallace"
git config --global user.email "darrel.l.wallace.civ@gmail.com"
echo "--- Git config complete. ---"

# --- 3. Set up GitHub SSH Key ---
echo "--- 3. Creating new SSH Key ---"
echo "   When prompted, use the *same email* as your GitHub account."
echo "   It is highly recommended to use a secure passphrase."
ssh-keygen -t ed25519 -C "darrel.l.wallace.civ@gmail.com"

echo "--- Starting the SSH agent... ---"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
# Note: You will be prompted for your passphrase here if you set one.

echo "---"
echo "--- Your new Public Key (copy all of this): ---"
cat ~/.ssh/id_ed25519.pub
echo "---"
echo "!!============================================================!!"
echo "!!  ACTION REQUIRED: Add the key above to your GitHub account:  !!"
echo "!!    1. Go to: https://github.com/settings/keys"
echo "!!    2. Click 'New SSH key'"
echo "!!    3. Paste the key and save it."
echo "!!============================================================!!"
echo "   Press Enter here when you are done..."
read

echo "--- Testing SSH connection... ---"
ssh -T git@github.com
# You should see: "Hi darrel-wallace! You've successfully authenticated..."

# --- 4. Install AI CLI Tools ---
echo "--- 4. Installing Gemini and Claude CLIs ---"
npm install -g @google/gemini-cli
npm install -g @anthropic-ai/claude-code
echo "--- AI tools installed. ---"

# --- 5. Clone Your Projects ---
echo "--- 5. Cloning your projects into '~/projects' ---"
mkdir -p ~/projects
cd ~/projects

echo "Cloning your portfolio repository..."
git clone git@github.com:darrel-wallace/darrel-wallace.git

echo "Cloning your vehicle research project..."
git clone git@github.com:darrel-wallace/off-road-vehicle-research.git

echo "--- All projects cloned. ---"

# --- 6. Authenticate AI CLIs ---
echo "--- 6. Authenticating AI CLIs ---"
echo "   This will open your browser to log in."
echo "   Authenticating Gemini CLI..."
gemini auth

echo "   Authenticating Claude Code..."
claude auth
# Note: The auth command might be different (e.g., `claude setup-token` or just run `claude`)
# If `claude auth` fails, just run `claude` and it will prompt you.

echo "---"
echo "--- ✅ New laptop setup is complete! ---"
echo "--- You are now in the '~/projects' directory. ---"
cd ~/projects/off-road-vehicle-research
ls -F
