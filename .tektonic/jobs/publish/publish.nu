#!/usr/bin/env nu
# Publish each image selected by the detect step (to-publish.tsv). Wolfi images
# use their committed lockfile; melange-built images have an empty lock field and
# are published from the local @local repo built by the build-melange step.
# Records each image@digest for Tekton Chains. $(workspaces.workspace.path) and
# $(results.IMAGES.path) are Tekton variables substituted before nu runs.

git config --global --add safe.directory $(workspaces.workspace.path)

# This step runs on the apko image, so `apko` is already on PATH.
# --raw: nushell would otherwise auto-parse a .tsv into a table; we want the lines.
let rows = (open --raw to-publish.tsv | lines | where {|l| ($l | str trim) | is-not-empty})
if ($rows | is-empty) {
  log "Nothing to publish."
  "" | save -f $(results.IMAGES.path)
  return
}

mkdir dist
mut published = []
for row in $rows {
  let parts = ($row | split row "\t")
  let config = $parts.0
  let tag = $parts.1
  let lock = ($parts | get 2? | default "")
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
  $published = ($published | append $digest_ref)
}

# Tekton Chains build subjects: newline-separated image@digest list.
$published | str join (char nl) | save -f $(results.IMAGES.path)
log $"Published ($published | length) image\(s\)."
