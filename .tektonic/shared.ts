import { GitHubStatusReporter, TaskVolumeSpec } from "@pfenerty/tektonic";

// base:stable provides /bin/sh, git, nushell, curl and tar — everything the
// clone and publish steps invoke. It runs as nonroot (uid 1001).
export const baseImage = "ghcr.io/pfenerty/apko-cicd/base:stable";

// This repo's own tool images provide the apko/melange binaries (plus base's
// git + nushell), so CI steps use them directly instead of downloading a binary
// on every run. Both are built on base (nonroot) and pulled via the SA's
// ghcr-docker-config imagePullSecret.
//
// These are RUNNER images and must be tags that already exist in the registry —
// the pipeline uses apko to publish, so it can't bootstrap from an unpublished
// tag. They intentionally lag the Makefile's publish targets (which can be bumped
// ahead of a successful publish); bump these deliberately once a newer tag is live.
export const apkoImage = "ghcr.io/pfenerty/apko-cicd/apko:1.2.25";
export const melangeImage = "ghcr.io/pfenerty/apko-cicd/melange:0.54.0";

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
