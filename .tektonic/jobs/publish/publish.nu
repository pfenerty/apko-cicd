#!/usr/bin/env nu
# Per-image cell (matrix), publish step. The unit is the apko config path. Runs in
# the cell subdir the melange step prepared, derives the image tag from the
# Makefile IMAGE macro, and publishes with apko — using --lockfile for Wolfi
# images and the freshly-built local @local repo for melange images. Emits the
# image@digest for Tekton Chains. $(workspaces.workspace.path), $(params.unit),
# $(context.taskRun.name), and $(results.IMAGES.path) are Tekton variables
# (Tekton validates $(...) refs in the whole script, comments included).

git config --global --add safe.directory $(workspaces.workspace.path)

let config = "$(params.unit)"

let cell = "$(workspaces.workspace.path)/.cell-$(context.taskRun.name)"
cd $cell
mkdir dist

# Derive the image tag from the Makefile IMAGE macro that references this config.
let tag = (
  open --raw Makefile
  | lines
  | where {|l| $l | str contains $",($config),"}
  | first
  | parse --regex 'call IMAGE,[^,]+,[^,]+,(?P<tag>[^)]+)'
  | get tag.0
)
let lock = ($config | str replace --regex '\.yaml$' '.lock.json')
let melange = $"($config | path dirname)/melange.yaml"
# Melange images publish from the local @local repo (no lockfile); Wolfi images
# use their committed lockfile when present.
let use_lock = ((not ($melange | path exists)) and ($lock | path exists))

let image = $"ghcr.io/pfenerty/apko-cicd/($tag)"
let args = (
  if $use_lock {
    ["publish" "--sbom-path" "dist" "--lockfile" $lock $config $image]
  } else {
    ["publish" "--sbom-path" "dist" $config $image]
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
$digest_ref | save -f $(results.IMAGES.path)
log $"Published ($image)."
