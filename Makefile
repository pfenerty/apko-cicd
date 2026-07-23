REGISTRY   := ghcr.io/pfenerty/apko-cicd
DIST_DIR   := dist
APKO       := apko --log-level WARN

IMAGES :=

# $(1)=target  $(2)=config  $(3)=image:tag
# Passes --lockfile when a lock file exists alongside the config YAML.
# Lock file path: tools/grype/apko.yaml -> tools/grype/apko.lock.json
define IMAGE
IMAGES += $(1)
.PHONY: $(1) publish-$(1)
$(1): $$(DIST_DIR)
	$$(APKO) build --sbom-path $$(DIST_DIR) $$(if $$(wildcard $(2:.yaml=.lock.json)),--lockfile $(2:.yaml=.lock.json)) $(2) $$(REGISTRY)/$(3) $$(DIST_DIR)/$(1).tar
publish-$(1): $$(DIST_DIR)
	$$(APKO) publish --sbom-path $$(DIST_DIR) $$(if $$(wildcard $(2:.yaml=.lock.json)),--lockfile $(2:.yaml=.lock.json)) $(2) $$(REGISTRY)/$(3)
endef

# ── Base ─────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,base,base/apko.yaml,base:stable))

# ── Tools ────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,tools-syft,tools/syft/apko.yaml,syft:1.48.0))
$(eval $(call IMAGE,tools-grype,tools/grype/apko.yaml,grype:0.116.0))
$(eval $(call IMAGE,tools-oras,tools/oras/apko.yaml,oras:1.3.3))
$(eval $(call IMAGE,tools-apko,tools/apko/apko.yaml,apko:1.2.27))
$(eval $(call IMAGE,tools-melange,tools/melange/apko.yaml,melange:0.56.3))
$(eval $(call IMAGE,tools-golangci-lint-go1.22,tools/golangci-lint/1.22.yaml,golangci-lint:2.12.2-go1.22))
$(eval $(call IMAGE,tools-golangci-lint-go1.23,tools/golangci-lint/1.23.yaml,golangci-lint:2.12.2-go1.23))
$(eval $(call IMAGE,tools-golangci-lint-go1.24,tools/golangci-lint/1.24.yaml,golangci-lint:2.12.2-go1.24))
$(eval $(call IMAGE,tools-golangci-lint-go1.25,tools/golangci-lint/1.25.yaml,golangci-lint:2.12.2-go1.25))
$(eval $(call IMAGE,tools-golangci-lint-go1.26,tools/golangci-lint/1.26.yaml,golangci-lint:2.12.2-go1.26))
$(eval $(call IMAGE,tools-govulncheck-go1.22,tools/govulncheck/1.22.yaml,govulncheck:1.6.0-go1.22))
$(eval $(call IMAGE,tools-govulncheck-go1.23,tools/govulncheck/1.23.yaml,govulncheck:1.6.0-go1.23))
$(eval $(call IMAGE,tools-govulncheck-go1.24,tools/govulncheck/1.24.yaml,govulncheck:1.6.0-go1.24))
$(eval $(call IMAGE,tools-govulncheck-go1.25,tools/govulncheck/1.25.yaml,govulncheck:1.6.0-go1.25))
$(eval $(call IMAGE,tools-govulncheck-go1.26,tools/govulncheck/1.26.yaml,govulncheck:1.6.0-go1.26))
$(eval $(call IMAGE,tools-gosec-go1.22,tools/gosec/1.22.yaml,gosec:2.28.0-go1.22))
$(eval $(call IMAGE,tools-gosec-go1.23,tools/gosec/1.23.yaml,gosec:2.28.0-go1.23))
$(eval $(call IMAGE,tools-gosec-go1.24,tools/gosec/1.24.yaml,gosec:2.28.0-go1.24))
$(eval $(call IMAGE,tools-gosec-go1.25,tools/gosec/1.25.yaml,gosec:2.28.0-go1.25))
$(eval $(call IMAGE,tools-gosec-go1.26,tools/gosec/1.26.yaml,gosec:2.28.0-go1.26))
$(eval $(call IMAGE,tools-gcloud,tools/gcloud/apko.yaml,gcloud:576.0.0))

# gosec has no Wolfi package — build the apk with melange first, then the apko
# configs above consume it from ./packages via the @local repository.
# NOTE: melange builds Linux apks and only runs on Linux (uses bubblewrap), so
# this target runs in the Tekton pipeline / a Linux host — not natively on macOS.
GOSEC_IMAGES := tools-gosec-go1.22 tools-gosec-go1.23 tools-gosec-go1.24 tools-gosec-go1.25 tools-gosec-go1.26
.PHONY: melange-gosec
melange-gosec:
	@test -f local-melange.rsa || melange keygen local-melange.rsa
	melange build tools/gosec/melange.yaml --arch amd64 --signing-key local-melange.rsa --out-dir packages
$(GOSEC_IMAGES) $(addprefix publish-,$(GOSEC_IMAGES)): melange-gosec

# # ── Node.js ──────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,nodejs-18,languages/nodejs/18.yaml,nodejs:18))
$(eval $(call IMAGE,nodejs-20,languages/nodejs/20.yaml,nodejs:20))
$(eval $(call IMAGE,nodejs-22,languages/nodejs/22.yaml,nodejs:22))
$(eval $(call IMAGE,nodejs-24,languages/nodejs/24.yaml,nodejs:24))

# ── Go ───────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,golang-1.22,languages/golang/1.22.yaml,golang:1.22))
$(eval $(call IMAGE,golang-1.23,languages/golang/1.23.yaml,golang:1.23))
$(eval $(call IMAGE,golang-1.24,languages/golang/1.24.yaml,golang:1.24))
$(eval $(call IMAGE,golang-1.25,languages/golang/1.25.yaml,golang:1.25))
$(eval $(call IMAGE,golang-1.26,languages/golang/1.26.yaml,golang:1.26))

# ── Java ─────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,java-jdk-11,languages/java/11/jdk.yaml,jdk:11))
$(eval $(call IMAGE,java-maven-3.9-jdk11,languages/java/11/maven-3.9.yaml,maven:3.9-jdk11))
$(eval $(call IMAGE,java-gradle-8-jdk11,languages/java/11/gradle-8.yaml,gradle:8-jdk11))
$(eval $(call IMAGE,java-jdk-17,languages/java/17/jdk.yaml,jdk:17))
$(eval $(call IMAGE,java-maven-3.9-jdk17,languages/java/17/maven-3.9.yaml,maven:3.9-jdk17))
$(eval $(call IMAGE,java-gradle-8-jdk17,languages/java/17/gradle-8.yaml,gradle:8-jdk17))
$(eval $(call IMAGE,java-jdk-21,languages/java/21/jdk.yaml,jdk:21))
$(eval $(call IMAGE,java-maven-3.9-jdk21,languages/java/21/maven-3.9.yaml,maven:3.9-jdk21))
$(eval $(call IMAGE,java-gradle-8-jdk21,languages/java/21/gradle-8.yaml,gradle:8-jdk21))
$(eval $(call IMAGE,java-jdk-24,languages/java/24/jdk.yaml,jdk:24))
$(eval $(call IMAGE,java-maven-3.9-jdk24,languages/java/24/maven-3.9.yaml,maven:3.9-jdk24))
$(eval $(call IMAGE,java-gradle-8-jdk24,languages/java/24/gradle-8.yaml,gradle:8-jdk24))

# ── Rust ─────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,rust-1.92,languages/rust/1.92.yaml,rust:1.92))
$(eval $(call IMAGE,rust-1.93,languages/rust/1.93.yaml,rust:1.93))
$(eval $(call IMAGE,rust-1.94,languages/rust/1.94.yaml,rust:1.94))

# ── Aggregates ───────────────────────────────────────────────────────────────
.PHONY: all build publish clean

all build: $(IMAGES)
publish: $(addprefix publish-,$(IMAGES))

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

clean:
	rm -rf $(DIST_DIR)

# ── Tekton (Pipelines as Code) ───────────────────────────────────────────────
.PHONY: tekton-synth
tekton-synth:
	cd .tektonic && npm install && npx ts-node pipeline.ts
