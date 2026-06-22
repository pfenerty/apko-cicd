import { GitPipeline, PACProject, TRIGGER_EVENTS } from "@pfenerty/tektonic";

import { publishChangedImages } from "./jobs/publish/spec";

// ─── Pipeline ────────────────────────────────────────────────────────────────
// On push to main, publish any apko images whose lockfiles changed.
// cloneDepth: 2 so the publish task can compute `git diff HEAD~1 HEAD`.
const pushPipeline = new GitPipeline({
  name: "push",
  triggers: [TRIGGER_EVENTS.PUSH],
  onTargetBranch: "main",
  cloneDepth: 2,
  tasks: [publishChangedImages],
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
