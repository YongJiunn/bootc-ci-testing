# Trivy Waiver Documentation

This document outlines the Trivy waivers required for the deployment of CentOS Stream 9 (CS9).

> Only those that are flagged out as "High" in the [trivy report](./trivy-report.txt) will be highlighted here.

# Deployment

This waiver documentation is applicable for all variants of CS9 OS deployed as a BootC VM.

# Benchmark Verification

The tool [`trivy`](https://github.com/aquasecurity/trivy) is used to scan vulnerability and generate the `trivy-report.txt`.

## Waiver: CVE-2025-58183 (golang: archive/tar: Unbounded allocation when parsing GNU sparse map)

[CVE-2025-58183 – Red Hat Security Advisory](https://access.redhat.com/security/cve/CVE-2025-58183)

### Description

A flaw exists in Go’s ```archive/tar``` package where ```tar.Reader``` does not enforce a maximum number of sparse data regions when parsing **GNU tar pax 1.0** sparse files.
A specially crafted tar archive could cause a Go application to allocate excessive memory, leading to **out-of-memory denial of service**, but only if the application actively processes attacker-controlled tar files using Go’s ```archive/tar``` package.

### Proposal

This vulnerability is **not exploitable** in our BootC image due to the following:

- **The system does not run any Go application code** and no service installed via ```build_scripts/``` uses Go’s ```archive/tar``` package.

- **No component in the image processes tar files**.

- **Node Exporter**, the only Go-based binary included, does not handle file uploads, archives, or any user-controlled file parsing.

- Exploitation requires the system to **actively parse attacker-crafted GNU tar archives** using Go’s standard library — a scenario that does not occur anywhere in this deployment.

- OSTree immutability and hardened configuration eliminate paths for executing arbitrary Go parsing workloads.

Based on these conditions, the presence of the vulnerable library is a passive, unused code path, not an actual exposure.

### Risk Conclusion

The vulnerable function cannot be triggered because:

- No Go workloads run on the system.

- No tar archives are accepted or processed.

- No attacker-controlled data reaches any Go parsing library.

Thus, while the CVE is present in the underlying Golang runtime shipped by CentOS Stream 9, it is **not reachable, not exploitable**, and therefore represents **no practical risk** to system.

Residual risk is **negligible.**

### Recommendation

Approve waiver.
Continue to consume upstream OSTree updates as they become available, but no mitigation or configuration changes are required for safe production deployment.

## Waiver: CVE-2025-58186 (golang: net/http — Unbounded memory allocation via excessive cookies)

[CVE-2025-58186](https://www.tenable.com/cve/CVE-2025-58186)

### Description

A vulnerability exists in Go’s ```net/http``` package where HTTP header parsing enforces a 1MB size limit, but **the number of individual cookies is not limited.**
An attacker can send a large number of tiny cookies (e.g., ```a=; b=; c=; ...```) which forces a Go HTTP server using the standard ```net/http``` parser to allocate memory for each cookie.
This can trigger excessive memory consumption and potentially lead to a **denial of service through memory exhaustion.**

### Proposal - False Positive

This vulnerability does **not apply** to our BootC hardened image for the following reasons:

- **There is no Go-based HTTP server running on the system.**
The only Go binaries present (e.g., node_exporter) do not expose HTTP endpoints that parse attacker-controlled cookies.

- **Node Exporter does not parse cookies or arbitrary HTTP headers.**
Its HTTP endpoint is a simple metrics endpoint (/metrics) meant for Prometheus scraping, which sends no cookies and does not allow clients to influence header parsing.

- **No inbound traffic from untrusted clients is permitted** on this system based on deployment architecture and firewalling.
Even if a Go-based HTTP listener existed, it would not be reachable from attackers.

- **The vulnerable code path requires a Go HTTP server that processes user-supplied HTTP cookies**, which this environment does not run and does not support.

Therefore, the presence of the Go standard library containing ```net/http``` does **not create an exploitable condition** in this image.

### Risk Conclusion

The risk is **theoretical only.**
Exploitation requires:

- A Go HTTP server running on the host
- Accepting requests from attackers
- Parsing untrusted cookies via Go’s net/http parser

None of these conditions occur in this system.
As such, **the vulnerability is not reachable or exploitable**, and the actual security impact to our deployment is **zero.**

Residual risk is **negligible.**

### Recommendation

Approve waiver.
No configuration or code changes are needed. The system remains safe for production.
Monitor upstream OSTree / Golang updates for future remediation.

## Waiver: CVE-2025-58187 (golang: x509 — Non-linear processing time in name constraint validation)

[CVE-2025-58187](https://ubuntu.com/security/CVE-2025-58187)

### Description

A vulnerability exists in Go’s ```crypto/x509``` package where the **name constraint checking algorithm** exhibits **non-linear processing** time for certain specially crafted certificate inputs.
When validating an attacker-controlled certificate chain, the validation time may increase in proportion to certificate size and complexity, potentially resulting in:

- Excessive CPU usage

- Slowdowns or temporary denial of service during certificate validation

This vulnerability affects **software that performs certificate chain validation using Go’s x509 package on untrusted certificate chains.**

### Proposal - False Positive

This finding is **not applicable** to our hardened BootC image based on the following:

- **The system does not perform certificate chain validation on untrusted user-provided certificates.**
Only system-internal TLS is used (e.g., PostgreSQL server certificates, internal CA), and all certificates are controlled and generated internally.

- **No Go application on the image ingests or validates arbitrary external certificates.**
Tools like ```node_exporter``` do not accept client certificates nor validate untrusted certificate chains.

- **Inbound connections from untrusted sources are not permitted**, enforced by network segmentation and firewall rules.
Even if a service were to use x509 validation, attackers cannot deliver malicious certificates to the system.

Therefore, the vulnerability exists in the Go standard library but is not reachable or exploitable within our environment.

### Risk Conclusion

To exploit this issue, an attacker must be able to:

- Provide a malicious certificate chain to the system

- Trigger Go’s x509 name constraint validation code

- Force the system to repeatedly validate arbitrary certificates

None of these conditions occur in this environment, eliminating the attack vector.

Residual risk is **effectively zero.**

### Recommendation

Approve waiver.
No configuration changes or software patches are needed at this time.
Continue monitoring upstream Golang and RHEL OSTree updates for eventual fixes.

## Waiver: CVE-2025-47907 (golang: database/sql — Race condition during Scan after query cancellation)

[CVE-2025-47907 – Red Hat Security Advisory](https://access.redhat.com/security/cve/cve-2025-47907)

### Description

A flaw exists in Go’s ```database/sql``` package where **concurrent query execution combined with query cancellation** can lead to a race condition during the ```Scan``` operation on ```Rows```.

If an attacker can:

- Initiate a query, and
- Cancel it while the application is scanning the result set

the Go SQL driver may return **corrupted or inconsistent data**, potentially impacting application logic.

This vulnerability specifically affects **Go applications** performing concurrent database operations using database/sql.

### Proposal - False Positive

This vulnerability is not applicable to our BootC Postgres image due to the following:

- The only Go-based component present (node_exporter) does not use the affected archive/tar package and does not process TAR files of any kind.

- PostgreSQL itself is written in C, not Go.
Query execution, cancelling, and scanning are entirely handled by the internal database engine and the PostgreSQL wire protocol — none of which call Go code.

- Nothing installed in /build_scripts/ uses Go’s database/sql package.
The system does not run any Go API servers, Go microservices, Go database clients, or Go workers.

- Attack requires the ability to initiate and cancel queries through a Go program. Such a workload does not exist in our deployment architecture

Node Exporter is the only Go binary present, and:

- It does not interface with PostgreSQL

- It does not execute SQL queries

- It cannot be used to trigger scan/cancel race conditions

Thus, the vulnerable code path never executes on this image.

### Risk Conclusion

For this CVE to be exploitable, the following must be true:

- A Go application uses ```database/sql```

- It executes concurrent SQL queries

- It allows cancellation of in-progress queries

- It processes returned ```Rows``` via ```Scan```

- The attacker can drive both query creation and cancellation

Because no Go-based database logic exists and no Go code interacts with Postgres, the vulnerability **is not reachable and cannot be triggered.**

Residual risk is **zero.**

### Recommendation

Approve waiver.
Monitor upstream OSTree and Golang updates for completeness, but no remediation is required for safe production deployment.

## Waiver: CVE-2025-52881 (runc — LSM relabel redirection vulnerability)

[CVE-2025-52881 – Red Hat Security Advisory](https://access.redhat.com/security/cve/cve-2025-52881#cve-details-description)

### Description

A flaw exists in **runc** involving an enhanced variant of the CVE-2019-16884 “LSM label redirection” attack.
In vulnerable environments, a malicious local user may be able to trick ```runc``` into writing Linux Security Module (LSM) labels intended for container processes into **dummy tmpfs files** rather than the correct ```/proc``` entries.

If successful, a container may launch **without proper SELinux/AppArmor confinement**, potentially enabling container breakout.

### Proposal - False Positive

This CVE is not applicable to our BootC image due to the following:

- runc is not installed on the system.

- No containers are created or executed on this host.
The container lifecycle paths required to trigger the vulnerability (runc create, runc run, runc exec) never occur on this machine.

- BootC OSTree makes the system immutable.
The host filesystem cannot be changed post-deployment, preventing introduction of container runtimes or arbitrary processes that could manipulate runc.

- SELinux/AppArmor LSM relabel operations do not occur because container creation does not occur.
The vulnerable logic is dormant and never invoked.

Thus, although the vulnerable package may exist in upstream repositories, it is **not present, not used**, and **not reachable** within our environment.

### Risk Conclusion

To exploit this issue, an attacker must:

- Have local access

- Initiate or manipulate a container start

- Cause runc to misapply LSM labels

- Leverage incorrect labels to escape container confinement

Since **no container runtime or runc exists**, none of these conditions can ever occur.

Therefore, this CVE has **no impact** on the BootC hardened image and is considered a **false positive** relative to our threat model.

Residual risk is **zero.**

### Recommendation

Approve waiver.
Continue monitoring upstream OSTree updates for completeness, but the system is safe for production deployment.
