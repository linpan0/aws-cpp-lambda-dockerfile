# Initial Setup

## Setup Docker Image

```bash
cd ${PROJECT_DIRECTORY_SUB_FOLDER} # e.g. /dev
git clone https://github.com/linpan0/aws-cpp-lambda-dockerfile.git ${PROJECT_NAME} && rm -rf ${PROJECT_NAME}/.git
cd ${PROJECT_NAME}
docker build . --build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}" -t ${PROJECT_NAME}
```

- `docker build .`: This tells Docker to **build** a new image using the `Dockerfile` found in the current directory (`.`).
- `--build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}"`: This passes a variable into the build process. It customizes the project skeleton that will be created inside the image, naming your application `${PROJECT_NAME}`.
- `-t my-first-lambda-base`: This tags (names) the finished image `${PROJECT_NAME}` so you can easily find and use it later.

## Setup Lambda Project

```bash
docker run -it --rm -v $(pwd):/app ${PROJECT_NAME}
```

- `docker run`: Starts a new container from your image.
- `-it`: Runs the container in interactive mode and attaches a terminal, allowing you to type commands into it.
- `--rm`: A handy cleanup flag that tells Docker to automatically delete the container when you stop it.
- `-v $(pwd):/app`: This is the most important flag. It creates a volume, which is a live, two-way link between your current directory on your Mac (`$(pwd)`) and the `/app` directory inside the container.
- `${PROJECT_NAME}`: Specifies which image to use for the container.

## Delete Builder Files & Connect VSCode

```bash
cd ${PROJECT_DIRECTORY}
rm -f Dockerfile && rm -rf templates
code .
```

- VS Code will open and see the `.devcontainer/devcontainer.json` file. A pop-up will appear in the bottom-right corner. Click the **"Reopen in Container"** button.

## Setup IAM Role Permissions

### Create IAM Role

```bash
aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://policies/trust-policy.json
```

### Attach Inline Lambda Execution Policy

```bash
aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Attach Custom Permission Policy

```bash
aws iam put-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-name Data-IO-Policy \
    --policy-document file://policies/data-io-policy.json
```

# Deployment
