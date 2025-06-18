# Use the Amazon Linux 2023 base image
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

# --- Build-Time Arguments ---
ARG CA_CERT_URL="https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem"
ARG CC='gcc'
ARG CXX='g++'
ARG CPP_VERSION=17
ARG DCMAKE_BUILD_TYPE=Release
ARG LAMBDA_TARGET_NAME

# Set environment variables for the build process
ENV CA_CERT_URL=${CA_CERT_URL} \
  CC=${CC} \
  CXX=${CXX} \
  CPP_VERSION=${CPP_VERSION} \
  DCMAKE_BUILD_TYPE=${DCMAKE_BUILD_TYPE} \
  LAMBDA_TARGET_NAME=${LAMBDA_TARGET_NAME}

# --- System Setup & Dependencies ---
RUN dnf -y groupinstall "Development Tools" && \
  dnf -y install \
  curl \
  git \
  libcurl-devel \
  ninja-build \
  clang \
  cmake \
  unzip \
  zlib-devel \
  openssl-devel \
  libpq-devel \
  --allowerasing && \
  dnf clean all

# --- Certificate Authority Setup ---
WORKDIR /opt
RUN mkdir -p rds-ca && \
  curl -o /opt/rds-ca/rds-ca-root.pem ${CA_CERT_URL}

# --- AWS SDK Installation ---
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/aws/aws-sdk-cpp.git && \
  cd aws-sdk-cpp && \
  git submodule update --init --recursive && \
  mkdir build && cd build && \
  cmake .. -DBUILD_ONLY="s3;core;secretsmanager;rds;lambda;dynamodb;sqs;sns;sts" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local && \
  make -j $(nproc) && make install && rm -rf /tmp/aws-sdk-cpp

RUN git clone --depth 1 https://github.com/awslabs/aws-lambda-cpp.git && \
  cd aws-lambda-cpp && mkdir build && cd build && \
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX=/usr/local && \
  make && make install && rm -rf /tmp/aws-lambda-cpp

# --- Create Project Template ---
# Create the project skeleton in a template directory.
# This now includes the .devcontainer directory for VS Code.
RUN mkdir -p /app_template/src && \
  mkdir -p /app_template/build && \
  mkdir -p /app_template/.devcontainer

# Create a starter CMakeLists.txt file in the template directory
RUN cat <<EOF > /app_template/CMakeLists.txt
# CMake configuration for a new AWS Lambda C++ project
cmake_minimum_required(VERSION 3.10)
project(${LAMBDA_TARGET_NAME}_Project CXX)

set(CMAKE_CXX_STANDARD ${CPP_VERSION})
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(aws-lambda-cpp REQUIRED)
find_package(AWSSDK REQUIRED COMPONENTS s3 core secretsmanager rds lambda dynamodb sqs sns sts)
find_package(PostgreSQL REQUIRED)

add_executable(${LAMBDA_TARGET_NAME} src/main.cpp)

target_link_libraries(${LAMBDA_TARGET_NAME} PRIVATE
    aws-lambda-cpp
    AWSSDK::s3 AWSSDK::core AWSSDK::secretsmanager AWSSDK::rds AWSSDK::lambda
    AWSSDK::dynamodb AWSSDK::sqs AWSSDK::sns AWSSDK::sts
    PostgreSQL::PostgreSQL
)

aws_lambda_package_target(${LAMBDA_TARGET_NAME})
EOF

# Create a starter main.cpp file in the template directory
RUN cat <<EOF > /app_template/src/main.cpp
#include <aws/lambda-runtime/runtime.h>
#include <aws/core/utils/json/JsonSerializer.h>
#include <aws/core/Aws.h>
#include <libpq-fe.h>
#include <cstdlib>

using namespace aws::lambda_runtime;

std::string get_env_var(const char* name) {
    const char* value = std::getenv(name);
    return value ? std::string(value) : "";
}

static invocation_response my_handler(invocation_request const& req)
{
    Aws::SDKOptions options;
    Aws::InitAPI(options);
    {
        Aws::Utils::Json::JsonValue json_response;
        json_response.WithString("executableName", "${LAMBDA_TARGET_NAME}");

        std::string conn_str = "host=" + get_env_var("PG_HOST") +
                               " port=" + get_env_var("PG_PORT") +
                               " dbname=" + get_env_var("PG_DBNAME") +
                               " user=" + get_env_var("PG_USER") +
                               " password=" + get_env_var("PG_PASSWORD") +
                               " sslmode=verify-full" +
                               " sslrootcert=/opt/rds-ca/rds-ca-root.pem";

        PGconn* conn = PQconnectdb(conn_str.c_str());

        if (PQstatus(conn) != CONNECTION_OK) {
            json_response.WithString("db_connection_status", "Failed");
            json_response.WithString("db_error", PQerrorMessage(conn));
        } else {
            json_response.WithString("db_connection_status", "Success");
        }
        
        if(conn) { PQfinish(conn); }

        Aws::ShutdownAPI(options);
        return invocation_response::success(
            json_response.View().WriteCompact(),
            "application/json"
        );
    }
}

int main()
{
    run_handler(my_handler);
    return 0;
}
EOF

# Create the VS Code Dev Container config file in the template directory
RUN cat <<EOF > /app_template/.devcontainer/devcontainer.json
{
  "name": "C++ Lambda (\${LAMBDA_TARGET_NAME})",
  "image": "\${LAMBDA_TARGET_NAME}-base",
  "runArgs": [
    "--volume=\${localWorkspaceFolder}:/app"
  ],
  "workspaceFolder": "/app",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.cpptools-extension-pack"
      ],
      "settings": {
        "C_Cpp.default.includePath": [
          "\${workspaceFolder}/**",
          "/usr/local/include",
          "/usr/include"
        ]
      }
    }
  }
}
EOF

# --- Entrypoint Script ---
RUN cat <<EOF > /entrypoint.sh
#!/bin/sh
set -e
# Check if CMakeLists.txt does NOT exist in the /app directory.
if [ ! -f "/app/CMakeLists.txt" ]; then
   echo "CMakeLists.txt not found. Initializing project from template..."
   # Copy the template files into the mounted volume.
   cp -r /app_template/. /app/
else
   echo "Existing CMakeLists.txt found. Skipping initialization."
fi

# Execute the command passed to the container (e.g., /bin/bash)
exec "\$@"
EOF

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the final working directory and the entrypoint/cmd
WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]