#!/usr/bin/env nu
# Regenerate every apko lock file against the latest Wolfi packages. gosec has no
# Wolfi package, so its apk is built with melange first (into ./packages) so the
# @local gosec configs resolve during locking. $(workspaces.workspace.path) is a
# Tekton variable substituted before nushell runs.

git config --global --add safe.directory $(workspaces.workspace.path)

let melange = "$(workspaces.workspace.path)/melange"
let apko = "$(workspaces.workspace.path)/apko"

# melange's bubblewrap runner needs bwrap, which base:stable does not ship. This
# step runs privileged as root, so install it at runtime.
^apk add --no-cache bubblewrap

# Build the gosec apk so tools/gosec/*.yaml can be locked. Ephemeral signing key.
if not ("local-melange.rsa" | path exists) {
  ^$melange keygen local-melange.rsa
}
let build = (
  ^$melange build tools/gosec/melange.yaml
    --arch amd64
    --signing-key local-melange.rsa
    --out-dir packages
  | complete
)
print $build.stderr
if $build.exit_code != 0 {
  error make {msg: "melange build failed for tools/gosec/melange.yaml"}
}

# Lock every apko config under base/, tools/, languages/. melange recipes are not
# apko configs, so skip anything named melange.yaml.
for yaml in (glob {base,tools,languages}/**/*.yaml) {
  if (($yaml | path basename) == "melange.yaml") { continue }
  let lock = ($yaml | str replace --regex '\.yaml$' '.lock.json')
  log $"Locking ($yaml)"
  let out = (^$apko lock $yaml --output $lock | complete)
  if $out.exit_code != 0 {
    print $out.stderr
    error make {msg: $"apko lock failed for ($yaml)"}
  }
}
log "Lock files regenerated."
