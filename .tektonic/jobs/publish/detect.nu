#!/usr/bin/env nu
# Decide which images to (re)publish this push. An image (any Makefile IMAGE
# entry) is selected when its apko config, its lock file, or a sibling
# melange.yaml changed in the last commit. Writes two files for later steps:
#   to-build.txt   — unique melange.yaml files to build first (empty ⇒ Wolfi-only)
#   to-publish.tsv — one `config<TAB>tag<TAB>lockfile-or-empty` row per image
# $(workspaces.workspace.path) is a Tekton variable substituted before nu runs.

git config --global --add safe.directory $(workspaces.workspace.path)

let changed = (git diff --name-only HEAD~1 HEAD | lines)

# All images declared by the Makefile IMAGE macro.
let images = (
  open --raw Makefile
  | lines
  | each {|l| $l | parse --regex 'call IMAGE,(?P<target>[^,]+),(?P<config>[^,]+),(?P<tag>[^)]+)'}
  | flatten
)

mut to_publish = []
mut to_build = []
for img in $images {
  let config = $img.config
  let lock = ($config | str replace --regex '\.yaml$' '.lock.json')
  let melange = $"($config | path dirname)/melange.yaml"
  # config / lock / melange are the trigger files; ones that don't exist can never
  # appear in the diff, so membership is enough (no existence check needed here).
  if ([$config, $lock, $melange] | any {|t| $t in $changed}) {
    let is_melange = ($melange | path exists)
    # Melange-built images are published from the freshly-built local repo with no
    # lockfile (a rebuilt apk would not match a pinned hash); Wolfi images use
    # their committed lockfile when present.
    let lock_field = (if $is_melange { "" } else if ($lock | path exists) { $lock } else { "" })
    $to_publish = ($to_publish | append $"($config)\t($img.tag)\t($lock_field)")
    if $is_melange { $to_build = ($to_build | append $melange) }
  }
}

($to_build | uniq | str join (char nl)) | save -f to-build.txt
($to_publish | str join (char nl)) | save -f to-publish.tsv
log $"($to_publish | length) image\(s\) to publish; ($to_build | uniq | length) melange package\(s\) to build."
