ARG PLATFORM=arm64

FROM --platform=arm64 nvcr.io/nvidia/isaac/ros:aarch64-ros2_humble_fd3cefe09df8d19bf6cc82b0d57de78d AS base-arm64
FROM --platform=amd64 nvcr.io/nvidia/isaac/ros:x86_64-ros2_humble_79152baed139e9f4258734f3056c263a AS base-amd64
FROM base-${PLATFORM}

# Use bash as shell.
SHELL ["/bin/bash", "-c"]

ARG PLATFORM=arm64 
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
    apt -y autoremove && apt clean autoclean && rm -rf "/var/lib/apt/lists/*"

#########################################################################################################
# Apply patches.                                                                                        #
#########################################################################################################
WORKDIR "/"

RUN --mount=type=bind,source=".devcontainer/patches",target="/tmp/patches",ro \
    for PATCH in "/tmp/patches/"*.patch; do \
        patch -p1 < "${PATCH}"; \
    done

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

# Set our working directory.
WORKDIR "${CONTAINER_WORKSPACE_DIRECTORY}"
# Activate the previously created user.
USER "${USERNAME}"
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
COPY ".devcontainer-user" "/tmp/.devcontainer-user"

RUN --mount=type=cache,target="/var/cache/apt" \
    if [ -f "/tmp/.devcontainer-user/user_install_dependencies" ]; then \
        sudo chmod +x "/tmp/.devcontainer-user/user_install_dependencies" && \
        "/tmp/.devcontainer-user/user_install_dependencies" \
        sudo apt -y autoremove && sudo apt clean autoclean && sudo rm -rf "/var/lib/apt/lists/*"; \
    fi
