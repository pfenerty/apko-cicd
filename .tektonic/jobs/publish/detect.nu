#!/usr/bin/env nu
# Emit one "unit" per changed image (any Makefile IMAGE entry whose apko config,
# lock file, or sibling melange.yaml changed in the last commit) as a JSON array
# result. A downstream task fans out over it — one build+publish job per image.
# Unit format (comma-separated, empty fields allowed): config,tag,lock,melange
# $(workspaces.workspace.path) and $(results.units.path) are Tekton variables.

git config --global --add safe.directory $(workspaces.workspace.path)

let changed = (git diff --name-only HEAD~1 HEAD | lines)

let images = (
  open --raw Makefile
  | lines
  | each {|l| $l | parse --regex 'call IMAGE,(?P<target>[^,]+),(?P<config>[^,]+),(?P<tag>[^)]+)'}
  | flatten
)

mut units = []
for img in $images {
  let config = $img.config
  let lock = ($config | str replace --regex '\.yaml$' '.lock.json')
  let melange = $"($config | path dirname)/melange.yaml"
  if ([$config, $lock, $melange] | any {|t| $t in $changed}) {
    let is_melange = ($melange | path exists)
    # Melange images publish from a freshly-built local repo (no lockfile); Wolfi
    # images use their committed lockfile when present.
    let lock_field = (if $is_melange { "" } else if ($lock | path exists) { $lock } else { "" })
    let melange_field = (if $is_melange { $melange } else { "" })
    $units = ($units | append $"($config),($img.tag),($lock_field),($melange_field)")
  }
}

# Tekton array result: a JSON array of strings, one per fan-out matrix cell.
$units | to json | save -f $(results.units.path)
log $"($units | length) image\(s\) to build/publish."
