#!/usr/bin/env bash
# Zenity GUI Installer for Cursor IDE v6.9.35

set -euo pipefail

VERSION="6.9.35"
APPIMAGE_FILE="01-appimage_v6.9.35.AppImage"
INSTALL_DIR="/opt/cursor"

# Check if zenity is available
if ! command -v zenity >/dev/null 2>&1; then
    echo "Error: Zenity is not installed"
    echo "Install with: sudo apt-get install zenity"
    exit 1
fi

# Check if running in GUI environment
if [[ -z "${DISPLAY:-}" ]]; then
    echo "Error: No display environment detected"
    echo "Zenity requires a GUI environment (X11/Wayland)"
    exit 1
fi

# Welcome dialog
if ! zenity --question --title="Cursor IDE Installer" \
    --text="Welcome to Cursor IDE v$VERSION installer.\n\nThis will install Cursor IDE to your system.\n\nContinue?"; then
    zenity --info --text="Installation cancelled."
    exit 0
fi

# Check for AppImage
if [[ ! -f "$APPIMAGE_FILE" ]]; then
    zenity --error --text="AppImage file not found: $APPIMAGE_FILE"
    exit 1
fi

# Progress dialog for installation
(

echo "10" ; echo "# Creating installation directory..."
sudo mkdir -p "$INSTALL_DIR"

echo "30" ; echo "# Copying AppImage..."
sudo cp "$APPIMAGE_FILE" "$INSTALL_DIR/cursor.AppImage"

echo "50" ; echo "# Setting permissions..."
sudo chmod +x "$INSTALL_DIR/cursor.AppImage"

# Install icon

echo "60" ; echo "# Installing icon..."
if [[ -f "cursor.svg" ]]; then
  sudo cp "cursor.svg" "$INSTALL_DIR/cursor.svg"
else
  sudo tee "$INSTALL_DIR/cursor.svg" > /dev/null <<'ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" fill="#007ACC"/>
  <text x="32" y="40" font-family="Arial" font-size="24" fill="white" text-anchor="middle">C</text>
</svg>
ICON
fi

echo "70" ; echo "# Creating symlink..."
sudo ln -sf "$INSTALL_DIR/cursor.AppImage" /usr/local/bin/cursor

echo "90" ; echo "# Creating desktop entry..."
sudo tee /usr/share/applications/cursor.desktop > /dev/null <<'DESKTOP'
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=/usr/local/bin/cursor %F
Icon=/opt/cursor/cursor.svg
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
DESKTOP

echo "100" ; echo "# Installation complete!"
) | zenity --progress --title="Installing Cursor IDE" --percentage=0 --auto-close

# Success dialog
zenity --info --title="Installation Complete" \
    --text="Cursor IDE v$VERSION has been installed successfully!\n\nYou can now:\n• Run 'cursor' from terminal\n• Find Cursor in your applications menu"

echo "Cursor IDE installed successfully via Zenity GUI!"
