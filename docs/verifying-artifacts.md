# Verifying apko-cicd artifacts

These [apko](https://github.com/chainguard-dev/apko) images are published to
`ghcr.io/pfenerty/apko-cicd/*` (`base`, `apko`, `gcloud`, `grype`, `melange`, `oras`,
`syft`, …) with SBOMs and signed build provenance you can verify before use.

## What each image carries

| Artifact | Producer | Signed | Where |
|---|---|---|---|
| SPDX SBOM (per package) | apko (build time) | no | embedded in the image filesystem at `/var/lib/db/sbom/` |
| Signed SLSA provenance + image signature | Tekton Chains (cluster) | **yes** — cosign x509 + Rekor | attached to the image in the registry |

The signing public key is published in this repo: [`cosign.pub`](../cosign.pub) — or fetch it:

```bash
curl -fsSL https://raw.githubusercontent.com/pfenerty/apko-cicd/main/cosign.pub -o cosign.pub
```

Always verify by **immutable digest**:

```bash
IMAGE=ghcr.io/pfenerty/apko-cicd/base
REF="$IMAGE@$(docker buildx imagetools inspect "$IMAGE:stable" --format '{{.Manifest.Digest}}')"
```

## 1. Verify the signature + signed provenance (recommended)

```bash
# Tekton Chains image signature (cosign simplesigning)
cosign verify --key cosign.pub "$REF"

# Signed SLSA provenance attestation (Chains emits SLSA v1.0, so use slsaprovenance1;
# the bare `slsaprovenance` alias is SLSA v0.2 and will not match)
cosign verify-attestation --key cosign.pub --type slsaprovenance1 "$REF" \
  | jq -r '.payload | @base64d | fromjson | .predicate'
```

## 2. Extract the apko SBOM (no key needed)

apko embeds an SPDX SBOM for each package inside the image filesystem:

```bash
cid=$(docker create "$REF"); docker cp "$cid":/var/lib/db/sbom ./sbom; docker rm "$cid"
ls ./sbom    # *.spdx.json
```

## 3. Transparency log (Rekor)

```bash
rekor-cli search --sha "${REF#*@}"
```

The producing PipelineRun also carries a `chains.tekton.dev/transparency` annotation linking
the exact Rekor entry, and an `IMAGES` result listing every published `image@digest`.

## Status / prerequisites

The signed, image-attached verification in **step 1** requires Tekton Chains **OCI storage**
enabled with a registry-push credential on the chains controller (see the `homelab` repo); it
applies to images built after that is in place. Steps 2 and 3 work today.
