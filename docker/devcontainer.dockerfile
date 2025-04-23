ARG PLATFORM=arm64

FROM --platform=arm64 nvcr.io/nvidia/isaac/ros:aarch64-ros2_humble_fd3cefe09df8d19bf6cc82b0d57de78d AS base-arm64
FROM --platform=amd64 nvcr.io/nvidia/isaac/ros:x86_64-ros2_humble_79152baed139e9f4258734f3056c263a AS base-amd64
FROM base-${PLATFORM}

# Use bash as shell.
SHELL ["/bin/bash", "-c"]

ARG PLATFORM=arm64
ENV PLATFORM=${PLATFORM}

ARG ROS_DOMAIN_ID
ENV ROS_DOMAIN_ID=${ROS_DOMAIN_ID}

ARG CONTAINER_WORKSPACE_DIRECTORY
ENV WORKSPACE_DIRECTORY=${CONTAINER_WORKSPACE_DIRECTORY}

ARG CONTAINER_REPOSITORY_MOUNT_POINT
ENV REPOSITORY_DIRECTORY=${CONTAINER_REPOSITORY_MOUNT_POINT}

USER root

#########################################################################################################
# Update and install required apt and pip dependencies.                                                 #
#########################################################################################################
RUN --mount=type=cache,id=apt_cache_devcontainer,target="/var/cache/apt" \
    apt update && apt install -y --no-install-recommends \
        iproute2 \
        iperf3 \
        bmon \
        usbutils \
        dotnet-sdk-6.0 \
        python3-colcon-mixin && \
    apt -y autoremove && apt clean && rm -rf "/var/lib/apt/lists/*"

#########################################################################################################
# Apply patches.                                                                                        #
#########################################################################################################
WORKDIR "/"

RUN --mount=type=bind,source=".devcontainer/patches",target="/tmp/patches",ro \
    for PATCH in "/tmp/patches/${PLATFORM}/"*.patch; do \
        # Check if the patch file actually exists (glob might return the pattern if no files match).
        [ -f "${PATCH}" ] || continue; \
        patch -p1 --forward <"${PATCH}"; \
    done

#########################################################################################################
# Create a non-root user.                                                                               #
#########################################################################################################
ARG USERNAME=developer
ENV USERNAME=${USERNAME}
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN if [ ! $(getent group "${USER_GID}") ]; then \
        groupadd --gid "${USER_GID}" "${USERNAME}" &>"/dev/null"; \
    else \
        CONFLICTING_GROUPNAME=`getent group "${USER_GID}" | cut -d: -f1` && \
        groupmod -o --gid "${USER_GID}" -n "${USERNAME}" "${CONFLICTING_GROUPNAME}"; \
    fi; \
    \
    if [ ! $(getent passwd "${USER_UID}") ]; then \
        useradd --no-log-init --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" &>"/dev/null"; \
    else \
        CONFLICTING_USERNAME=`getent passwd "${USER_UID}" | cut -d: -f1` && \
        usermod -l "${USERNAME}" -u "${USER_UID}" -m -d "/home/${USERNAME}" "${CONFLICTING_USERNAME}" &>"/dev/null" && \
        mkdir -p "/home/${USERNAME}" && \
        # Wipe files that may create issues for users with large uid numbers.
        rm -f "/var/log/lastlog /var/log/faillog"; \
    fi; \
    \
    chown "${USERNAME}":"${USERNAME}" "/home/${USERNAME}" && \
    echo "${USERNAME}" ALL=\(root\) NOPASSWD:ALL >"/etc/sudoers.d/${USERNAME}" && \
    chmod 0440 "/etc/sudoers.d/${USERNAME}" && \
    usermod -aG video,plugdev,sudo "${USERNAME}";

# Set our working directory.
WORKDIR "${CONTAINER_WORKSPACE_DIRECTORY}"
# Activate the previously created user.
USER "${USERNAME}"
# Ensure we can read/write to the working directory.
RUN sudo chmod a+rwx "." && \
    # Fix for empty .bashrc and non-existing .profile when using amd64 base image.
    [[ ${PLATFORM} == amd64 ]] && cat "/etc/skel/.bashrc" >>"/home/${USERNAME}/.bashrc" && cat "/etc/skel/.profile" >>"/home/${USERNAME}/.profile" || true

#########################################################################################################
# Setup ROS2.                                                                                           #
#########################################################################################################
COPY --chown=${USERNAME}:${USERNAME} ".devcontainer/.vscode" "${CONTAINER_WORKSPACE_DIRECTORY}/.vscode"

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >>"${HOME}/.bashrc" && \
    colcon mixin add default "https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml" && \
    colcon mixin update default && \
    mkdir -p "${HOME}/.colcon" && \
    echo "build: {mixin: [compile-commands]}" >>"${HOME}/.colcon/defaults.yaml" && \
    echo "[ -f ${CONTAINER_REPOSITORY_MOUNT_POINT}/colcon_ws/install/setup.bash ] && source ${CONTAINER_REPOSITORY_MOUNT_POINT}/colcon_ws/install/setup.bash" >>"/home/${USERNAME}/.bashrc"

ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

#########################################################################################################
# Install user dependencies.                                                                            #
#########################################################################################################
COPY ".devcontainer-user" "/tmp/.devcontainer-user"

RUN --mount=type=cache,id=apt_cache_devcontainer,target="/var/cache/apt" \
    if [ -f "/tmp/.devcontainer-user/user_install_dependencies" ]; then \
        sudo chmod +x "/tmp/.devcontainer-user/user_install_dependencies" && \
        "/tmp/.devcontainer-user/user_install_dependencies" \
        sudo apt -y autoremove && sudo apt clean && sudo rm -rf "/var/lib/apt/lists/*" && sudo rm -rf "${HOME}/.ros/rosdep/*"; \
    fi
