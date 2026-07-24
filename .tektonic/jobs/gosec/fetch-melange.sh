#!/bin/sh
set -e
# gosec has no Wolfi package, so it is built from source with melange and consumed
# by the apko configs from a local repo. base:stable runs as nonroot (uid 1001) so
# `apk add` is unavailable — download the melange binary matching tools/melange/apko.yaml
# into the workspace (writable via fsGroup) so the build step can use it.
# $(workspaces.workspace.path) is a Tekton variable; the $(...) command
# substitutions are evaluated by the shell at runtime.
MELANGE_VERSION=$(grep 'image.version' tools/melange/apko.yaml | awk '{print $NF}' | tr -d '[:space:]')
echo "Fetching melange ${MELANGE_VERSION}"
TMPDIR=$(mktemp -d)
MELANGE_URL="https://github.com/chainguard-dev/melange/releases/download/v${MELANGE_VERSION}/melange_${MELANGE_VERSION}_linux_amd64.tar.gz"
curl -fsSL "${MELANGE_URL}" | tar xz -C "${TMPDIR}"
mv "${TMPDIR}"/melange_*/melange "$(workspaces.workspace.path)/melange"
chmod +x "$(workspaces.workspace.path)/melange"
rm -rf "${TMPDIR}"
