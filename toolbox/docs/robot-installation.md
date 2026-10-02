# Local ROBOT installation

## Recommended installation

Install ROBOT inside the repository without changing the global `PATH` and
without requiring `sudo`:

```bash
make install-robot
```

The installer:

1. uses an existing Java 17 or later runtime when one is functional;
2. otherwise downloads Eclipse Temurin JDK 17 for macOS or Linux;
3. downloads the pinned ROBOT `1.9.10` JAR;
4. verifies the ROBOT JAR against its pinned SHA-256 checksum;
5. creates local `java` and `robot` launchers.

Everything downloaded or generated is stored under `.tools/`. This directory
is ignored by Git. The installation script and this procedure remain tracked.

```text
.tools/
  bin/
    java
    robot
  java/17/                 # only when a local JDK is needed
  robot/1.9.10/robot.jar
  robot/current -> 1.9.10
```

## Using the local installation

All repository build scripts automatically prepend `.tools/bin` when the local
ROBOT launcher exists. After installation, normal commands work without
exporting environment variables:

```bash
make import
make all
make test-imports
make test-profiles
```

For a direct check:

```bash
./.tools/bin/java -version
./.tools/bin/robot --version
```

To use ROBOT interactively in the current shell:

```bash
export PATH="$PWD/.tools/bin:$PATH"
robot --version
```

## RDF/XML files named `.rdf`

ROBOT accepts `.owl` as an RDF/XML output extension and does not infer a
supported format from the `.rdf` extension. When `OUTPUT_FORMAT=rdf`, repository
scripts therefore ask ROBOT to write a temporary `.owl` file, then copy the
unchanged RDF/XML document to its required `.rdf` delivery name and remove the
temporary file. With `OUTPUT_FORMAT=ttl` or `OUTPUT_FORMAT=owl`, ROBOT writes the
configured path directly. This is a filename compatibility workaround, not an
OWL-to-RDF semantic conversion.

Do not call ROBOT with `--output result.rdf`, even with an explicit format.
Use the shared output helpers and let the repository scripts publish the
configured artifact.

## Optional JVM profile

For large reasoning tasks, generate a conservative machine-specific profile:

```bash
make java-conf
```

This writes `conf/java.conf`, which is loaded once by `toolbox/common.sh` into
`JAVA_TOOL_OPTIONS`. The generated file is ignored by Git; only its generator is
tracked. `JAVA_CPU_LIMIT` and `JAVA_HEAP_LIMIT_MB` can override the defaults.

## Installation options

The default `INSTALL_LOCAL_JAVA=auto` reuses a compatible system Java and
downloads Temurin only when necessary.

```bash
# Always install a repository-local JDK 17
INSTALL_LOCAL_JAVA=always make install-robot

# Never download Java; fail when Java 17+ is unavailable
INSTALL_LOCAL_JAVA=never make install-robot
```

The pinned ROBOT release can be overridden deliberately, but its matching
checksum must also be supplied:

```bash
ROBOT_VERSION=<version> \
ROBOT_SHA256=<sha256> \
make install-robot
```

The official ROBOT releases are published at
<https://github.com/ontodev/robot/releases>.

## Reinstallation and cleanup

Running `make install-robot` again is idempotent when the installed JAR matches
the pinned checksum. An invalid local JDK is moved to a timestamped backup under
`.tools/java/` before replacement.

To return to global tools, remove or rename `.tools/`. No tracked repository
file is stored there.
