# Initial Setup

## 1. Setup Docker Image

```bash
cd ${PROJECT_DIRECTORY_SUB_FOLDER} # e.g. /dev
```

```bash
git clone https://github.com/linpan0/aws-cpp-lambda-dockerfile.git ${PROJECT_NAME} && rm -rf ${PROJECT_NAME}/.git
```

```bash
cd ${PROJECT_NAME}
```

```bash
docker build . --build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}" -t ${PROJECT_NAME}
```

- `docker build .`: This tells Docker to **build** a new image using the `Dockerfile` found in the current directory (`.`).
- `--build-arg LAMBDA_TARGET_NAME="${PROJECT_NAME}"`: This passes a variable into the build process. It customizes the project skeleton that will be created inside the image, naming your application `${PROJECT_NAME}`.
- `-t ${PROJECT_NAME}`: This tags (names) the finished image `${PROJECT_NAME}` so you can easily find and use it later.

## 2. Setup Lambda Function Project

```bash
docker run -it --rm -v $(pwd):/app ${PROJECT_NAME}
```

- `docker run`: Starts a new container from your image.
- `-it`: Runs the container in interactive mode and attaches a terminal, allowing you to type commands into it.
- `--rm`: A handy cleanup flag that tells Docker to automatically delete the container when you stop it.
- `-v $(pwd):/app`: This is the most important flag. It creates a volume, which is a live, two-way link between your current directory on your Mac (`$(pwd)`) and the `/app` directory inside the container.
- `${PROJECT_NAME}`: Specifies which image to use for the container.

## 3. Delete Builder Files & Connect VSCode

```bash
cd ${PROJECT_DIRECTORY}
rm -f Dockerfile && rm -rf templates
code .
```

- VS Code will open and see the `.devcontainer/devcontainer.json` file. A pop-up will appear in the bottom-right corner. Click the **"Reopen in Container"** button.

## 4. Setup IAM Role Permissions

### 4a. Create IAM Role

```bash
aws iam create-role --assume-role-policy-document file://policies/trust-policy.json --role-name ${ROLE_NAME}
```

### 4b. Attach Inline Lambda Execution Policy

```bash
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --role-name ${ROLE_NAME}
```

### 4c. Attach Custom Permission Policy

```bash
aws iam put-role-policy \
    --policy-name Data-IO-Policy \
    --policy-document file://policies/data-io-policy.json \
    --role-name ${ROLE_NAME}
```

# Deployment

## 1. Compile and Create the Deployment Package

- Run these commands in the Docker bash environment!

```bash
cd ${PROJECT_DIRECTORY}/build
# Compiles the program.
make ${PROJECT_NAME}
# Create the deployment package
make aws-lambda-package-${PROJECT_NAME}
```

## 2. Create/Update Lambda Function

### 2a. Create Function

- Run these commands in ${PROJECT_NAME}/build

```bash
aws lambda create-function \
  --region us-east-1 \
  --runtime provided.al2023 \
  --memory-size 512 \
  --timeout 15 \
  --role ${YOUR_IAM_ROLE_ARN} \
  --handler ${PROJECT_NAME} \
  --zip-file fileb://${PROJECT_NAME}.zip \
  --function-name ${PROJECT_NAME} \
  --architectures ${x86_64 or arm64}
```

### 2b. Update Function

```bash
# Run these commands in the Docker bash environment!
cd ${PROJECT_DIRECTORY}/build
make ${PROJECT_NAME}
make aws-lambda-package-${PROJECT_NAME}

# Not this one.
aws lambda update-function-code \
  --function-name ${PROJECT_NAME} \
  --zip-file fileb://${PROJECT_NAME}.zip
```

# Executing Lambda Function

```bash
aws lambda invoke \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  --payload '{"key1": "value1", "key2": "value2"}' \
  --function-name ${PROJECT_NAME} \
  output.json
```
