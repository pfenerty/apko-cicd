import { GitPipeline, PACProject, TRIGGER_EVENTS } from "@pfenerty/tektonic";

import { publishChangedImages } from "./jobs/publish/spec";
import { buildPublishGosec } from "./jobs/gosec/spec";

// ─── Pipeline ────────────────────────────────────────────────────────────────
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

// ─── Synthesize (Pipelines as Code) ──────────────────────────────────────────
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
