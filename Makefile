REGISTRY   := ghcr.io/pfenerty/apko-cicd
DIST_DIR   := dist
APKO       := apko
APKO_BUILD  = $(APKO) build --sbom-path $(DIST_DIR)

.PHONY: all build clean \
  base \
  tools-syft tools-grype tools-oras tools-apko tools-melange \
  nodejs-18 nodejs-20 nodejs-22 nodejs-24 \
  golang-1.22 golang-1.23 golang-1.24 \
  java-jdk-11 java-maven-3.9-jdk11 java-gradle-8-jdk11 \
  java-jdk-17 java-maven-3.9-jdk17 java-gradle-8-jdk17 \
  java-jdk-21 java-maven-3.9-jdk21 java-gradle-8-jdk21 \
  java-jdk-24 java-maven-3.9-jdk24 java-gradle-8-jdk24 \
  rust-1.92 rust-1.93 rust-1.94

all: base \
  tools-syft tools-grype tools-oras tools-apko tools-melange \
  nodejs-18 nodejs-20 nodejs-22 nodejs-24 \
  golang-1.22 golang-1.23 golang-1.24 \
  java-jdk-11 java-maven-3.9-jdk11 java-gradle-8-jdk11 \
  java-jdk-17 java-maven-3.9-jdk17 java-gradle-8-jdk17 \
  java-jdk-21 java-maven-3.9-jdk21 java-gradle-8-jdk21 \
  java-jdk-24 java-maven-3.9-jdk24 java-gradle-8-jdk24 \
  rust-1.92 rust-1.93 rust-1.94

build: all

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

# ── Base ─────────────────────────────────────────────────────────────────────

base: $(DIST_DIR)
	$(APKO_BUILD) base/apko.yaml $(REGISTRY)/base:stable $(DIST_DIR)/base.tar

# ── Tools ────────────────────────────────────────────────────────────────────

tools-syft: $(DIST_DIR)
	$(APKO_BUILD) tools/syft/apko.yaml $(REGISTRY)/syft:1.42.3 $(DIST_DIR)/syft.tar

tools-grype: $(DIST_DIR)
	$(APKO_BUILD) tools/grype/apko.yaml $(REGISTRY)/grype:0.110.0 $(DIST_DIR)/grype.tar

tools-oras: $(DIST_DIR)
	$(APKO_BUILD) tools/oras/apko.yaml $(REGISTRY)/oras:1.3.1 $(DIST_DIR)/oras.tar

tools-apko: $(DIST_DIR)
	$(APKO_BUILD) tools/apko/apko.yaml $(REGISTRY)/apko:1.1.16 $(DIST_DIR)/apko.tar

tools-melange: $(DIST_DIR)
	$(APKO_BUILD) tools/melange/apko.yaml $(REGISTRY)/melange:0.46.1 $(DIST_DIR)/melange.tar

# ── Node.js ──────────────────────────────────────────────────────────────────

nodejs-18: $(DIST_DIR)
	$(APKO_BUILD) languages/nodejs/18.yaml $(REGISTRY)/nodejs:18 $(DIST_DIR)/nodejs-18.tar

nodejs-20: $(DIST_DIR)
	$(APKO_BUILD) languages/nodejs/20.yaml $(REGISTRY)/nodejs:20 $(DIST_DIR)/nodejs-20.tar

nodejs-22: $(DIST_DIR)
	$(APKO_BUILD) languages/nodejs/22.yaml $(REGISTRY)/nodejs:22 $(DIST_DIR)/nodejs-22.tar

nodejs-24: $(DIST_DIR)
	$(APKO_BUILD) languages/nodejs/24.yaml $(REGISTRY)/nodejs:24 $(DIST_DIR)/nodejs-24.tar

# ── Go ───────────────────────────────────────────────────────────────────────

golang-1.22: $(DIST_DIR)
	$(APKO_BUILD) languages/golang/1.22.yaml $(REGISTRY)/golang:1.22 $(DIST_DIR)/golang-1.22.tar

golang-1.23: $(DIST_DIR)
	$(APKO_BUILD) languages/golang/1.23.yaml $(REGISTRY)/golang:1.23 $(DIST_DIR)/golang-1.23.tar

golang-1.24: $(DIST_DIR)
	$(APKO_BUILD) languages/golang/1.24.yaml $(REGISTRY)/golang:1.24 $(DIST_DIR)/golang-1.24.tar

# ── Java ─────────────────────────────────────────────────────────────────────

java-jdk-11: $(DIST_DIR)
	$(APKO_BUILD) languages/java/11/jdk.yaml $(REGISTRY)/jdk:11 $(DIST_DIR)/java-jdk-11.tar

java-maven-3.9-jdk11: $(DIST_DIR)
	$(APKO_BUILD) languages/java/11/maven-3.9.yaml $(REGISTRY)/maven:3.9-jdk11 $(DIST_DIR)/java-maven-3.9-jdk11.tar

java-gradle-8-jdk11: $(DIST_DIR)
	$(APKO_BUILD) languages/java/11/gradle-8.yaml $(REGISTRY)/gradle:8-jdk11 $(DIST_DIR)/java-gradle-8-jdk11.tar

java-jdk-17: $(DIST_DIR)
	$(APKO_BUILD) languages/java/17/jdk.yaml $(REGISTRY)/jdk:17 $(DIST_DIR)/java-jdk-17.tar

java-maven-3.9-jdk17: $(DIST_DIR)
	$(APKO_BUILD) languages/java/17/maven-3.9.yaml $(REGISTRY)/maven:3.9-jdk17 $(DIST_DIR)/java-maven-3.9-jdk17.tar

java-gradle-8-jdk17: $(DIST_DIR)
	$(APKO_BUILD) languages/java/17/gradle-8.yaml $(REGISTRY)/gradle:8-jdk17 $(DIST_DIR)/java-gradle-8-jdk17.tar

java-jdk-21: $(DIST_DIR)
	$(APKO_BUILD) languages/java/21/jdk.yaml $(REGISTRY)/jdk:21 $(DIST_DIR)/java-jdk-21.tar

java-maven-3.9-jdk21: $(DIST_DIR)
	$(APKO_BUILD) languages/java/21/maven-3.9.yaml $(REGISTRY)/maven:3.9-jdk21 $(DIST_DIR)/java-maven-3.9-jdk21.tar

java-gradle-8-jdk21: $(DIST_DIR)
	$(APKO_BUILD) languages/java/21/gradle-8.yaml $(REGISTRY)/gradle:8-jdk21 $(DIST_DIR)/java-gradle-8-jdk21.tar

java-jdk-24: $(DIST_DIR)
	$(APKO_BUILD) languages/java/24/jdk.yaml $(REGISTRY)/jdk:24 $(DIST_DIR)/java-jdk-24.tar

java-maven-3.9-jdk24: $(DIST_DIR)
	$(APKO_BUILD) languages/java/24/maven-3.9.yaml $(REGISTRY)/maven:3.9-jdk24 $(DIST_DIR)/java-maven-3.9-jdk24.tar

java-gradle-8-jdk24: $(DIST_DIR)
	$(APKO_BUILD) languages/java/24/gradle-8.yaml $(REGISTRY)/gradle:8-jdk24 $(DIST_DIR)/java-gradle-8-jdk24.tar

# ── Rust ─────────────────────────────────────────────────────────────────────

rust-1.92: $(DIST_DIR)
	$(APKO_BUILD) languages/rust/1.92.yaml $(REGISTRY)/rust:1.92 $(DIST_DIR)/rust-1.92.tar

rust-1.93: $(DIST_DIR)
	$(APKO_BUILD) languages/rust/1.93.yaml $(REGISTRY)/rust:1.93 $(DIST_DIR)/rust-1.93.tar

rust-1.94: $(DIST_DIR)
	$(APKO_BUILD) languages/rust/1.94.yaml $(REGISTRY)/rust:1.94 $(DIST_DIR)/rust-1.94.tar

# ── Util ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(DIST_DIR)
