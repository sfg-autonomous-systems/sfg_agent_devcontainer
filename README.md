# SFG Agent - Devcontainer

In order to integrate this devcontainer into your project follow the steps below:

1. Add this repository to your project root (the directory you open in VS Code) as a submodule with

   | Protocol | Command                                                                                                |
   |:--------:|--------------------------------------------------------------------------------------------------------|
   | HTTPS    | `git submodule add https://github.com/sfg-autonomous-systems/sfg_agent_devcontainer.git .devcontainer` |
   | SSH      | `git submodule add git@github.com:sfg-autonomous-systems/sfg_agent_devcontainer.git .devcontainer`     |

2. Execute `.devcontainer/scripts/create_devcontainer_user_directory` to create the integration files required at the root of your project. This will generate the following directory structure:
   ```
   <your repository>
   ├── .devcontainer                       # This repository as a git submodule.
   ├── .devcontainer_user/                 # Integration files for the agent devcontainer.
   │   ├── compose.user.yaml
   │   ├── dockerfile.user
   │   ├── user_initialize_command
   │   └── user_post_start_command
   └── ...
   ```

3. Create your colcon workspace directory at the root of your repository:
   ```
   <your repository>
   ├── .devcontainer
   ├── .devcontainer_user/
   ├── colcon_ws/                          # Your colcon workspace.
   │   └── src/
   └── ...
   ```
   In order for intellisense and automatic sourcing to function correctly inside the container, you will have to create the directory with this exact name and location. If you chose to store your colcon workspace in some other directory, you need to update the container's `COLCON_WS` environment variable accordingly in order for these features to work. This can be done via the `dockerfile.user` (see next step).

4. Additional configuration such as executing code before the image is build, installing custom dependencies as part of the container's image, or executing code when the container is started can be achieved with `user_initialize_command`, `dockerfile.user`, and `user_post_start_command`, respectively.

## Important Remarks

Note that...

1. `user_initialize_command` and `user_post_start_command` are executed towards the end of their respective devcontainer command scripts `initialize_command` and `post_start_command`, respectively. See [devcontainer json reference](https://containers.dev/implementors/json_reference/) for more details.

2. your project's directory structure should match the directory structure to the extend shown above. This also applies to the filenames shown. For a reference implementation you may refer to [sfg_go2](https://github.com/sfg-autonomous-systems-agents/sfg_go2).

3. while `user_initialize_command` is executed on the host, `user_post_start_command` is executed inside the container. Therefore, you cannot simply reference files residing on the host in the latter command.

## Running on WSL2

The host side scripts run inside the WSL2 distribution, so most of the setup works unchanged. Note the following differences compared to a native Linux host.

### Windows

1. Enable mirrored networking in `%UserProfile%\.wslconfig` so WSL2 shares the Windows network adapters and receives LAN multicast. Run `wsl --shutdown` afterwards.

   ```ini
   [wsl2]
   networkingMode=mirrored
   dnsTunneling=true
   autoProxy=true

   [experimental]
   hostAddressLoopback=true
   ```

2. Allow inbound traffic to WSL2 through the Hyper-V firewall. In mirrored mode it blocks all inbound traffic except ping and mDNS by default, so the container can send to the LAN but never receives.

   ```powershell
   Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
   ```

### WSL2 Distribution

1. Enable systemd in `/etc/wsl.conf`.
   
   ```ini
   [boot]
   systemd=true
   ```

2. Install [Docker](https://docs.docker.com/engine/install/) inside the distribution instead of using Docker Desktop.

3. If an NVIDIA GPU is present, install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) and register its runtime.

4. Clone your project onto the Linux filesystem, not under `/mnt/c`, and open it in VS Code through the WSL extension. Opening it via `\\wsl.localhost\...` from Windows would run the initialize command on Windows.

## Known Issues

1. Docker Buildx >= 0.37.2 refuses to read the Dockerfile the Dev Containers extension generates in `/tmp`, which fails the build with `additional privileges requested: pass "--allow=fs.read=..."`. To work around this, add the following to `~/.profile` on the host and start a fresh session so VS Code picks it up:

   ```bash
   export BUILDX_BAKE_ENTITLEMENTS_FS=0
   ```
   The workaround can be removed once a Docker Compose release containing [docker/compose#14325](https://github.com/docker/compose/pull/14325) is installed (see [devcontainers/cli#1320](https://github.com/devcontainers/cli/issues/1320)).

2. Running the project as a service on boot will not work when using WSL2 because WSL2 does not start on Windows boot and the service itself waits for NetworkManager (`nm-online`), which WSL2 does not use.