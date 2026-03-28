REGISTRY   := ghcr.io/pfenerty/apko-cicd
DIST_DIR   := dist
APKO       := apko
APKO_BUILD   = $(APKO) build --sbom-path $(DIST_DIR)
APKO_PUBLISH = $(APKO) publish --sbom-path $(DIST_DIR)

IMAGES :=

# $(1)=target  $(2)=config  $(3)=image:tag
define IMAGE
IMAGES += $(1)
.PHONY: $(1) publish-$(1)
$(1): $$(DIST_DIR)
	$$(APKO_BUILD) $(2) $$(REGISTRY)/$(3) $$(DIST_DIR)/$(1).tar
publish-$(1): $$(DIST_DIR)
	$$(APKO_PUBLISH) $(2) $$(REGISTRY)/$(3)
endef

# ── Base ─────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,base,base/apko.yaml,base:stable))

# ── Tools ────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,tools-syft,tools/syft/apko.yaml,syft:1.42.3))
$(eval $(call IMAGE,tools-grype,tools/grype/apko.yaml,grype:0.110.0))
$(eval $(call IMAGE,tools-oras,tools/oras/apko.yaml,oras:1.3.1))
$(eval $(call IMAGE,tools-apko,tools/apko/apko.yaml,apko:1.1.16))
$(eval $(call IMAGE,tools-melange,tools/melange/apko.yaml,melange:0.46.1))
$(eval $(call IMAGE,tools-golangci-lint,tools/golangci-lint/apko.yaml,golangci-lint:2.11.4))

# ── Node.js ──────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,nodejs-18,languages/nodejs/18.yaml,nodejs:18))
$(eval $(call IMAGE,nodejs-20,languages/nodejs/20.yaml,nodejs:20))
$(eval $(call IMAGE,nodejs-22,languages/nodejs/22.yaml,nodejs:22))
$(eval $(call IMAGE,nodejs-24,languages/nodejs/24.yaml,nodejs:24))

# ── Go ───────────────────────────────────────────────────────────────────────
$(eval $(call IMAGE,golang-1.22,languages/golang/1.22.yaml,golang:1.22))
$(eval $(call IMAGE,golang-1.23,languages/golang/1.23.yaml,golang:1.23))
$(eval $(call IMAGE,golang-1.24,languages/golang/1.24.yaml,golang:1.24))

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
