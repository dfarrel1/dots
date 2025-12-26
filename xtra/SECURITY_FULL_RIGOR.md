# Security Policy & Cryptographic Standards

This document outlines the lifecycle management, access controls, and hygiene standards required for the maintenance of this repository and the associated workstation environment.

## 1. Cryptographic Material Hygiene

To prevent unauthorized usage of identity assets in the event of local data exfiltration, strict "At-Rest" encryption is enforced for all private keys.

### 1.1. Passphrase Protection
* **Requirement:** All Private Keys (SSH, GPG) must be encrypted with a strong, high-entropy passphrase. Storing keys in plaintext (passwordless) is strictly prohibited.
* **Operational Integration:**
    * Passphrases should be stored in the System Keychain (macOS) or a secure Agent to ensure seamless automation without compromising security.
    * **Verification:** Any key triggering a "passwordless" login event is considered non-compliant and must be immediately rotated or locked.

### 1.2. Key Rotation Schedule
Cryptographic identity limits the "Blast Radius" of a potential compromise by enforcing regular expiration.

* **Routine Rotation:** SSH and GPG keys are rotated on an **Annual Basis**.
* **Event-Driven Rotation:** Keys must be immediately rotated and revoked under the following conditions:
    * Loss or theft of a physical device.
    * Accidental commitment of a private key to a public repository.
    * Departure from the organization.
* **Mechanism:** Rotation is performed by generating new keys locally, updating the `Dotfiles-Secrets-Bundle` via the maintenance script, and removing public keys from downstream services (GitHub, AWS).

## 2. Service Account Lifecycle (1Password)

The `New Computer Bootstrap` token is classified as a **Just-In-Time (JIT) Provisioning Credential**, not a persistent application secret.

### 2.1. Ephemeral Existence
* **Creation:** A Service Account Token is generated *only* at the moment of provisioning a new device.
* **Scope:** The token is strictly scoped to **Read-Only** access on the specific Vaults required for bootstrapping (`work-dev`, `work-aws`).
* **Revocation:** Upon the successful completion of the bootstrap process (`newcomp.sh`), the Service Account is effectively decommissioned. The token is deleted or revoked to close the access window.

### 2.2. Zero-Trust Fallback
* In environments requiring elevated security (or where JIT tokens are unavailable), automation tokens are bypassed in favor of **Interactive Biometric Authentication**.
* The bootstrap orchestrator supports this by defaulting to `op signin` (Human Interaction) if no environment token is provided.

## 3. Reference Procedures

### Updating Key Passphrases (Non-Destructive)
To bring existing keys into compliance without rotating the fingerprint:

```bash
# SSH Keys
ssh-keygen -p -f ~/.ssh/id_rsa
ssh-keygen -p -f ~/.ssh/id_ed25519

# GPG Keys
gpg --edit-key <KEY_ID>
# command: passwd
# command: save
```

### Rotating Keys (Destructive)
1. **Generate:** `ssh-keygen -t ed25519 -C "new-key-202X"`

2. **Sync:** Run `./xtra/private/push_secrets_to_1pass.sh` to update the Bundle.

3. **Deploy:** Upload the new .pub key to GitHub/AWS.

4. **Revoke:** Delete the old public key from the provider.