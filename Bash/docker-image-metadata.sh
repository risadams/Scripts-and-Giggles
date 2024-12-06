#!/bin/bash

#----------------------------------------------------------------------
# Name: docker-image-metadata.sh
# Description:
#   This script attempts to reconstruct key metadata from a given Docker
#   image and print it in a Dockerfile-like format. It retrieves the
#   MAINTAINER information (if available) and then uses `docker inspect`
#   to list environment variables, exposed ports, volumes, user settings,
#   working directory, entrypoint, CMD, and ONBUILD instructions.
#
# Usage:
#   ./docker-image-metadata.sh <image>
#
#   <image> can be a Docker image name or ID. The image must be locally
#   available (e.g., pulled or built beforehand).
#
# Example:
#   # Assume 'nginx:latest' is already pulled.
#   ./docker-image-metadata.sh nginx:latest
#
#   This will output something like:
#     MAINTAINER <some_maintainer>
#     ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#     EXPOSE 80
#     WORKDIR /usr/share/nginx/html
#     ENTRYPOINT ["nginx","-g","daemon off;"]
#     CMD ["nginx","-g","daemon off;"]
#
# Notes:
#   - Not all fields will be present in all images. If a field (like
#     MAINTAINER or ENTRYPOINT) is not set, it will not appear in the
#     output.
#   - This script relies on `docker history` and `docker inspect`. Make
#     sure you have Docker installed and the daemon running.
#----------------------------------------------------------------------

if [ $# -ne 1 ]; then
  echo "Error: Missing required parameter <image>."
  echo "Usage: $0 <image>"
  exit 1
fi

IMAGE="$1"

# Extract the MAINTAINER line from the image history
docker history --no-trunc "$IMAGE" |
  sed -n -e 's,.*/bin/sh -c #(nop) \(MAINTAINER .*[^ ]\) *0 B,\1,p' |
  head -1

# Extract Docker configuration details using inspect
docker inspect --format='{{range $e := .Config.Env}}
ENV {{$e}}
{{end}}{{range $e,$v := .Config.ExposedPorts}}
EXPOSE {{$e}}
{{end}}{{range $e,$v := .Config.Volumes}}
VOLUME {{$e}}
{{end}}{{with .Config.User}}USER {{.}}{{end}}
{{with .Config.WorkingDir}}WORKDIR {{.}}{{end}}
{{with .Config.Entrypoint}}ENTRYPOINT {{json .}}{{end}}
{{with .Config.Cmd}}CMD {{json .}}{{end}}
{{with .Config.OnBuild}}ONBUILD {{json .}}{{end}}' "$IMAGE"
