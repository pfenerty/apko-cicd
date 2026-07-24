#!/usr/bin/env nu
# Per-image cell (matrix), publish step. Runs in the cell subdir the melange step
# prepared and publishes this unit's image with apko (--lockfile for Wolfi images;
# from the local @local repo for melange images). Emits the image@digest for
# Tekton Chains. $(workspaces.workspace.path), $(params.unit), $(context.taskRun.name),
# and $(results.IMAGE.path) are Tekton variables.

git config --global --add safe.directory $(workspaces.workspace.path)

let unit = "$(params.unit)"
let f = ($unit | split row ",")
let config = $f.0
let tag = $f.1
let lock = ($f | get 2? | default "")

let cell = "$(workspaces.workspace.path)/.cell-$(context.taskRun.name)"
cd $cell
mkdir dist

let image = $"ghcr.io/pfenerty/apko-cicd/($tag)"
let args = (
  if ($lock | is-empty) {
    ["publish" "--sbom-path" "dist" $config $image]
  } else {
    ["publish" "--sbom-path" "dist" "--lockfile" $lock $config $image]
  }
)
log $"[publish] ($config) → ($image)"
let out = (^apko ...$args | complete)
print $out.stderr
if $out.exit_code != 0 {
  error make {msg: $"apko publish failed for ($config)"}
}

# apko prints the published digest reference (image@sha256:...) on stdout.
let digest_lines = ($out.stdout | lines | where {|l| $l =~ '@sha256:'})
let digest_ref = (if ($digest_lines | is-empty) { $image } else { $digest_lines | last | str trim })
$digest_ref | save -f $(results.IMAGE.path)
log $"Published ($image)."
