# Isaac ROS Dev Container

In order to integrate this dev container into your project follow the steps below:

1.  Add this repository to your project root as a submodule (the directory you open in VS Code) with
    ```
        git submodule add <url> .devcontainer
    ```
2. Create a top level `compose.yml` file. For reference the minimum `compose.yml` file is
    ```yaml
    include:
    - path:
        - .devcontainer/compose/compose.base.yml
        - .devcontainer/compose/compose.${PLATFORM}.yml
    ```

# Expanding on the Isaac ROS Dev Container

If you want to add additional dependencies to the Isaac ROS dev container you may do so as follows:

ToDo