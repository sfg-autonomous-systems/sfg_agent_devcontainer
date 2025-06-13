FROM ubuntu:22.04 AS fast_dds_router

# Use bash as shell.
SHELL ["/bin/bash", "-c"]

ARG ROS_DOMAIN_ID
ENV ROS_DOMAIN_ID=${ROS_DOMAIN_ID}

USER root

#########################################################################################################
# Update and install required apt and pip dependencies.                                                 #
#########################################################################################################
RUN --mount=type=cache,id=apt_cache_fast_dds_router,target="/var/cache/apt" \
    apt update && apt install -y --no-install-recommends \
        make \
        cmake \
        g++ \
        pip \
        wget \
        git \
        gettext \
        libasio-dev \
        libtinyxml2-dev \
        libssl-dev \
        libyaml-cpp-dev && \
    apt -y autoremove && apt clean && rm -rf "/var/lib/apt/lists/*"

RUN pip install \
        vcstool

#########################################################################################################
# Install Fast DDS Router and its Dependencies.                                                         #
#########################################################################################################
ARG DDS_ROUTER_VERSION=v3.1.0
ARG DDS_ROUTER_DIRECTORY=/opt/DDS-Router
WORKDIR "${DDS_ROUTER_DIRECTORY}"

RUN mkdir \
        "src" \
        "build" && \
    wget "https://raw.githubusercontent.com/eProsima/DDS-Router/${DDS_ROUTER_VERSION}/ddsrouter.repos" && \
    vcs import "src" < "ddsrouter.repos"

ENV CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

# Foonathan Memory Vendor
RUN mkdir "build/foonathan_memory_vendor" && \
    cd "build/foonathan_memory_vendor" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/foonathan_memory_vendor" \
        -DCMAKE_INSTALL_PREFIX="/usr/local/" \
        -DBUILD_SHARED_LIBS=ON && \
    cmake --build "." --target install -j$(nproc)

# Fast CDR
RUN mkdir "build/fastcdr" && \
    cd "build/fastcdr" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/fastcdr" && \
    cmake --build "." --target install -j$(nproc)

# Fast DDS
RUN mkdir "build/fastdds" && \
    cd "build/fastdds" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/fastdds" && \
    cmake --build "." --target install -j$(nproc)

# CMake Utils
RUN mkdir "build/cmake_utils" && \
    cd "build/cmake_utils" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/dev-utils/cmake_utils" && \
    cmake --build "." --target install -j$(nproc)

# C++ Utils
RUN mkdir "build/cpp_utils" && \
    cd "build/cpp_utils" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/dev-utils/cpp_utils" && \
    cmake --build "." --target install -j$(nproc)

# DDS Pipe Core
RUN mkdir "build/ddspipe_core" && \
    cd "build/ddspipe_core" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddspipe/ddspipe_core" && \
    cmake --build "." --target install -j$(nproc)

# DDS Pipe Participants
RUN mkdir "build/ddspipe_participants" && \
    cd "build/ddspipe_participants" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddspipe/ddspipe_participants" && \
    cmake --build "." --target install -j$(nproc)

# DDS Pipe YAML
RUN mkdir "build/ddspipe_yaml" && \
    cd "build/ddspipe_yaml" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddspipe/ddspipe_yaml" && \
    cmake --build "." --target install -j$(nproc)

ENV LD_LIBRARY_PATH=/usr/local/lib/:${LD_LIBRARY_PATH}

# DDS Router Core
RUN mkdir "build/ddsrouter_core" && \
    cd "build/ddsrouter_core" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddsrouter/ddsrouter_core" && \
    cmake --build "." --target install -j$(nproc)

# DDS Router YAML
RUN mkdir "build/ddsrouter_yaml" && \
    cd "build/ddsrouter_yaml" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddsrouter/ddsrouter_yaml" && \
    cmake --build "." --target install -j$(nproc)

# DDS Router Tool
RUN mkdir "build/ddsrouter_tool" && \
    cd "build/ddsrouter_tool" && \
    cmake "${DDS_ROUTER_DIRECTORY}/src/ddsrouter/tools/ddsrouter_tool" && \
    cmake --build "." --target install -j$(nproc)

#########################################################################################################
# Run DDS Router.                                                                                       #
#########################################################################################################
COPY ".devcontainer/resources/fast_dds_router_config.yaml.template" "${DDS_ROUTER_DIRECTORY}/fast_dds_router_config.yaml.template"
RUN envsubst < "fast_dds_router_config.yaml.template" > "fast_dds_router_config.yaml"
CMD [ "ddsrouter", "-c", "fast_dds_router_config.yaml" ]
