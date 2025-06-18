# Setup Docker Image
```bash
cd ${PROJECT_DIRECTORY}
git clone https://github.com/linpan0/aws-cpp-lambda-dockerfile.git
docker build . --build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}" -t ${PROJECT_NAME}
```

- `docker build .`: This tells Docker to **build** a new image using the `Dockerfile` found in the **current directory (`.`)**.
- `--build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}"`: This passes a variable into the build process. It customizes the project skeleton that will be created inside the image, naming your application `${PROJECT_NAME}`.
- `-t my-first-lambda-base`: This tags (names) the finished image `${PROJECT_NAME}` so you can easily find and use it later.


# Setup Lambda project
```bash
docker run -it --rm -v $(pwd):/app ${PROJECT_NAME}
```

- `docker run`: Starts a new container from your image.
- `-it`: Runs the container in **i**nteractive mode and attaches a **t**erminal, allowing you to type commands into it.
- `--rm`: A handy cleanup flag that tells Docker to automatically delete the container when you stop it.
- `-v $(pwd):/app`: This is the most important flag. It creates a volume, which is a live, two-way link between your current directory on your Mac (`$(pwd)`) and the `/app` directory inside the container.
- `${PROJECT_NAME}`: Specifies which image to use for the container.


# Connect VSCode
```bash
cd ${PROJECT_DIRECTORY}
code .
```
- VS Code will open and see the `.devcontainer/devcontainer.json` file. A pop-up will appear in the bottom-right corner. Click the **"Reopen in Container"** button.