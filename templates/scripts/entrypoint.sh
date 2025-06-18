#!/bin/sh
set -e

# Check if CMakeLists.txt does NOT exist in the /app directory.
if [ ! -f "/app/CMakeLists.txt" ]; then
   echo "CMakeLists.txt not found. Initializing project from template..."
   # Copy the pre-processed template files into the mounted volume.
   cp -r /app_template/. /app/
else
   echo "Existing CMakeLists.txt found. Skipping initialization."
fi

# Execute the command passed to the container (e.g., /bin/bash)
# This allows 'docker run my-image ls -l' to work, or defaults to the CMD.
exec "$@"