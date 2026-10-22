# Chapter 25: Compute as a Service

## Core Idea
As an organization scales, managing individual machines ("pets") stops working; the only sustainable path is treating compute units as anonymous, disposable, automatically-replaceable "cattle" — which requires both a centralized scheduling/isolation service (Borg-like CaaS) and a fundamental change in how engineers architect software (stateless, failure-tolerant, cattle-compatible).

## Frameworks Introduced
- **Pets vs. Cattle** (attributed to Bill Baker via Randy Bias): a pet server is nursed back to health by a human when it breaks and is hard to replace; cattle are numbered, automatically replaced on failure, requiring no manual setup.
  - When to use: as the litmus test for whether your architecture will scale — pet-based maintenance burden grows linearly/superlinearly with fleet size; cattle-based systems self-heal.
  - How: make instance creation fully automatable (no manual SSH/config), design work to be resumable/re-assignable in small chunks, externalize all state that must survive an instance's death.
- **Borg's Evolution Path**: manual SFTP/SSH → simple automation (scripted deploy, health-check-and-restart) → automated scheduling (a central service assigns machines on demand) → containerization/multitenancy (bin-pack many jobs per machine with resource isolation) → rightsizing/autoscaling (automate the resource-request numbers themselves).
  - When to use: as a maturity model for evaluating where your own compute environment sits and what the next automation investment should be.
- **Unified Compute Pool** ("One Service to Rule Them All"): merge batch and serving workload scheduling into a single pool (Borg, 2003) rather than separate per-team/per-workload-type clusters.
  - When to use: when your organization has both latency-sensitive serving jobs (which must be overprovisioned for spike/outage headroom) and throughput-oriented batch jobs (which can tolerate being killed/paused).
  - How: let batch jobs opportunistically consume serving jobs' overprovisioned slack capacity, with the policy that serving jobs reclaim resources on demand (freeze batch for CPU contention, kill for RAM contention) — in Google's experience this makes batch effectively free.

## Key Concepts
- **Multitenancy**: multiple jobs sharing a machine's resources, requiring a scheduler to bin-pack based on declared CPU/RAM/disk requirements and a runtime isolation mechanism to prevent noisy-neighbor interference.
- **Containers** (cgroups + chroot/bind-mounts/overlay filesystems): Google's chosen lightweight isolation mechanism over VMs, adopted in 2003 specifically because VMs' full-OS boot overhead and startup latency were unacceptable for short-lived batch jobs.
- **Rightsizing/autoscaling**: automating the resource-request numbers (CPU/RAM) a human would otherwise have to guess and maintain over a service's lifetime — Google only recently crossed 50% of Borg fleet resource usage under automated rightsizing.
- **Batch jobs vs. serving jobs**: batch optimizes for aggregate throughput, is short-lived, and tolerates being killed and resumed elsewhere; serving jobs optimize for per-request latency, run indefinitely, and need graceful-drain semantics (Borg signals intent to reschedule so a container can stop accepting new requests before termination).
- **Service discovery**: an indirection layer resolving a durable service identifier to the current physical location of "cattle" backend instances, avoiding hardcoded hostnames — paired with load balancing.
- **Idempotency / client-assigned identifiers**: the property that repeating a mutating request has the same effect as issuing it once, achieved by having the client supply a request/order ID the server can deduplicate against — necessary because cattle-based retries make duplicate delivery routine.
- **Serverless (FaaS/PaaS)**: an even higher abstraction layer where teams write only request handlers; the framework server itself becomes multitenant and dynamically loads/unloads handler code — requires code to be truly stateless (no local state surviving across requests).

## Mental Models
- Treat local/in-process state as inherently transient under a cattle model — anything that must survive an instance's replacement belongs in external, replicated durable storage (Google built GFS, Bigtable, Spanner specifically to make "all state is transient locally" viable for applications).
- Provision your cache for latency goals but your core application for total load — this way losing the entire cache layer degrades latency but never causes an outage, because the non-cached path was already sized to handle 100% of traffic.
- View a compute architecture choice as a high-lock-in decision precisely because of Hyrum's Law: engineers will inevitably depend on implementation quirks of whatever system you pick (the Borg PID-space and Bash-vs-ash examples), so switching later is far more expensive than the nominal API surface suggests.
- Compare serverless not against "VMs as pets" (an unfairly easy win) but against a mature persistent-container/cattle architecture (Borg/Kubernetes) — against that baseline, serverless mainly buys more aggressive scale-to-zero at the cost of statelessness and reduced control, which matters most for smaller teams/orgs that can't otherwise amortize a shared cluster.

## Anti-patterns
- **Treating compute resources like a scarce budget item requiring approval friction**: unlike office supplies, engineer time dwarfs compute cost — a thousand core-hours rarely costs more than a fraction of a day of engineering time, so gate one-off usage with generous/near-unlimited low-priority quotas rather than a heavyweight approval process (mirrors the book's earlier "markers" analogy).
- **Hardcoding hostnames or manually configured machine lists**: breaks the cattle model outright and reintroduces the "pets" maintenance burden; requires a service-discovery indirection layer instead.
- **Ignoring implicit dependencies on container/scheduler internals**: e.g. teams silently depending on Borg's 32,000 PID limit (log records assumed 5-digit PIDs) turned an implementation detail into a de facto API guarantee — Hyrum's Law applies "even more than usual" to infrastructure abstractions because users don't perceive themselves as consuming an API at all.
- **Expanding a shared compute platform's API surface ad hoc to accommodate one customization request at a time**: Borg's post-2012 API became "large and unwieldy" from accreted special-casing (Cloud VM live-migration needs, Search's local-disk-failure tolerance), making behavior intersections untestable and unpredictable — requires deliberate whitelisting/cleanup discipline to contain.
- **Choosing a compute service without weighing lock-in**: both the explicit API and Hyrum's-Law-driven implicit dependencies make migrating off a chosen architecture expensive later; mitigations include using an open-source-based managed offering, layering your own abstraction on top of a lower-level cloud primitive, or deliberately running multicloud/hybrid-cloud to force portability discipline.

## Reference Tables

| Job type | Optimizes for | Lifespan | Failure tolerance | Startup time |
|---|---|---|---|---|
| Batch | Aggregate throughput | Minutes to hours | High — kill/resume is cheap, only lose one chunk of work | Fast |
| Serving | Per-request latency | Indefinite (until new release) | Low — needs graceful drain, warning before eviction | Slower (state/cache warm-up) |

| Abstraction level | Example offerings | Key trade-off |
|---|---|---|
| Bare metal / colocation | Owned machines, rented colo space | Full control, full management burden ("pets" by default) |
| VMs (IaaS) | GCE, Amazon EC2 | Bring-your-own-OS flexibility; can be pets or cattle depending on usage |
| Managed containers | Borg, Kubernetes (GKE/AKS) | Lightweight, resource-efficient cattle; requires stateless-by-design apps |
| Serverless (FaaS/PaaS) | AWS Lambda, Cloud Functions, Knative | Scale-to-zero, least management overhead, but requires true statelessness and loses environment control |

## Worked Example
**Borg's 2011 process-ID exhaustion incident**, illustrating Hyrum's Law inside a container abstraction:
1. Linux processes on Borg were assigned PIDs in the range [0, PID_MAX-1], with PID_MAX defaulting to 32,000 — seemingly a trivial, raisable configuration constant.
2. Over time, downstream systems silently came to depend on PIDs always fitting in 5 digits — e.g., log storage processes that encoded the PID into fixed-width record names broke outright when 6-digit PIDs appeared.
3. Simply raising PID_MAX was therefore not "problem solved" — it would have broken those log-record-naming assumptions immediately.
4. The actual fix took multiple phases over multiple years: (1) cap the number of PIDs a single container could consume, so one thread-leaking job couldn't exhaust the whole machine's PID space; (2) split the PID space for threads vs. processes, since almost no one depended on the 32,000 limit for thread IDs specifically, allowing that limit alone to be raised; (3) (planned) introduce per-container PID namespaces — which then predictably surfaced a *new* Hyrum's Law dependency, because many systems had come to assume the triple {hostname, timestamp, pid} uniquely identified a process, an assumption PID namespaces would break.
5. As of the book's writing, identifying and fixing every place relying on that assumption was still an ongoing effort eight years after the initial incident.

Lesson: the point isn't "always use PID namespaces" — Borg's 2003 designers couldn't have anticipated this. It's that any container abstraction accumulates unplanned-for implicit dependencies over time, which is a strong argument for using a widely-adopted community container system (where such lessons are already baked in) rather than a bespoke one.

## Key Takeaways
1. Automate machine/toil management incrementally — script deployment, then health-check-triggered restart, then centralized scheduling, then multitenant bin-packing, then automated resource-sizing — each stage removes a specific class of manual, error-prone human intervention.
2. Architect software for the cattle model explicitly: chunk work into small, dynamically-reassignable units; treat all local state as transient; externalize durable state to replicated storage systems; use service discovery instead of hardcoded addresses; and design mutating APIs to be idempotent, because cattle-based retries make duplicate requests routine.
3. Batch and serving workloads are complementary at the resource level — a unified scheduler lets batch jobs consume serving jobs' overprovisioned slack capacity essentially for free, while serving jobs get failure-resistant headroom they're already paying for.
4. Compute-service choice carries very high lock-in risk, driven as much by Hyrum's-Law-style implicit dependencies as by the explicit API — weigh centralization-for-efficiency against the inevitable need for some workload-specific customization (Cloud VM live migration, Search's disk-failure tolerance) before committing.
5. Serverless is a genuine leap only when compared honestly against a mature cattle-based container platform, not against "VMs as pets" — it wins mainly on scale-to-zero cost and reduced management overhead for teams that can't otherwise amortize a shared cluster, at the cost of requiring true statelessness and less environmental control.
6. Compute resources should be governed like engineering-time trade-offs, not like scarce physical goods — the cost of over-restricting one-off engineer compute usage usually exceeds the cost of the wasted compute itself, but accidental overconsumption (a forgotten load test, a runaway debug session) still needs a quota safety net.

## Connects To
- **Ch 3 (Knowledge Sharing)**: warns against depending on documentation/tribal knowledge for service configuration — reinforces using a standardized configuration language instead.
- **Ch 22 (Large-Scale Changes)**: the "cattle, not pets" metaphor is explicitly noted as applicable beyond servers to LSC shard management.
- **Ch 24 (Continuous Delivery)**: a standardized configuration language is called out as a requirement for CD automation.
- **Hyrum's Law**: the chapter's recurring theoretical explanation for why container/scheduler internals (PID limits, shell wrapper choice) become de facto unbreakable APIs.
- **Site Reliability Engineering (O'Reilly)**: cited directly for retry/backoff/jitter/cascading-failure best practices needed to make idempotent retries safe in a cattle environment.
