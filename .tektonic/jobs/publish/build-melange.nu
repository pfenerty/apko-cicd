#!/usr/bin/env nu
# Per-image cell (matrix), melange step. Copies the repo into a cell-unique subdir
# (isolating packages/ and dist/ from other parallel cells on the shared RWO
# workspace) and, if this unit has a melange.yaml, builds its apk into ./packages.
# No-op for Wolfi images. This is the only privileged step (bubblewrap); it hands
# the cell off to the nonroot publish step by chowning it to uid 1001.
# $(workspaces.workspace.path), $(params.unit), $(context.taskRun.name) are Tekton vars.

git config --global --add safe.directory $(workspaces.workspace.path)

let unit = "$(params.unit)"
let melange = ($unit | split row "," | get 3? | default "")

let cell = "$(workspaces.workspace.path)/.cell-$(context.taskRun.name)"
^mkdir -p $cell
^cp -r base tools languages Makefile $cell
cd $cell

if ($melange | is-empty) {
  log $"[($unit)] Wolfi image — no melange build."
} else {
  # The melange image already ships melange; ensure bwrap for its sandbox runner.
  ^apk add --no-cache bubblewrap
  ^melange keygen local-melange.rsa
  log $"[melange] building ($melange)"
  let out = (^melange build $melange --arch amd64 --signing-key local-melange.rsa --out-dir packages | complete)
  print $out.stderr
  if $out.exit_code != 0 {
    error make {msg: $"melange build failed for ($melange)"}
  }
}

# This step runs as root; the publish step runs as nonroot (uid 1001). Hand the
# cell over so publish can write dist/ and read the built packages/ + key.
^chown -R 1001:1001 $cell
