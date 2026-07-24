import { GitPipeline, TektonicProject, TRIGGER_EVENTS } from "@pfenerty/tektonic";

import { publishChangedImages } from "./jobs/publish/spec";

// ─── Push pipeline (Pipelines as Code) ────────────────────────────────────────
// On push to main, (re)publish every image whose apko config, lock file, or
// sibling melange.yaml changed. The trigger's pathsChanged keeps the run from
// firing on non-image commits (docs, CI, scripts). cloneDepth: 2 lets the detect
// task compute `git diff HEAD~1 HEAD`.
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
  tasks: [publishChangedImages],
});

new TektonicProject({
  name: "apko-cicd",
  namespace: "apko-cicd-ci",
  pipelines: [pushPipeline],
  outdir: "../.tekton",
  repoRelativePath: ".tekton",
  serviceAccountName: "default",
  workspaceStorageSize: "2Gi",
  workspaceStorageClass: "local-path",
});

// NOTE: the daily package-update job (.tekton/update/) is a standalone Pipeline +
// CronJob that is now hand-authored — the current tektonic is all-in on PAC and no
// longer emits triggerless pipelines. It is not synthesized here.
