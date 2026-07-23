#!/usr/bin/env nu
# If the lockfile/version regen produced changes, push them to the
# update/package-versions branch and open a pull request with auto-merge enabled,
# so it merges automatically once the required push-pipeline checks pass.
#
# Requires GH_TOKEN (repo-scoped) from the github-automerge-token secret.
# $(workspaces.workspace.path) is a Tekton variable substituted before nu runs.

const REPO = "pfenerty/apko-cicd"
const BRANCH = "update/package-versions"
const BASE = "main"

git config --global --add safe.directory $(workspaces.workspace.path)
git config --global user.email "ci@apko-cicd.local"
git config --global user.name "apko-cicd CI"

# packages/ and the local key are build artifacts — never commit them.
if ($env.GH_TOKEN? | is-empty) {
  error make {msg: "GH_TOKEN is not set (github-automerge-token secret missing)"}
}

let dirty = (git status --porcelain | lines | where {|l| not ($l | str contains "packages/") and not ($l | str contains "local-melange.rsa")})
if ($dirty | is-empty) {
  log "No package/version changes — nothing to propose."
  return
}

# update-versions.py rewrites Makefile tags/annotations; the lock files live under
# base/ tools/ languages/. Stage exactly those — never packages/ or the signing key.
git checkout -B $BRANCH
git add Makefile base tools languages
git commit -m "chore: update package versions"

let remote = $"https://x-access-token:($env.GH_TOKEN)@github.com/($REPO)"
git push --force $remote $"HEAD:($BRANCH)"

# Create the PR (ignore 422 = one already open for this head branch).
let api = $"https://api.github.com/repos/($REPO)"
let pr_body = {
  title: "chore: update package versions",
  head: $BRANCH,
  base: $BASE,
  body: "Automated package version update. Lock files regenerated with `apko lock` and version pins updated from them by the update-packages Tekton pipeline."
}
let created = (
  http post --allow-errors --content-type application/json
    --headers [Authorization $"Bearer ($env.GH_TOKEN)" Accept "application/vnd.github+json" "X-GitHub-Api-Version" "2022-11-28"]
    $"($api)/pulls" $pr_body
)

# Resolve the PR number (newly created, or the existing open one for this branch).
let number = (
  if ($created | get number? | is-not-empty) {
    $created.number
  } else {
    let open = (
      http get
        --headers [Authorization $"Bearer ($env.GH_TOKEN)" Accept "application/vnd.github+json"]
        $"($api)/pulls?head=pfenerty:($BRANCH)&state=open"
    )
    $open.0.number
  }
)
log $"PR #($number) ready"

# Enable auto-merge (squash) via GraphQL. The PR merges once required checks pass.
let node_id = (
  http get
    --headers [Authorization $"Bearer ($env.GH_TOKEN)" Accept "application/vnd.github+json"]
    $"($api)/pulls/($number)"
  | get node_id
)
let mutation = $"mutation { enablePullRequestAutoMerge\(input: {pullRequestId: \"($node_id)\", mergeMethod: SQUASH}\) { clientMutationId } }"
http post --allow-errors --content-type application/json
  --headers [Authorization $"Bearer ($env.GH_TOKEN)"]
  "https://api.github.com/graphql" { query: $mutation }
log $"Auto-merge enabled for PR #($number)."
