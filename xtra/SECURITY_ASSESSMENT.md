
# Security Assessment: Workstation Bootstrap Architecture

## 1. Executive Summary

The workstation provisioning process ("Bootstrap") utilizes a **Split-Brain Architecture** to decouple public orchestration logic from sensitive configuration data. This design eliminates "Secret Sprawl" by ensuring no credentials, internal infrastructure identifiers, or private configuration logic exist within the version control system (VCS).

Trust is established via a high-integrity, ephemeral runtime environment that relies on cryptographic verification and strictly scoped access controls (Least Privilege) to deliver secrets from a secure vault to the target machine.

## 2. Architectural Components

The system is composed of three distinct security domains:

1.  **The Public Domain (VCS / GitHub):**
    * Contains the Orchestrator (`newcomp.sh`).
    * **Status:** "Opaque." Contains no hardcoded vault names, item titles, or secrets. It operates solely on variables loaded from a local, git-ignored configuration file.
    
2.  **The Private Domain (1Password Vaults):**
    * Contains the Logic (`sys_script_restore`) and the Data (`Dotfiles-Secrets-Bundle`).
    * **Status:** Encrypted at rest. Accessed only via authenticated API calls.

3.  **The Ephemeral Runtime (Target Machine):**
    * The temporary environment where public and private components meet.
    * **Status:** Volatile. Sensitive artifacts exist in memory or strictly controlled temporary paths only for the duration of the execution.

## 3. Implemented Security Controls

### 3.1. Integrity Locking (Cryptographic Chain of Trust)
To mitigate "Supply Chain" attacks where the storage provider (1Password) or the private script itself is compromised:
* **Mechanism:** The public orchestrator enforces a hardcoded SHA256 integrity check on the private payload.
* **Effect:** `newcomp.sh` downloads the private restore logic but calculates its hash before execution. If the downloaded artifact does not match the expected fingerprint defined in `restore_script.sha256`, execution aborts immediately. This prevents the execution of tampered or malicious code.

### 3.2. Least Privilege Access (RBAC)
To mitigate the impact of a compromised Service Account Token:
* **Mechanism:** The bootstrap process utilizes a dedicated **Read-Only Service Account**.
* **Scope:**
    * `Read`: Allowed for specific configuration vaults (`work-dev`, `work-aws`).
    * `Write/Delete/Edit`: Explicitly Denied.
* **Effect:** A stolen token allows an attacker to download configuration data (Information Disclosure) but prevents them from modifying scripts, overwriting secrets, or destroying backups (Integrity/Availability impact is negated).

### 3.3. Ephemeral State & Memory Hygiene
To mitigate local credential theft during or after execution:
* **Mechanism:** The system utilizes strict `trap` signals on `EXIT`, `INT` (Ctrl+C), and `TERM`.
* **Effect:**
    * **Token Sanitation:** The `OP_SERVICE_ACCOUNT_TOKEN` environment variable is unset immediately upon script termination.
    * **Artifact Cleanup:** Temporary scripts downloaded to `/tmp` are securely removed (using `rm -P` for overwriting where supported) to prevent recovery from disk.

### 3.4. Logic Isolation (Air-Gap)
To mitigate "Confused Deputy" attacks:
* **Mechanism:** The private restore script (`restore_secrets_from_1p.sh`) is isolated from the authentication layer. It delegates authentication to the parent process and strictly enforces vault paths.
* **Effect:** The script does not contain logic to prompt for credentials or search broad scopes (e.g., "All Vaults"). It operates only if a valid session is provided by the orchestrator, and it refuses to retrieve payloads from unverified vaults.

## 4. Threat Model Analysis

| Threat Scenario | Mitigation Strategy | Residual Risk |
| :--- | :--- | :--- |
| **Accidental Commit** | No secrets or internal names are hardcoded. Vault names are loaded from `bootstrap.conf` (git-ignored). | Low (User error in `.gitignore`) |
| **Compromised GitHub Repo** | Attacker modifies `newcomp.sh` to steal token. Token is Read-Only; attacker cannot inject malware into the vault for other users. | Medium (Info Disclosure only) |
| **Compromised 1Password Vault** | Attacker modifies the private script (`sys_script_restore`). SHA256 Checksum failure in `newcomp.sh` prevents execution. | Low |
| **Stolen Laptop (Post-Provisioning)** | Secrets are on disk (necessary for work). `newcomp.sh` artifacts and tokens are already wiped by the `trap` function. | Standard Endpoint Risk |

## 5. Conclusion

This architecture represents a mature "Infrastructure as Code" approach to workstation provisioning. By strictly enforcing **Integrity Verification** and **Least Privilege**, the system maintains a high security posture without sacrificing developer velocity. It successfully decouples the *delivery mechanism* from the *sensitive payload*, allowing the public repository to remain open while the organization's identity remains strictly private.