#!/usr/bin/env nu
# Publish apko images whose *.lock.json changed in the last commit, and record the
# published image@digest references for Tekton Chains provenance.
# $(workspaces.workspace.path) and $(results.IMAGES.path) are Tekton variables,
# substituted into the script before nushell runs.

git config --global --add safe.directory $(workspaces.workspace.path)

let apko = "$(workspaces.workspace.path)/apko"

let changed = (
  git diff --name-only HEAD~1 HEAD
  | lines
  | where {|f| $f | str ends-with ".lock.json"}
)

if ($changed | is-empty) {
  log "No lock files changed — nothing to publish."
  return
}

mkdir dist
mut published = []
for lockfile in $changed {
  let yaml = ($lockfile | str replace --regex '\.lock\.json$' '.yaml')

  # Find the image tag from the Makefile IMAGE macro that references this yaml.
  let matches = (
    open --raw Makefile
    | lines
    | where {|l| $l | str contains $",($yaml),"}
  )
  if ($matches | is-empty) {
    log $"[skip] no IMAGE macro for ($yaml)"
    continue
  }

  let tag = (
    $matches.0
    | parse --regex 'call IMAGE,[^,]+,[^,]+,(?P<tag>[^)]+)'
    | get tag.0
  )
  let image = $"ghcr.io/pfenerty/apko-cicd/($tag)"

  log $"[publish] ($yaml) → ($image)"
  let out = (^$apko publish --sbom-path dist --lockfile $lockfile $yaml $image | complete)
  print $out.stderr
  if $out.exit_code != 0 {
    error make {msg: $"apko publish failed for ($yaml)"}
  }

  # apko prints the published digest reference (image@sha256:...) on stdout.
  let digest_lines = ($out.stdout | lines | where {|l| $l =~ '@sha256:'})
  let digest_ref = (if ($digest_lines | is-empty) { $image } else { $digest_lines | last | str trim })
  $published = ($published | append $digest_ref)
}

# Tekton Chains build subjects: newline-separated image@digest list.
$published | str join (char nl) | save -f $(results.IMAGES.path)
log $"Published ($published | length) image\(s\)."
