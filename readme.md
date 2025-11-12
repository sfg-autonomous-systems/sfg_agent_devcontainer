# Agent - Devcontainer

In order to integrate this devcontainer into your project follow the steps below:

1.  Add this repository to your project root (the directory you open in VS Code) as a submodule with

    | Protocol | Command                                                                                                                                   |
    |:--------:|-------------------------------------------------------------------------------------------------------------------------------------------|
    | HTTPS    | `git submodule add https://gitlab.hs-esslingen.de/smart-factory-grids/autonomous-systems/agents/agent-devcontainer.git .devcontainer` |
    | SSH      | `git submodule add git@gitlab.hs-esslingen.de:smart-factory-grids/autonomous-systems/agents/agent-devcontainer.git .devcontainer`     |

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

2. your project's directory structure should match the directory structure to the extend shown above. This also applies to the filenames shown. For a reference implementation you may refer to [Smart Factory Grids > Autonomous Systems > Robots > Go2](https://gitlab.hs-esslingen.de/smart-factory-grids/autonomous-systems/robots/go2).

3. while `user_initialize_command` is executed on the host, `user_post_start_command` is executed inside the container. Therefore, you cannot simply reference files residing on the host in the latter command.
