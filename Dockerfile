# syntax=docker/dockerfile:1
# Multi-stage build: static Go binary -> distroless. See docs/DEPLOY.md "Docker".
#
#   docker build -t cronova .
#   docker build --build-arg VERSION="$(git describe --tags --always --dirty)" -t cronova .
#
# The binary embeds the web console (internal/web, embed.FS), so the final image
# is just the scheduler plus a static busybox shell. The shell is not optional:
# the executor launches EVERY task through `sh -c` (internal/executor/runner.go),
# including the pure-Go http/sql operators (`cronova run-op ...`). python/jar
# tasks need interpreters this image deliberately does not carry — pair the
# scheduler with a host-side cronova-executor for those (docs/DEPLOY.md).

ARG GO_VERSION=1.26.5

FROM golang:${GO_VERSION}-alpine AS build
WORKDIR /src
# Cache module downloads separately from source changes.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# VERSION is baked with the same ldflags contract as the Makefile / package.sh
# (-X main.version). TARGETOS/TARGETARCH make `docker buildx` cross-builds work.
ARG TARGETOS TARGETARCH
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" \
    -o /out/cronova ./cmd/cronova

# Stage a rootfs snippet here because the distroless final stage has no shell to
# run mkdir/ln: the state-dir skeleton (chowned to nonroot on COPY, so the named
# volume's first-use copy-up hands the mount to uid 65532), the example DAGs
# (the same seeding deploy/install.sh performs), and symlinks for the busybox
# applets shell tasks may use.
RUN mkdir -p /rootfs/bin \
      /rootfs/var/lib/cronova/data \
      /rootfs/var/lib/cronova/dags \
      /rootfs/var/lib/cronova/logs \
      /rootfs/var/lib/cronova/projects \
      /rootfs/var/lib/cronova/workspaces \
      /rootfs/var/lib/cronova/backups && \
    cp dags/*.yaml /rootfs/var/lib/cronova/dags/ && \
    for a in sh ash env printf echo true false test [ cat cp mv rm mkdir rmdir \
             ls ln date sleep sed awk grep head tail tr cut sort uniq wc xargs \
             find tar gzip gunzip basename dirname wget od stat tee touch \
             readlink realpath seq expr sync mktemp; do \
      ln -s /bin/busybox "/rootfs/bin/$a"; \
    done

# Java runtime + build tools stage. Temurin alpine gives us a JDK and a shell
# (busybox ash) so cronova can both serve and compile Spring Boot projects
# inside the same container. Maven is unpacked on top of the JDK image.
FROM eclipse-temurin:25-jdk-alpine AS java-tools
ARG MAVEN_VERSION=3.9.9
RUN apk add --no-cache curl tar bash && \
    mkdir -p /opt/maven && \
    curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      -o /tmp/maven.tar.gz && \
    tar -xzf /tmp/maven.tar.gz -C /opt/maven --strip-components=1 && \
    rm /tmp/maven.tar.gz && \
    /opt/maven/bin/mvn -version

# Final image: Temurin JDK + Maven + cronova binary. We keep a non-root user
# and copy the busybox applets from the build stage for a consistent shell.
FROM eclipse-temurin:25-jdk-alpine
COPY --from=build /rootfs/bin/ /bin/
COPY --from=build --chown=65532:65532 /rootfs/var/lib/cronova /var/lib/cronova
COPY --from=build /out/cronova /cronova
COPY --from=java-tools --chown=65532:65532 /opt/maven /opt/maven

# All state lives under the single /var/lib/cronova volume. These envs also
# steer the `healthcheck`, `users`, and `backup` subcommands run via
# `docker exec` (each reads CRONOVA_* itself).
ENV CRONOVA_DB=/var/lib/cronova/data/cronova.db \
    CRONOVA_DAGS=/var/lib/cronova/dags \
    CRONOVA_LOGS=/var/lib/cronova/logs \
    CRONOVA_PROJECTS=/var/lib/cronova/projects \
    CRONOVA_WORKSPACES=/var/lib/cronova/workspaces \
    CRONOVA_KEY_FILE=/var/lib/cronova/cronova.key \
    JAVA_HOME=/opt/java/openjdk \
    MAVEN_HOME=/opt/maven \
    PATH=/opt/maven/bin:/opt/java/openjdk/bin:/usr/local/bin:/usr/bin:/bin

WORKDIR /var/lib/cronova
VOLUME /var/lib/cronova
EXPOSE 8090
USER 65532:65532

# `cronova healthcheck` probes /readyz itself — no curl/wget/shell required.
# It honors CRONOVA_HTTP (rewriting 0.0.0.0 to 127.0.0.1 for the probe).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/cronova", "healthcheck"]

ENTRYPOINT ["/cronova"]
CMD ["serve"]
