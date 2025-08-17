FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

# Flutter SDK installieren
RUN apt-get update && apt-get install -y \
    curl \
    git \
    git-lfs \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    fonts-firacode \
    && rm -rf /var/lib/apt/lists/*

USER vscode

# Git LFS global für den vscode-Benutzer aktivieren
RUN git lfs install

# Flutter SDK herunterladen und installieren
RUN git clone https://github.com/flutter/flutter.git -b stable /home/vscode/flutter
ENV PATH="$PATH:/home/vscode/flutter/bin"

# Flutter Web-Abhängigkeiten
RUN flutter config --enable-web
RUN flutter precache --web
