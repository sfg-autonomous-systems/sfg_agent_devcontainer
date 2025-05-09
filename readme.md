# Isaac ROS Dev Container

In order to integrate this dev container into your project follow the steps below:

1.  Add this repository to your project root (the directory you open in VS Code) as a submodule with

    | Protocol | Command                                                                                                                                 |
    |:--------:|-----------------------------------------------------------------------------------------------------------------------------------------|
    | HTTPS    | `git submodule add https://gitlab.hs-esslingen.de/smart-factory-grids/autonomous-systems/tools/isaac-ros-dev-container.git .devcontainer` |
    | SSH      | `git submodule add git@gitlab.hs-esslingen.de:smart-factory-grids/autonomous-systems/tools/isaac-ros-dev-container.git .devcontainer`     |

2. Execute `.devcontainer/scripts/create_devcontainer_user_directory` to create the integration files required at the root of your project.

3. Additional configuration such as executing code before the image is build, installing custom dependencies as part of the container's image, or executing code when the container is started can be achieved with `user_initialize_command`, `dockerfile`, and `user_post_start_command`, respectively. For reference the integrated directory structure is shown below.
    ```
    .
    ├── .devcontainer                       # This repository as a git submodule.
    ├── .devcontainer-user/                 # User configuration to customize the ISAAC ROS dev container.
    │   ├── .gitingnore                     # Contents should be ".env".
    │   ├── compose.yaml
    │   ├── dockerfile
    │   ├── user_initialize_command
    │   └── user_post_start_command
    ├── colcon_ws/
    │   └── src/
    └── ...
    ```
## Important Remarks
Note that...

1. `user_initialize_command` and `user_post_start_command` are executed at the end of their respective devcontainer command scripts `initialize_command` and `post_start_command`, respectively. See [devcontainer json reference](https://containers.dev/implementors/json_reference/) for more details.

2. your project's directory structure should match the directory structure to the extend shown above. This also applies to the filenames shown. For a reference implementation you may refer to [Smart Factory Grids > Autonomous Systems > Robots > Go2](https://gitlab.hs-esslingen.de/smart-factory-grids/autonomous-systems/robots/go2).

3. while `user_initialize_command` is executed on the host, `user_post_start_command` is executed inside the container. Therefore, you cannot reference anything that resides outside the directory `.devcontainer-user` in the latter command.
