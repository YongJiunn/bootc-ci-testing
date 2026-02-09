# CIS Benchmark Waiver Documentation

This document outlines the CIS Benchmark waivers required for the deployment of CentOS Stream 9 (CS9).

> Due to the onerous amount of control measures imposed by CIS, only those that are flagged out as "Failed" in the [openscap report](./report.html) will be highlighted here.

# Deployment

This hardening benchmark and waiver documentation is only applicable for a stock CS9 OS deployed as a BootC VM.

# Benchmark Verification

The tool [`openscap`](https://www.open-scap.org/resources/documentation/) is used to scan compliance and generate the `report.html` following the steps outlined [here](../README.md#os-scan). Configuration is benchmarked against `CIS Red Hat Enterprise Linux 9 Benchmark for Level 2 - Server v2.0.0`, dated 2024-06-20

Hardening was done using the [`oscap-im` tool that was created to build hardened bootable images](https://www.mankier.com/8/oscap-im).

> Hardening was originally done using [Ansible Playbooks](https://github.com/ansible-lockdown/RHEL9-CIS/) due to legacy configuration, but migrated off due to the heavy tweaking needed and numerous number of false positives.

# Failed Benchmarks

## CIS 1.6.1 - Ensure system wide crypto policy is not set to legacy

### Description

When a system-wide policy is set up, the default behavior of applications will be to follow the policy. Applications will be unable to use algorithms and protocols that do not meet the policy, unless you explicitly request the application to do so.
The system-wide crypto-policies followed by the crypto core components allow consistently deprecating and disabling algorithms system-wide.
The LEGACY policy ensures maximum compatibility with version 5 of the operating system and earlier; it is less secure due to an increased attack surface. In addition to the DEFAULT level algorithms and protocols, it includes support for the TLS 1.0 and 1.1 protocols. The algorithms DSA, 3DES, and RC4 are allowed, while RSA keys and Diffie-Hellman parameters are accepted if they are at least 1023 bits long.

### Proposal - False Positive

- Due to the implementation of Postgres, FIPS policy is used, which is more strict than CIS' recomendation of `DEFAULT`.
- Audit: `cat /etc/crypto-policies/config` -> should return FIPS.

## CIS 5.1.2 - Ensure permissions on SSH private host key files are configured

### Description

An SSH private key is one of two files used in SSH public key authentication. In this authentication method, the possession of the private key is proof of identity. Only a private key that corresponds to a public key will be able to authenticate successfully. The private keys need to be stored and handled carefully, and no copies of the private key should be distributed.

### Proposal - False Positive

- Openscap is blanket checking for `600` permissions, but there is an alternative configuration of `640`, where owning group is `ssh_keys` (GID 999).
- Audit:  `ls -la /etc/ssh/ssh_host_*_key` -> the owning group is ssh_keys

## CIS 5.4.2.4 - Ensure root account access is controlled

### Description

There are a number of methods to access the root account directly. Without a password set any user would be able to gain access and thus control over the entire system.

> If cannot waiver got a few options
>
> 1. Set random root password per VM and throw the password away -> implications of not having access to the rescue kernel should the need arises.
> 2. Set password and maintain the password -> no good way to manage secrets currently -> high likelihood of losing the password.

### Additional Information

- By default, `root` account does not have a password set, resulting in nobody being able to login as `root`.
- Hardened SSH configuration also prohibits SSH connections as `root` directly.

### Threat Vector

- Malicious actor needs to have physical and credentialed access to the VM, such that they can trigger a system reboot into the GRUB2 bootloader screen, where they can go into the restore kernel to gain root access without authentication.

### Proposal - Waiver

- The risk associated with leaving the root account locked is already mitigated through multiple layers of security. The system has a GRUB2 bootloader password configured (CIS 1.4.1 passed), which prevents attackers from interrupting the boot process or injecting kernel parameters to obtain a root shell. SSH access as root is disabled, ensuring no remote authentication path exists. Console access is strictly controlled through backend MFA and hypervisor-level security, making unauthorized physical access highly unlikely.
- Threat likelihood is minimal.

## CIS 5.4.2.7 - Ensure system accounts do not have a valid login shell

### Description

There are a number of accounts provided with most distributions that are used to manage applications and are not intended to provide an interactive shell. Furthermore, a user may add special accounts that are not intended to provide an interactive shell.

### Additional Information

- [Postgres system account needs to have a shell](https://access.redhat.com/solutions/965383) to run init scripts.

### Proposal - Waiver

- Postgres' shell is completely inaccessible, except for root user, due to the lack of password set for the system user.
- Superusers who are able to run `sudo` to gain access to Postgres' shell would already have greater privileges that `postgres` user.
- Superuser account access is limited to trusted personnel.
- Threat impact and likelihood is minimal.

## CIS 6.1.1 - Ensure AIDE is installed

### Description

Advanced Intrusion Detection Environment (AIDE) is a intrusion detection tool that uses predefined rules to check the integrity of files and directories in the Linux operating system. AIDE has its own database to check the integrity of files and directories.
aide takes a snapshot of files and directories including modification times, permissions, and file hashes which can then be used to compare against the current state of the filesystem to detect modifications to the system.

### Proposal - False Positive

- `report.html` throwing error - "Referenced variable has no values (oval:ssg-variable_aide_operational_database_absolute_path:var:1)".
- Audit: `sudo /usr/sbin/aide --check`
