ARG PLATFORM

FROM --platform=arm64 nvcr.io/nvidia/isaac/ros:aarch64-ros2_humble_fd3cefe09df8d19bf6cc82b0d57de78d AS base-arm64
FROM --platform=amd64 nvcr.io/nvidia/isaac/ros:x86_64-ros2_humble_79152baed139e9f4258734f3056c263a AS base-amd64
FROM base-${PLATFORM}

# Use bash as shell.
SHELL ["/bin/bash", "-c"]

ARG PLATFORM 
ARG LOCAL_DEVCONTAINER_USER_DIRECTORY 
ARG CONTAINER_REPOSITORY_MOUNT_POINT CONTAINER_WORKSPACE_DIRECTORY 

USER root

#########################################################################################################
# Update and install required apt and pip dependencies.                                                 #
#########################################################################################################
RUN --mount=type=cache,target="/var/cache/apt" \
    apt update && apt-get install -y --no-install-recommends --allow-downgrades \
        iproute2 \
        usbutils \
        python3-colcon-mixin \
        v4l-utils \
        # Fix taken from "https://github.com/IntelRealSense/realsense-ros/issues/3203" for error during colcon build: 
        # The imported target "opencv_core" references the file "/usr/lib/libopencv_core.so.4.8.0" but this file does not exist.
        libopencv-dev=4.5.4+dfsg-9ubuntu4 && \
    apt -y autoremove && apt clean autoclean && rm -rf "/var/lib/apt/lists/*"

RUN pip install \
        python-can \
        piper_sdk

#########################################################################################################
# Apply patches.                                                                                        #
#########################################################################################################
WORKDIR "/"
COPY ".devcontainer/patches" "/tmp/patches"

RUN for PATCH in "/tmp/patches/"*.patch; do \
        patch -p1 < "${PATCH}"; \
    done && \
    rm -rf "/tmp/patches"

#########################################################################################################
# Create a non-root user:                                                                               #
# - https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_creating-a-nonroot-user.  #
#########################################################################################################
ARG USERNAME=developer
ENV USERNAME=${USERNAME}
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN CONFLICTING_GROUPNAME=$(getent group "${USER_GID}" | cut -d: -f1) && \
    groupmod -o --gid "${USER_GID}" -n "${USERNAME}" "${CONFLICTING_GROUPNAME}" && \
    useradd --no-log-init --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" && \
    echo "${USERNAME}" ALL=\(root\) NOPASSWD:ALL > "/etc/sudoers.d/${USERNAME}" && \
    chmod 0440 "/etc/sudoers.d/${USERNAME}" && \
    usermod -aG video,plugdev,sudo "${USERNAME}"

# Activate the previously created user.
USER "${USERNAME}"
# Set our working directory.
WORKDIR "${CONTAINER_WORKSPACE_DIRECTORY}"
# Ensure we can read/write to the working directory.
RUN sudo chmod a+rwx "."

#########################################################################################################
# Setup ROS2.                                                                                           #
#########################################################################################################
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> "${HOME}/.bashrc" && \
    ln -s "${CONTAINER_REPOSITORY_MOUNT_POINT}/.devcontainer/.vscode" "${CONTAINER_WORKSPACE_DIRECTORY}" && \
    colcon mixin add default "https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml" && \
    colcon mixin update default && \
    mkdir -p "${HOME}/.colcon" && \
    echo "build: {mixin: [compile-commands]}" >> "${HOME}/.colcon/defaults.yaml" && \
    echo "[ -f ${CONTAINER_REPOSITORY_MOUNT_POINT}/colcon_ws/install/setup.bash ] && source ${CONTAINER_REPOSITORY_MOUNT_POINT}/colcon_ws/install/setup.bash" >> "/home/${USERNAME}/.bashrc"

#########################################################################################################
# Install user dependencies.                                                                            #
#########################################################################################################
COPY "${LOCAL_DEVCONTAINER_USER_DIRECTORY}" "/tmp/.devcontainer-user"

RUN if [ -f "/tmp/user_install_dependencies.sh" ]; then \
        chmod +x "/tmp/user_install_dependencies.sh" && \
        "/tmp/user_install_dependencies.sh" && \
        rm "/tmp/user_install_dependencies.sh"; \
    fi 
