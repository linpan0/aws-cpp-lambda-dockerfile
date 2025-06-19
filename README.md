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

- Run these commands in the Docker bash environment!

```bash
cd ${PROJECT_DIRECTORY}/build
# Compiles the program.
make ${PROJECT_NAME}
# Create the deployment package
make aws-lambda-package-${PROJECT_NAME}
```

# Create/Update Lambda Function

## Create Function

- Run these commands in ${PROJECT_NAME}/build

```bash
aws lambda create-function \
  --region us-east-1 \
  --runtime provided.al2023 \
  --handler ${PROJECT_NAME} \
  --memory-size 512 \
  --timeout 15 \
  --role ${YOUR_IAM_ROLE_ARN} \
  --zip-file fileb://${PROJECT_NAME}.zip \
  --function-name ${PROJECT_NAME} \
  --architectures ${x86_64 or ARM}
```

## Update Function

```bash
aws lambda update-function-code \
  --function-name ${PROJECT_NAME} \
  --zip-file fileb://${PROJECT_NAME}.zip
```

# Executing Lambda Function

```bash
aws lambda invoke \
  --function-name my-cpp-s3-uploader \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucketName": "your-unique-bucket-name-12345", "keyName": "hello-from-lambda.txt", "fileContent": "This is a test file from C++ Lambda!"}' \
  output.json
```

TODO: The deploying probably needs to be done on Docker or something because the Lambda function is either x86 or ARM, and it defaults to x86. Or maybe in create-function, [--architectures <value>]? https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html
