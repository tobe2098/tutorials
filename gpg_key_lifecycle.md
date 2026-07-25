## What is a GPG Key?

**GPG (GNU Privacy Guard)** is a free, open-source implementation of the OpenPGP standard. At its core, GPG relies on **asymmetric cryptography** (public-key cryptography), which uses a mathematically linked pair of keys:

* **Public Key:** The key you share with the world. Anyone can use it to encrypt a message intended *only* for you, or to verify that a signature came from you.
* **Private (Secret) Key:** The key you keep strictly to yourself, protected by a passphrase. You use it to decrypt messages sent to you or to digitally sign files and commits.

Think of your public key as a open padlock that anyone can snap onto a box containing secret data. Once closed, only your private key can unlock it.

---

## Key Use Cases: What is GPG Used For?

GPG solves two main problems on the internet: **confidentiality** (keeping secrets secret) and **authenticity** (proving you are who you say you are).

### 1. Signing Git Commits

When working on platforms like GitHub or GitLab, anyone can forge a Git commit name and email. Signing commits with a GPG key attaches a cryptographic signature to your code, awarding you that coveted **"Verified"** badge.

### 2. File and Message Encryption

Encrypt sensitive files, passwords, or communications before sending them over insecure networks like email or cloud storage.

### 3. Software Package & Release Verification

Linux distributions (like Debian, Ubuntu, Arch) and open-source developers sign release packages with GPG keys. When you download software, your package manager verifies the signature against the developer’s public key to ensure the file wasn't tampered with by a middleman.

### 4. Encrypted Email (PGP/MIME)

Using desktop clients like Thunderbird (with built-in OpenPGP support), you can end-to-end encrypt emails so not even your email provider can read them.

---

## Practical Guide: How to Use GPG

### Step 1: Install GPG

GPG is pre-installed on almost all Linux distributions and macOS (via Xcode tools or Homebrew).

* **macOS:** `brew install gnupg`
* **Debian/Ubuntu:** `sudo apt install gnupg`
* **Fedora/RHEL:** `sudo dnf install gnupg2`
* **Windows:** Install [Gpg4win](https://www.gpg4win.org/).

Verify your installation:

```bash
gpg --version

```

---

### Step 2: Generate Your Keypair

To generate a new key pair, run:

```bash
gpg --full-generate-key

```

Follow the prompts:

1. **Algorithm:** Choose `(1) RSA and RSA` or `(9) ECC (Ed25519)`. *ECC (Ed25519) is modern, fast, and highly secure. RSA 4096-bit is the classic choice.*
2. **Key Size (if using RSA):** Enter `4096`.
3. **Expiration:** Set an expiration date (e.g., `2y` for 2 years). You can always extend it later.
4. **User Details:** Enter your Real Name and Email Address (matching your Git/work email).
5. **Passphrase:** Choose a strong passphrase to encrypt your private key on disk.

---

### Step 3: Managing Your Keys

#### List Existing Keys

To see your public keys:

```bash
gpg --list-keys

```

To see your private keys:

```bash
gpg --list-secret-keys --keyid-format=long

```

Your key ID is the long hexadecimal string listed next to `sec` or `rsa4096/` (e.g., `3AA5C34371567BD2`).

#### Exporting Your Public Key

To let others encrypt files for you or verify your signatures, export your public key in text format (ASCII-armored):

```bash
gpg --armor --export YOUR_KEY_ID > publickey.asc

```

#### Importing Someone Else’s Public Key

When a colleague sends you their public key:

```bash
gpg --import recipient_key.asc

```

---

### Step 4: Encrypting and Decrypting Files

#### Encrypting a File

To encrypt a file for a specific recipient (using their public key):

```bash
gpg --encrypt --recipient recipient@example.com secret_file.txt

```

*This produces `secret_file.txt.gpg`.*

#### Decrypting a File

To decrypt a file sent to you using your private key:

```bash
gpg --decrypt secret_file.txt.gpg > decrypted_file.txt

```

---

### Step 5: Signing and Verifying Files

#### Create a Detached Signature

If you want to distribute a file (like an installer) and allow users to prove it hasn't been altered:

```bash
gpg --armor --detach-sign release.zip

```

*This generates `release.zip.asc`.*

#### Verify a Signature

To verify that `release.zip` matches its signature:

```bash
gpg --verify release.zip.asc release.zip

```

---

### Step 6: Configuring Git to Use GPG

To get that **"Verified"** badge on GitHub or GitLab:

1. Copy your long key ID from `gpg --list-secret-keys --keyid-format=long`.
2. Print your ASCII-armored public key:
```bash
gpg --armor --export YOUR_KEY_ID

```


3. Copy the output (including `-----BEGIN PGP PUBLIC KEY BLOCK-----`) and paste it into **GitHub Settings > SSH and GPG keys**.
4. Configure local Git:
```bash
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

```



Now, every `git commit` will prompt for your GPG passphrase and digitally sign your work.

---

## Best Practices & Security Checklist

> ⚠️ **Critical Rule:** Never share your private key or passphrase with anyone. If your private key is compromised, your digital identity with GPG is compromised.

| Practice | Why it matters | Command / Action |
| --- | --- | --- |
| **Generate a Revocation Cert** | Allows you to invalidate your key if you lose your private key or forget your passphrase. | `gpg --output revoke.asc --gen-revoke YOUR_KEY_ID` |
| **Set an Expiration Date** | Forces key rotation and limits damages if a key is abandoned or lost. | Set during key creation or edit via `gpg --edit-key` |
| **Backup Private Keys** | Store an encrypted backup of your private key on an offline USB drive. | `gpg --armor --export-secret-keys YOUR_KEY_ID > private.asc` |
| **Use Subkeys** | Advanced: Keep your master key offline and use subkeys for day-to-day signing/encryption. | Configured via `gpg --edit-key` |
