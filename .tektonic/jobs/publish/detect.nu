#!/usr/bin/env nu
# Emit one unit per changed image (any Makefile IMAGE entry whose apko config,
# lock file, or sibling melange.yaml changed in the last commit) as a JSON array
# result. A downstream task fans out over it — one build+publish job per image.
# Each unit is just the apko config path; the cell derives its tag (from the
# Makefile), lock, and melange.yaml itself. Keeping units to the bare path keeps
# the array result well under Tekton's 4KB result-size limit even for large fan-outs.
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
    $units = ($units | append $config)
  }
}

# Tekton array result: a JSON array of config paths, one per fan-out matrix cell.
$units | to json | save -f $(results.units.path)
log $"($units | length) image\(s\) to build/publish."
