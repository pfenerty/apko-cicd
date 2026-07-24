import * as path from "path";
import { Task, Param, Result, scriptFromFile } from "@pfenerty/tektonic";
import { baseImage, apkoImage, melangeImage, dockerConfigVolume } from "../../shared";

// Change-driven matrix publish. `detect` emits one unit per changed image (its
// apko config, lock file, or sibling melange.yaml changed); `build-publish-image`
// fans out over them into one build+publish job per image. Melange-built images
// build their apk first (privileged), then apko publish. Adding a future
// melange+apko image needs no CI change.

const detectScript = scriptFromFile(path.join(__dirname, "detect.nu"));
const buildMelange = scriptFromFile(path.join(__dirname, "build-melange.nu"));
const publishScript = scriptFromFile(path.join(__dirname, "publish.nu"));

// Array of changed-image units — one element per fan-out matrix cell.
const units = new Result({ name: "units", type: "array" });

export const detectChangedImages = new Task({
  name: "detect-changed-images",
  results: [units],
  steps: [{ name: "detect", image: baseImage, script: detectScript }],
});

// The unit string (config,tag,lock,melange) this matrix cell builds/publishes.
const unitParam = new Param({ name: "unit" });

// Per-cell published image@digest (Tekton Chains subject; the matrix aggregates
// these into an array on the pipeline task).
const image = new Result({ name: "IMAGE", description: "Published image@digest" });

export const buildPublishImage = new Task({
  name: "build-publish-image",
  params: [unitParam],
  fanOut: { over: units, as: unitParam },
  results: [image],
  volumes: [dockerConfigVolume],
  stepTemplate: {
    computeResources: {
      // Cells run as separate pods; keep requests small so several fit the worker.
      requests: { cpu: "100m", memory: "256Mi" },
      // melange builds Go from source for melange images — give headroom.
      limits: { cpu: "4", memory: "4Gi" },
    },
  },
  steps: [
    {
      // Only privileged step: melange's bubblewrap runner needs it. No-op for
      // Wolfi images. privileged requires allowPrivilegeEscalation (the secure
      // default sets it false, which K8s rejects alongside privileged).
      name: "build-melange",
      image: melangeImage,
      securityContext: { privileged: true, runAsUser: 0, runAsNonRoot: false, allowPrivilegeEscalation: true },
      script: buildMelange,
    },
    {
      name: "publish",
      image: apkoImage,
      env: [{ name: "DOCKER_CONFIG", value: "/tmp/docker-auth" }],
      volumeMounts: [
        {
          name: "docker-config",
          mountPath: "/tmp/docker-auth/config.json",
          subPath: ".dockerconfigjson",
          readOnly: true,
        },
      ],
      script: publishScript,
    },
  ],
});
