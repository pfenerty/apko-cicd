import { GitPipeline, TektonicProject, TRIGGER_EVENTS, DEFAULT_BASE_IMAGE } from "@tektonic-ci/core";

import { detectChangedImages, buildPublishImage } from "./jobs/publish/spec";

// ─── Push pipeline (Pipelines as Code) ────────────────────────────────────────
// On push to main, detect every image whose apko config, lock file, or sibling
// melange.yaml changed, then fan out into one build+publish job per image.
// The trigger's pathsChanged keeps the run from firing on non-image commits;
// cloneDepth: 2 lets detect compute `git diff HEAD~1 HEAD`.
const pushPipeline = new GitPipeline({
  name: "push",
  trigger: {
    rules: [
      {
        on: TRIGGER_EVENTS.PUSH,
        branch: "main",
        pathsChanged: ["base/**", "tools/**", "languages/**"],
      },
    ],
  },
  cloneDepth: 2,
  // A full [rebuild-all] fans out to ~50 cells that largely serialize on the single
  // amd64 build node, exceeding Tekton's default 1h PipelineRun timeout.
  timeout: "3h",
  tasks: [detectChangedImages, buildPublishImage],
});

new TektonicProject({
  name: "apko-cicd",
  namespace: "apko-cicd-ci",
  pipelines: [pushPipeline],
  outdir: "../.tekton",
  repoRelativePath: ".tekton",
  serviceAccountName: "default",
  // tektonic 2.x defaults injected steps (git-clone, status reporting) to Docker Hub's
  // sh+git image; the status steps are nushell, so keep the base image 1.x used.
  injectedStepImage: DEFAULT_BASE_IMAGE,
  workspaceStorageSize: "2Gi",
  workspaceStorageClass: "local-path",
});

// NOTE: the daily package-update job (ci/update/) is a standalone Pipeline + CronJob that
// is hand-authored: tektonic is all-in on PAC and no longer emits triggerless pipelines.
// It lives outside .tekton/ because `tektonic synth` owns that directory and deletes any
// file it did not emit. homelab's apko-cicd-update Flux Kustomization applies it.
