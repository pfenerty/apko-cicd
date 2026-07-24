import * as path from "path";
import { Task, Result, scriptFromFile } from "@pfenerty/tektonic";
import { baseImage, statusReporter, dockerConfigVolume } from "../../shared";

// gosec is not a Wolfi package: it is built from source with melange and consumed
// by the apko configs from a local repo. This task fetches apko + melange, builds
// the gosec apk, and publishes the per-Go-version gosec images — but only when
// something under tools/gosec/ changed in the last commit (see build-publish.nu).

const fetchApko = scriptFromFile(path.join(__dirname, "..", "publish", "fetch-apko.sh"));
const fetchMelange = scriptFromFile(path.join(__dirname, "fetch-melange.sh"));
const buildPublish = scriptFromFile(path.join(__dirname, "build-publish.nu"));

const images = new Result({
  name: "IMAGES",
  description: "Published gosec images (image@digest), recorded as Tekton Chains subjects",
});

export const buildPublishGosec = new Task({
  name: "build-publish-gosec",
  statusReporter,
  results: [images],
  volumes: [dockerConfigVolume],
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
    {
      // base:stable is nonroot, so apko + melange are downloaded to the workspace
      // here (writable via fsGroup) and reused by the build-publish step.
      name: "fetch-apko",
      image: baseImage,
      script: fetchApko,
    },
    {
      name: "fetch-melange",
      image: baseImage,
      script: fetchMelange,
    },
    {
      name: "build-publish",
      image: baseImage,
      env: [{ name: "DOCKER_CONFIG", value: "/tmp/docker-auth" }],
      // melange's default (bubblewrap) runner needs elevated privileges to set up
      // its build sandbox — the secure-by-default stepTemplate drops all caps.
      // VALIDATE IN-CLUSTER: this may need tuning to the node's user-namespace
      // policy (e.g. specific caps instead of full privileged) on the Talos cluster.
      // privileged requires allowPrivilegeEscalation:true — must override the
      // secure-by-default stepTemplate (which sets it false), or the pod is rejected.
      securityContext: { privileged: true, runAsUser: 0, runAsNonRoot: false, allowPrivilegeEscalation: true },
      volumeMounts: [
        {
          name: "docker-config",
          mountPath: "/tmp/docker-auth/config.json",
          subPath: ".dockerconfigjson",
          readOnly: true,
        },
      ],
      script: buildPublish,
    },
  ],
});
