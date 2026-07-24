#!/usr/bin/env nu
# Build each melange package selected by the detect step into ./packages, so the
# apko configs that consume it via the @local repo can be published. This is the
# only privileged step — melange's bubblewrap runner needs bwrap + root. It is a
# no-op for Wolfi-only pushes. $(workspaces.workspace.path) is a Tekton variable.

git config --global --add safe.directory $(workspaces.workspace.path)

let to_build = (open --raw to-build.txt | lines | where {|l| ($l | str trim) | is-not-empty})
if ($to_build | is-empty) {
  log "No melange packages to build."
  return
}

# This step runs on the melange image, so `melange` is already on PATH. Ensure
# bwrap is present for melange's bubblewrap runner (a no-op once the image ships
# it); this step runs as root so apk works.
^apk add --no-cache bubblewrap

# One ephemeral signing key for every build; apko reads the pubkey in the same run,
# so nothing is persisted. Only amd64 is built (no cross-arch emulation available).
if not ("local-melange.rsa" | path exists) {
  ^melange keygen local-melange.rsa
}

for m in $to_build {
  log $"[melange] building ($m)"
  let out = (^melange build $m --arch amd64 --signing-key local-melange.rsa --out-dir packages | complete)
  print $out.stderr
  if $out.exit_code != 0 {
    error make {msg: $"melange build failed for ($m)"}
  }
}
log $"Built ($to_build | length) melange package\(s\)."
