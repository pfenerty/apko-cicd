import * as path from "path";
import { Task, Result, scriptFromFile } from "@pfenerty/tektonic";
import { baseImage, apkoImage, melangeImage, statusReporter, dockerConfigVolume } from "../../shared";

// Unified publish workflow. On push it (re)publishes every image whose apko
// config, lock file, or sibling melange.yaml changed. Images with a melange.yaml
// are built with melange first (into a local @local repo); Wolfi images publish
// straight from their committed lockfile. Adding a future melange+apko image needs
// no CI change — just drop a <dir>/melange.yaml, apko config(s), and a Makefile line.
//
// Steps run in one pod sharing the cloned workspace; the apko/melange binaries come
// from this repo's own tool images (no per-run downloads). Only the melange build
// step is privileged (bubblewrap).

const detect = scriptFromFile(path.join(__dirname, "detect.nu"));
const buildMelange = scriptFromFile(path.join(__dirname, "build-melange.nu"));
const publishScript = scriptFromFile(path.join(__dirname, "publish.nu"));

// Tekton Chains build subjects: each published image@digest is written here, and
// Chains records them as subjects in the run's SLSA provenance.
const images = new Result({
  name: "IMAGES",
  description: "Published images (image@digest), recorded as Tekton Chains subjects",
});

export const publishChangedImages = new Task({
  name: "publish-changed-images",
  statusReporter,
  results: [images],
  volumes: [dockerConfigVolume],
  stepTemplate: {
    computeResources: {
      // Kubernetes sums every step container's request even though steps run
      // sequentially — keep it small so the pod fits the shared amd64 worker.
      requests: { cpu: "150m", memory: "256Mi" },
      // melange builds Go from source when a melange.yaml changed — give headroom.
      limits: { cpu: "4", memory: "4Gi" },
    },
  },
  steps: [
    // Decide what to build/publish (writes to-build.txt + to-publish.tsv). base
    // provides git + nushell.
    { name: "detect", image: baseImage, script: detect },
    {
      // Only privileged step: melange's bubblewrap runner needs it. No-op when
      // nothing melange-based changed. privileged requires allowPrivilegeEscalation
      // (the secure-by-default stepTemplate sets it false, which K8s rejects).
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
