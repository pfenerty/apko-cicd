#!/bin/sh
set -e
# base:stable runs as nonroot (uid 1001) so `apk add` is unavailable — download the
# apko binary matching tools/apko/apko.yaml into the workspace (writable via fsGroup)
# so the publish step can use it. $(workspaces.workspace.path) is a Tekton variable;
# the $(...) command substitutions are evaluated by the shell at runtime.
APKO_VERSION=$(grep 'image.version' tools/apko/apko.yaml | awk '{print $NF}' | tr -d '[:space:]"')
echo "Fetching apko ${APKO_VERSION}"
TMPDIR=$(mktemp -d)
APKO_URL="https://github.com/chainguard-dev/apko/releases/download/v${APKO_VERSION}/apko_${APKO_VERSION}_linux_amd64.tar.gz"
curl -fsSL "${APKO_URL}" | tar xz -C "${TMPDIR}"
mv "${TMPDIR}"/apko_*/apko "$(workspaces.workspace.path)/apko"
chmod +x "$(workspaces.workspace.path)/apko"
rm -rf "${TMPDIR}"
