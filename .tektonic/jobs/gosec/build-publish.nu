#!/usr/bin/env nu
# Build the gosec apk with melange, then publish the per-Go-version gosec images
# with apko — but only when something under tools/gosec/ changed in the last
# commit. Records each published image@digest for Tekton Chains provenance.
# $(workspaces.workspace.path) and $(results.IMAGES.path) are Tekton variables,
# substituted into the script before nushell runs.

git config --global --add safe.directory $(workspaces.workspace.path)

let melange = "$(workspaces.workspace.path)/melange"
let apko = "$(workspaces.workspace.path)/apko"

# Only rebuild/publish gosec when its config or melange recipe changed.
let changed = (
  git diff --name-only HEAD~1 HEAD
  | lines
  | where {|f| $f | str starts-with "tools/gosec/"}
)

if ($changed | is-empty) {
  log "No tools/gosec/ changes — nothing to build or publish."
  return
}

# melange's bubblewrap runner needs bwrap, which base:stable does not ship. This
# step runs privileged as root, so install it at runtime.
^apk add --no-cache bubblewrap

# Fresh ephemeral signing key: apko reads the pubkey we generate here in the same
# run, so nothing needs to be persisted or committed.
if not ("local-melange.rsa" | path exists) {
  ^$melange keygen local-melange.rsa
}

log "Building gosec apk with melange"
let build = (
  ^$melange build tools/gosec/melange.yaml
    --arch amd64,arm64
    --signing-key local-melange.rsa
    --out-dir packages
  | complete
)
print $build.stderr
if $build.exit_code != 0 {
  error make {msg: "melange build failed for tools/gosec/melange.yaml"}
}

mkdir dist
mut published = []
for yaml in (glob tools/gosec/*.yaml | where {|f| ($f | path basename) != "melange.yaml"}) {
  let rel = ($yaml | str replace $"($env.PWD)/" "")

  # Find the image tag from the Makefile IMAGE macro that references this yaml.
  let matches = (
    open --raw Makefile
    | lines
    | where {|l| $l | str contains $",($rel),"}
  )
  if ($matches | is-empty) {
    log $"[skip] no IMAGE macro for ($rel)"
    continue
  }

  let tag = (
    $matches.0
    | parse --regex 'call IMAGE,[^,]+,[^,]+,(?P<tag>[^)]+)'
    | get tag.0
  )
  let image = $"ghcr.io/pfenerty/apko-cicd/($tag)"

  log $"[publish] ($rel) → ($image)"
  let out = (^$apko publish --sbom-path dist $rel $image | complete)
  print $out.stderr
  if $out.exit_code != 0 {
    error make {msg: $"apko publish failed for ($rel)"}
  }

  let digest_lines = ($out.stdout | lines | where {|l| $l =~ '@sha256:'})
  let digest_ref = (if ($digest_lines | is-empty) { $image } else { $digest_lines | last | str trim })
  $published = ($published | append $digest_ref)
}

# Tekton Chains build subjects: newline-separated image@digest list.
$published | str join (char nl) | save -f $(results.IMAGES.path)
log $"Published ($published | length) gosec image\(s\)."
