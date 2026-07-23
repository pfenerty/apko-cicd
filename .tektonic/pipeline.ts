import { GitPipeline, PACProject, TektonProject, TRIGGER_EVENTS } from "@pfenerty/tektonic";

import { publishChangedImages } from "./jobs/publish/spec";
import { buildPublishGosec } from "./jobs/gosec/spec";
import { updatePackages } from "./jobs/update/spec";

// ─── Push pipeline (Pipelines as Code) ────────────────────────────────────────
// On push to main, publish any apko images whose lockfiles changed, and (when
// tools/gosec/ changed) build the gosec apk with melange and publish its images.
// cloneDepth: 2 so both tasks can compute `git diff HEAD~1 HEAD`.
const pushPipeline = new GitPipeline({
  name: "push",
  triggers: [TRIGGER_EVENTS.PUSH],
  onTargetBranch: "main",
  cloneDepth: 2,
  tasks: [publishChangedImages, buildPublishGosec],
});

new PACProject({
  name: "apko-cicd",
  namespace: "apko-cicd-ci",
  pipelines: [pushPipeline],
  outdir: "../.tekton",
  repoRelativePath: ".tekton",
  serviceAccountName: "default",
  workspaceStorageSize: "2Gi",
  workspaceStorageClass: "local-path",
});

// ─── Update pipeline (scheduled via CronJob, not a webhook) ────────────────────
// Migrated off GitHub Actions. Triggerless: it has no GitHub event, so it is
// emitted as a plain Pipeline + Tasks by TektonProject (PACProject skips
// triggerless pipelines). A standalone CronJob
// (.tekton/update/update-packages-cronjob.yaml) creates a PipelineRun of it daily.
// Isolated outdir avoids colliding with the PAC output above.
const updatePipeline = new GitPipeline({
  name: "update-packages",
  tasks: [updatePackages],
});

new TektonProject({
  name: "apko-cicd-update",
  namespace: "apko-cicd-ci",
  pipelines: [updatePipeline],
  outdir: "../.tekton/update",
  serviceAccountName: "default",
  workspaceStorageSize: "2Gi",
  workspaceStorageClass: "local-path",
});
