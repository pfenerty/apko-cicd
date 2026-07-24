import * as path from "path";
import { Task, scriptFromFile } from "@pfenerty/tektonic";
import { baseImage } from "../../shared";

// Daily package-version update, migrated off GitHub Actions. Regenerates every
// apko lock file (building the gosec apk with melange first so its @local configs
// resolve), updates Makefile tags/annotations from the locks, and opens an
// auto-merging PR. Started on a schedule by .tekton/update/update-packages-cronjob.yaml.

const fetchApko = scriptFromFile(path.join(__dirname, "..", "publish", "fetch-apko.sh"));
const fetchMelange = scriptFromFile(path.join(__dirname, "..", "gosec", "fetch-melange.sh"));
const regenLockfiles = scriptFromFile(path.join(__dirname, "regen-lockfiles.nu"));
const openPr = scriptFromFile(path.join(__dirname, "open-pr.nu"));

// Chainguard python image for the update-versions.py step (base:stable has no python3).
const pythonImage = "cgr.dev/chainguard/python:latest-dev";

export const updatePackages = new Task({
  name: "update-packages",
  stepTemplate: {
    computeResources: {
      // Steps run sequentially, but Kubernetes sums every step container's request
      // when scheduling. Keep the request small so the pod fits on the shared amd64
      // worker; the melange build still bursts to the limit (4 cores).
      requests: { cpu: "200m", memory: "512Mi" },
      limits: { cpu: "4", memory: "4Gi" },
    },
  },
  steps: [
    { name: "fetch-apko", image: baseImage, script: fetchApko },
    { name: "fetch-melange", image: baseImage, script: fetchMelange },
    {
      name: "regen-lockfiles",
      image: baseImage,
      // melange's bubblewrap runner needs elevated privileges (see gosec task).
      // VALIDATE IN-CLUSTER against the node's user-namespace policy.
      // privileged requires allowPrivilegeEscalation:true — must override the
      // secure-by-default stepTemplate (which sets it false), or the pod is rejected.
      securityContext: { privileged: true, runAsUser: 0, runAsNonRoot: false, allowPrivilegeEscalation: true },
      script: regenLockfiles,
    },
    {
      name: "update-versions",
      image: pythonImage,
      script: { language: "python", body: "import runpy; runpy.run_path('scripts/update-versions.py', run_name='__main__')" },
    },
    {
      name: "open-pr",
      image: baseImage,
      env: [
        {
          name: "GH_TOKEN",
          valueFrom: { secretKeyRef: { name: "github-automerge-token", key: "token" } },
        },
      ],
      script: openPr,
    },
  ],
});
