import { GitHubStatusReporter, TaskVolumeSpec } from "@pfenerty/tektonic";

// base:stable provides /bin/sh, git, nushell, curl and tar — everything the
// clone and publish steps invoke. It runs as nonroot (uid 1001).
export const baseImage = "ghcr.io/pfenerty/apko-cicd/base:stable";

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
