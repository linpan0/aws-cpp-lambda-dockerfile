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
# We list the variables that envsubst will use
ENV CA_CERT_URL=${CA_CERT_URL} \
  CC=${CC} \
  CXX=${CXX} \
  CPP_VERSION=${CPP_VERSION} \
  DCMAKE_BUILD_TYPE=${DCMAKE_BUILD_TYPE} \
  LAMBDA_TARGET_NAME=${LAMBDA_TARGET_NAME}

# --- System Setup & Dependencies ---
# gettext provides the 'envsubst' utility
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
  gettext \
  --allowerasing && \
  dnf clean all

# --- Shell Customization ---
# Create a .bashrc for the root user to provide a more user-friendly shell prompt.
RUN echo "export PS1='[\u@\h \W]\\$ '" >> /root/.bashrc

# --- Certificate Authority Setup ---
RUN mkdir -p /opt/rds-ca && \
  curl -o /opt/rds-ca/rds-ca-root.pem ${CA_CERT_URL}

# --- AWS SDK Installation ---
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/aws/aws-sdk-cpp.git && \
  cd aws-sdk-cpp && \
  git submodule update --init --recursive && \
  mkdir build && cd build && \
  cmake .. -DBUILD_ONLY="s3;core;secretsmanager;rds;lambda" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local && \
  make -j $(nproc) && make install && rm -rf /tmp/aws-sdk-cpp

RUN git clone --depth 1 https://github.com/awslabs/aws-lambda-cpp.git && \
  cd aws-lambda-cpp && mkdir build && cd build && \
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX=/usr/local && \
  make && make install && rm -rf /tmp/aws-lambda-cpp

# --- Create Project Template ---
# Copy the entire local templates/ directory into the image
COPY templates/ /app_template_raw/

# Process the templates with envsubst and copy the gitignore file
RUN mkdir -p /app_template/.devcontainer && \
  mkdir -p /app_template/src && \
  mkdir -p /app_template/build && \
  envsubst '${LAMBDA_TARGET_NAME} ${CPP_VERSION}' < /app_template_raw/CMakeLists.txt.in > /app_template/CMakeLists.txt && \
  envsubst '${LAMBDA_TARGET_NAME}' < /app_template_raw/src/main.cpp.in > /app_template/src/main.cpp && \
  envsubst '${LAMBDA_TARGET_NAME}' < /app_template_raw/.devcontainer/devcontainer.json.in > /app_template/.devcontainer/devcontainer.json && \
  cp /app_template_raw/.gitignore.in /app_template/.gitignore && \
  cp /app_template_raw/policies/trust-policy.json /app_template/policies/trust-policy.json && \
  cp /app_template_raw/policies/data-io-policy.json /app_template/policies/data-io-policy.json 

# --- Entrypoint Script ---
# Copy the entrypoint script from its new nested location
COPY --chmod=755 templates/scripts/entrypoint.sh /entrypoint.sh

# Set the final working directory and the entrypoint/cmd
WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]