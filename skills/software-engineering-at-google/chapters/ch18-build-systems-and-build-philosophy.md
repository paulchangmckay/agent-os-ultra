# Chapter 18: Build Systems and Build Philosophy

## Core Idea
Task-based build systems fail at scale because they give engineers too much power (arbitrary scripts) and the system too little information; artifact-based build systems (Blaze/Bazel) instead let engineers declare *what* to build and leave *how* entirely to the system, which is what makes reliable parallelism, incremental builds, and distributed/remote execution possible.

## Frameworks Introduced
- **Artifact-based build systems (functional-programming analogy)**: buildfiles are a declarative manifest of artifacts and dependencies, not an imperative script.
  - When to use: any project beyond trivial single-file scope, and ideally from day one — "changes to a project's build system can be expensive, and that cost increases as the project becomes larger."
  - How: define targets (e.g., `java_binary`, `java_library`) with explicit `srcs` and `deps`; let the build tool compute the dependency graph and decide execution order/parallelism itself, the same way a functional language lets the compiler decide evaluation strategy.
- **The 1:1:1 Rule** (Pants' term for Bazel-style fine-grained modules): one BUILD file, one target, one package per directory (for languages with strong native packaging like Java).
  - When to use: structuring any new artifact-based build.
  - How: favor many small targets over one large one — trades some BUILD-file maintenance overhead for parallelism, caching granularity, and finer-grained test selection; Google tooling automates much of that overhead away.
- **Strict transitive dependency enforcement**: a target must explicitly declare every dependency it directly uses; it cannot rely on symbols pulled in transitively through another dependency.
  - When to use: any codebase expecting to scale past a handful of engineers.
  - How: have the build tool detect undeclared-but-used symbols and fail with an auto-fix command (Blaze's approach); accept the one-time verbosity cost to prevent dependency accumulation from silently slowing builds over time.
- **One-Version Rule (build-system instance)**: no two versions of the same external/third-party dependency may coexist in the workspace.
  - When to use: same rationale as Ch. 16's VCS-level rule, applied specifically to external artifact versions.
  - How: require a single, manually-updated, explicitly-versioned global manifest (Bazel's WORKSPACE file) rather than automatic "latest" or recursive transitive-dependency resolution.

## Key Concepts
- **Task-based build system**: fundamental unit of work is an arbitrary script ("task") with declared task dependencies (Ant, Maven, Gradle, Grunt, Rake).
- **Artifact-based build system**: fundamental unit is a declared artifact built by a small, fixed set of system-defined rules (Blaze, Bazel, Pants, Buck).
- **Action**: the lowest-level composable unit in Bazel — declares its own inputs/outputs, runs one executable or writes one file; Bazel schedules and caches at this level.
- **Sandboxing**: filesystem isolation (via LXC on Linux, the same tech underlying Docker) that prevents one action from reading undeclared inputs or leaking undeclared outputs, making action conflicts structurally impossible.
- **Toolchain**: a declared set of tools + properties for building a target type on a specific host/target platform, letting targets depend on a toolchain *type* rather than a specific tool location.
- **Remote caching**: a shared cache service (e.g., Redis, GCS) keyed on target + input hash; if an artifact already exists there, download instead of rebuild.
- **Remote execution**: a build master schedules individual actions across a distributed worker pool, reading/writing shared cache — true distributed compute, not just artifact reuse.
- **Diamond dependency problem**: target A depends on target B and directly on library v1; B is later changed to depend on library v2; A now implicitly needs both versions simultaneously — the concrete failure mode the One-Version Rule prevents.
- **Vendoring**: checking third-party dependencies directly into source control (converting external deps into internal ones) — Google's `third_party` directory approach, viable because Piper is custom-built for monorepo scale.

## Mental Models
- Think of task-based vs. artifact-based build systems as imperative vs. functional programming: imperative (task-based) systems specify *steps*; functional-style (artifact-based) systems specify *what a computation produces* and leave execution strategy to the system, enabling safe parallelization and reuse the same way pure functional languages do.
- Treat a build target's dependency list as part of its public contract once strict transitive dependencies are enforced — removing an unnecessary dependency becomes safe, since nothing downstream could have been silently relying on it.
- Treat tools themselves as just another declared dependency (Bazel: every `java_library` implicitly depends on a Java compiler target) — this is what makes builds reproducible across machines without manual environment setup.
- When evaluating whether to vendor, cache remotely, or fetch on-demand: manual, explicit, hash-verified versioning trades convenience for reproducibility and security — the trade-off tips toward manual/explicit as team size and project lifetime grow.

## Anti-patterns
- **DIY shell-script build automation**: works until a hard-drive crash, a new hire's environment, or a stale dependency forces you to reconstruct undocumented state by hand — the chapter's extended "disaster" scenario walkthrough.
- **Task-based systems relying on arbitrary scripts**: the system can't know whether two independent-looking tasks are safe to run in parallel (they might share an untracked resource), so it must either risk rare, hard-to-debug conflicts or serialize the entire build on one thread.
- **Unreliable incremental builds**: because tasks can do literally anything (download a file, write a timestamp), the system generally can't safely determine "has this actually changed," so many task-based setups end up rerunning everything or requiring habitual `clean` before every build — defeating the purpose of incrementality.
- **Automatically-managed ("latest"/range) external dependency versions**: convenient for small projects, "a recipe for disaster" beyond that — a working build can break with no code change and no easy rollback path.
- **Automatic recursive transitive external dependency resolution** (Maven/Gradle-style): convenient, but necessarily violates One-Version — two libraries can pull in conflicting versions of a shared transitive dependency with no way to control which "wins."
- **Coarse single-module builds**: a single BUILD file over the whole project means every build is all-or-nothing — no parallelism, no caching granularity, no incremental rebuild benefit.

## Code Examples
```xml
<!-- Ant buildfile (task-based) -->
<project name="MyProject" default="dist" basedir=".">
  <target name="init"><mkdir dir="${build}"/></target>
  <target name="compile" depends="init">
    <javac srcdir="${src}" destdir="${build}"/>
  </target>
  <target name="dist" depends="compile">
    <jar jarfile="${dist}/lib/MyProject-${DSTAMP}.jar" basedir="${build}"/>
  </target>
</project>
```
- **What it demonstrates**: task-based buildfiles are an imperative sequence of named tasks (`<target>`) each depending on others via `depends`; running `ant dist` walks the dependency chain and executes each task's commands in order.

```python
# Bazel BUILD file (artifact-based)
java_binary(
    name = "MyBinary",
    srcs = ["MyBinary.java"],
    deps = [":mylib"],
)
java_library(
    name = "mylib",
    srcs = ["MyLibrary.java", "MyHelper.java"],
    visibility = ["//java/com/example/myproduct:__subpackages__"],
    deps = [
        "//java/com/example/common",
        "//java/com/example/myproduct/otherlib",
        "@com_google_common_guava_guava//jar",
    ],
)
```
- **What it demonstrates**: declarative target definitions (`java_binary`, `java_library`) with explicit `srcs`/`deps`/`visibility`; Bazel — not the engineer — decides build order, parallelism, and what can be safely cached or skipped on `bazel build :MyBinary`.

## Reference Tables

| Property | Task-based (Ant, Maven, Gradle) | Artifact-based (Blaze/Bazel) |
|---|---|---|
| Fundamental unit | Task (arbitrary script) | Artifact (declared target) |
| Who controls "how" | Engineer | Build system |
| Parallelism safety | Unreliable — system can't verify isolation | Safe by construction (declared inputs/outputs) |
| Incremental builds | Difficult — system can't verify staleness | Reliable — functional-style input hashing |
| Distributed/remote execution | Effectively impossible to build reliably | Natural extension (Forge/remote execution) |
| Extensibility | Full scripting freedom | Constrained: custom rules with declared inputs/outputs |

| Distributed build tier | What it provides | Google's implementation |
|---|---|---|
| Remote caching | Download instead of rebuild if a matching artifact exists | ObjFS (Bigtable-backed) + objfsd FUSE daemon |
| Remote execution | Actions distributed across a worker pool | Forge (Distributor → Scheduler → Executor pool) |

## Worked Example
**Why Bazel can safely skip work.** After `bazel build :MyBinary` completes once, running the identical command again exits in under a second reporting "up to date." This is possible only because of the functional-programming guarantee: Bazel knows each target's output is a pure function of (a) its declared source inputs and (b) its declared tool dependencies (e.g., the Java compiler). If `MyBinary.java` changes, Bazel rebuilds `MyBinary` but reuses the cached `mylib` artifact untouched. If a source file inside `//java/com/example/common` changes, Bazel rebuilds that library, then `mylib` (which depends on it), then `MyBinary` — but leaves `//java/com/example/myproduct/otherlib` alone, since nothing in its input hash changed. A task-based system generally cannot make this guarantee, because a task might have done something nondeterministic (downloaded a file, written a timestamp) that the system has no visibility into — so it must conservatively rerun everything to stay correct.

## Key Takeaways
1. Adopt an artifact-based build system (Bazel or similar) from the start of a project — retrofitting one onto a large existing task-based build is expensive.
2. Prefer many fine-grained targets over few coarse ones; the BUILD-file maintenance overhead is offset by parallelism, caching, and precise incremental test selection, and can largely be automated.
3. Enforce strict transitive dependencies and a One-Version Rule for external dependencies — both trade a one-time verbosity/discipline cost for long-term build speed and stability.
4. Never rely on automatically-resolved "latest" or ranged external dependency versions past small-project scale; require explicit, hash-verified, manually-updated versions.
5. Treat build tools themselves as declared dependencies (not assumed-present system state) so builds are reproducible across machines and bootstrapping workers for remote execution.
6. Mirror or vendor third-party dependencies you rely on, rather than trusting an external repository's availability and integrity indefinitely.

## Connects To
- **Ch 16 (Version Control and Branch Management)**: the One-Version Rule appears in both chapters — Ch. 16 frames it as VCS/dependency policy, this chapter shows its build-system enforcement mechanism (explicit hashed external-dependency manifests, strict transitive deps).
- **Ch 21 (Dependency Management)**: this chapter explicitly defers deeper treatment of diamond dependencies and the One-Version Rule "in the context of a large monorepo" to Chapter 21.
- **Ch 22 (Large-Scale Changes)**: the multiyear rollout of strict transitive dependency enforcement across "millions of build targets" is cited as exactly the kind of effort covered in the LSC chapter.
- **Ch 23 (Continuous Integration)**: automated, machine-triggered builds (the majority of Google's builds) depend on the reproducibility guarantees an artifact-based system provides.
