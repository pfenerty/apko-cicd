import { GitHubStatusReporter, TaskVolumeSpec } from "@pfenerty/tektonic";

// base:stable provides /bin/sh, git, nushell, curl and tar — everything the
// clone and publish steps invoke. It runs as nonroot (uid 1001).
export const baseImage = "ghcr.io/pfenerty/apko-cicd/base:stable";

// This repo's own tool images provide the apko/melange binaries (plus base's
// git + nushell), so CI steps use them directly instead of downloading a binary
// on every run. Keep these tags in sync with the Makefile's tools-apko/
// tools-melange IMAGE entries. Both images are built on base (nonroot).
export const apkoImage = "ghcr.io/pfenerty/apko-cicd/apko:1.2.27";
export const melangeImage = "ghcr.io/pfenerty/apko-cicd/melange:0.56.3";

// Reports CI status back to GitHub. Requires a `github-pipeline-token` Secret
// (key `token`, scope repo:status) in the apko-cicd-ci namespace.
export const statusReporter = new GitHubStatusReporter({
  tokenSecretName: "github-pipeline-token",
});

// ghcr.io push credentials, mounted into the publish step as a docker config.
export const dockerConfigVolume: TaskVolumeSpec = {
  name: "docker-config",
  secret: { secretName: "ghcr-docker-config" },
};
