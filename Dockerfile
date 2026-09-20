FROM ghcr.io/catthehacker/ubuntu:act-latest

USER root

# System packages for building, Windows MSVC, and Android
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang lld llvm unzip ca-certificates openjdk-17-jdk curl git \
    && rm -rf /var/lib/apt/lists/*

# Fix the llvm-lib symlink for MSVC linking
RUN ln -sf /usr/bin/llvm-ar /usr/local/bin/llvm-lib

# Install fresh Stable Rust globally (accessible to all users)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain stable \
    --profile default && \
    chmod -R a+w /usr/local/rustup /usr/local/cargo

# Add the cross-compilation targets
RUN rustup target add \
    aarch64-linux-android \
    x86_64-pc-windows-msvc

# Pre-install cargo tools
RUN cargo install --locked \
    cargo-xwin@0.23.1 \
    b3sum@1.8.6 \
    cargo-ndk && \
    chmod -R a+rwX /usr/local/cargo

# Android SDK & NDK Setup (Mirrors GitHub Actions Runner Environment)
ENV ANDROID_HOME=/usr/local/lib/android/sdk \
    ANDROID_SDK_ROOT=/usr/local/lib/android/sdk

RUN mkdir -p ${ANDROID_HOME}/ndk ${ANDROID_HOME}/cmdline-tools

# Install Android SDK Command-Line Tools
RUN curl -fsSL -o /tmp/cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip -q /tmp/cmdline.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline.zip

# Install NDK r26d (Build 26.3.11579264) - DEFAULT
RUN curl -fsSL -o /tmp/ndk26.zip https://dl.google.com/android/repository/android-ndk-r26d-linux.zip && \
    unzip -q /tmp/ndk26.zip -d ${ANDROID_HOME}/ndk && \
    mv ${ANDROID_HOME}/ndk/android-ndk-* ${ANDROID_HOME}/ndk/26.3.11579264 && \
    ln -s ${ANDROID_HOME}/ndk/26.3.11579264 ${ANDROID_HOME}/ndk/r26d && \
    rm /tmp/ndk26.zip

# Install NDK r30 - LATEST
RUN curl -fsSL -o /tmp/ndk30.zip https://dl.google.com/android/repository/android-ndk-r30-linux.zip && \
    unzip -q /tmp/ndk30.zip -d ${ANDROID_HOME}/ndk && \
    mv ${ANDROID_HOME}/ndk/android-ndk-* ${ANDROID_HOME}/ndk/30.0.16248370 && \
    ln -s ${ANDROID_HOME}/ndk/30.0.16248370 ${ANDROID_HOME}/ndk/r30 && \
    rm /tmp/ndk30.zip

# Set global permissions so all users can execute tools
RUN chmod -R a+rX ${ANDROID_HOME}

# Define all GitHub Actions compatible Environment Variables
ENV ANDROID_NDK=/usr/local/lib/android/sdk/ndk/26.3.11579264 \
    ANDROID_NDK_HOME=/usr/local/lib/android/sdk/ndk/26.3.11579264 \
    ANDROID_NDK_ROOT=/usr/local/lib/android/sdk/ndk/26.3.11579264 \
    NDK_HOME=/usr/local/lib/android/sdk/ndk/26.3.11579264 \
    ANDROID_NDK_LATEST_HOME=/usr/local/lib/android/sdk/ndk/30.0.16248370

# Add SDK & Default NDK LLVM toolchain to PATH
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"
