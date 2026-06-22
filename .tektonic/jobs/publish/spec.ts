import * as path from "path";
import { Task, Result, scriptFromFile } from "@pfenerty/tektonic";
import { baseImage, statusReporter, dockerConfigVolume } from "../../shared";

const fetchApko = scriptFromFile(path.join(__dirname, "fetch-apko.sh"));
const publishScript = scriptFromFile(path.join(__dirname, "publish.nu"));

// Tekton Chains build subjects: each published image@digest is written here, and
// Chains records them as subjects in the run's SLSA provenance. (CHAINS-GIT_*
// source materials come for free from GitPipeline's git-clone task.)
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
      requests: { cpu: "200m", memory: "256Mi" },
      limits: { cpu: "2", memory: "1Gi" },
    },
  },
  steps: [
    {
      // base:stable is nonroot, so apko is downloaded to the workspace here and
      // reused by the publish step.
      name: "fetch-apko",
      image: baseImage,
      script: fetchApko,
    },
    {
      name: "publish",
      image: baseImage,
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
