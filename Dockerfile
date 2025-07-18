FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl wget ca-certificates \
    libfuse2 python3 python3-pip \
    xvfb fluxbox supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Flask
RUN pip3 install flask

# Create user
RUN useradd -m cursor

# Copy files
COPY 01-appimage_v6.9.32.AppImage /opt/cursor/cursor.AppImage
COPY 06-launcherplus_v6.9.32_fixed.py /opt/cursor/
COPY cursor.svg /opt/cursor/
COPY cursor.desktop /usr/share/applications/

# Set permissions
RUN chmod +x /opt/cursor/cursor.AppImage
RUN ln -s /opt/cursor/cursor.AppImage /usr/local/bin/cursor

# Expose ports
EXPOSE 8080

# Start command
CMD ["python3", "/opt/cursor/06-launcherplus_v6.9.32_fixed.py"]
