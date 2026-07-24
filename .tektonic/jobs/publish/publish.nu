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

# Git source, read from the cloned workspace. Used for the OCI
# org.opencontainers.image.revision annotation (which ocidex reads for git
# metadata) and re-emitted as the Chains git material below.
let url = (^git -C $(workspaces.workspace.path) config --get remote.origin.url | str trim)
let commit = (^git -C $(workspaces.workspace.path) rev-parse HEAD | str trim)
let rev_ann = $"org.opencontainers.image.revision:($commit)"

let image = $"ghcr.io/pfenerty/apko-cicd/($tag)"
let args = (
  if $use_lock {
    ["publish" "--sbom-path" "dist" "--lockfile" $lock "--annotations" $rev_ann $config $image]
  } else {
    ["publish" "--sbom-path" "dist" "--annotations" $rev_ann $config $image]
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

# Re-emit the git source so Chains records it as a resolvedDependency in THIS
# image's provenance (deep-inspection scopes provenance to this cell TaskRun, not
# the git-clone task).
$url | save -f $(results.CHAINS-GIT_URL.path)
$commit | save -f $(results.CHAINS-GIT_COMMIT.path)
log $"Published ($image)."
