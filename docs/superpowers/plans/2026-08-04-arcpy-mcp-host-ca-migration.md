# ArcPy MCP Host and CA Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the private ArcPy Codex plugin to `192.168.50.170:8765`, ship the replacement CA, and provide a token-preserving macOS migration workflow that reissues stale artifact download URLs.

**Architecture:** Keep the endpoint explicit in the Codex MCP manifest and the two macOS scripts. Extend the existing configuration script with a separate, idempotent `--refresh-ca` branch that targets old and current certificates by exact fingerprints and never enters the token-storage path. Preserve the existing static pytest style for repository contracts, then validate shell syntax separately.

**Tech Stack:** Codex plugin JSON manifests, Bash 3.2-compatible macOS scripts, macOS `security` and `launchctl`, Python 3.11+ with pytest, PEM X.509 certificates, Git.

---

## File Map

- Create `.gitattributes` to preserve certificate bytes across Windows and macOS checkouts.
- Modify `plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt` to contain the replacement public CA byte-for-byte.
- Modify `plugins/arcpy-mcp/.mcp.json` to register the new fixed MCP URL.
- Modify `plugins/arcpy-mcp/scripts/configure-macos.sh` to use the new health URL and implement CA refresh mode.
- Modify `plugins/arcpy-mcp/scripts/verify-connection.sh` to verify the new health and MCP URLs.
- Modify `plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md` to require new signed URLs after host migration.
- Modify `README.md` to document the new endpoint and the operator migration procedure.
- Modify `tests/test_scripts.py` to pin the replacement CA and migration-script contracts.
- Modify `tests/test_manifests.py` to pin the new MCP and documentation contracts.
- Modify `tests/test_repository.py` to reject the old endpoint in shipped client files.

### Task 1: Replace the Endpoint and CA

**Files:**
- Create: `.gitattributes`
- Modify: `plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt`
- Modify: `plugins/arcpy-mcp/.mcp.json`
- Modify: `plugins/arcpy-mcp/scripts/configure-macos.sh`
- Modify: `plugins/arcpy-mcp/scripts/verify-connection.sh`
- Modify: `README.md`
- Modify: `tests/test_scripts.py`
- Modify: `tests/test_manifests.py`
- Modify: `tests/test_repository.py`

- [ ] **Step 1: Write failing endpoint and CA regression tests**

Replace the imports, module constants, and existing CA test at the top of
`tests/test_scripts.py` with:

```python
import hashlib
from pathlib import Path


ROOT = Path(__file__).parents[1]
PLUGIN = ROOT / "plugins/arcpy-mcp"
CONFIGURE = PLUGIN / "scripts/configure-macos.sh"
VERIFY = PLUGIN / "scripts/verify-connection.sh"
REPLACEMENT_CA_SHA256 = (
    "3d875f739f3200e8cb6e351e0c2c6976d3686de11dd7e915fe069ee8535957cd"
)


def test_ca_asset_contains_only_the_replacement_public_certificate():
    certificate_bytes = (PLUGIN / "assets/arcpy-mcp-ca.crt").read_bytes()
    certificate = certificate_bytes.decode("ascii")

    assert hashlib.sha256(certificate_bytes).hexdigest() == REPLACEMENT_CA_SHA256
    assert certificate.count("BEGIN CERTIFICATE") == 1
    assert certificate.count("END CERTIFICATE") == 1
    assert "PRIVATE KEY" not in certificate
```

Change the expected health and MCP strings in the existing script tests to:

```python
"https://192.168.50.170:8765/healthz"
"https://192.168.50.170:8765/mcp"
```

Change the exact server assertion and README endpoint expectation in
`tests/test_manifests.py` to:

```python
assert server == {
    "type": "http",
    "url": "https://192.168.50.170:8765/mcp",
    "bearer_token_env_var": "ARCPY_MCP_TOKEN",
}
```

```python
"https://192.168.50.170:8765/mcp",
```

Add this shipped-file guard to `tests/test_repository.py`:

```python
def test_shipped_client_files_do_not_reference_old_endpoint():
    shipped_files = [
        ROOT / "README.md",
        ROOT / "plugins/arcpy-mcp/.mcp.json",
        ROOT / "plugins/arcpy-mcp/scripts/configure-macos.sh",
        ROOT / "plugins/arcpy-mcp/scripts/verify-connection.sh",
        ROOT / "plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md",
    ]

    for path in shipped_files:
        assert "192.168.25.228" not in path.read_text(encoding="utf-8"), path
```

- [ ] **Step 2: Run the focused tests and confirm they fail for the old client material**

Run:

```powershell
python -m pytest tests/test_scripts.py tests/test_manifests.py tests/test_repository.py -v
```

Expected: failures show the old CA hash and occurrences of
`192.168.25.228`; unrelated existing tests pass.

- [ ] **Step 3: Preserve certificate bytes and install the replacement CA asset**

Create `.gitattributes` with:

```gitattributes
plugins/arcpy-mcp/assets/*.crt -text
```

Replace the tracked certificate byte-for-byte from the server-generated public
CA using the explicit paths below. Do not copy any key file:

```powershell
Copy-Item -LiteralPath 'C:\Users\zn198\AppData\Local\ArcPyMCP\certs\ca.crt' -Destination 'D:\adk\standalone\codex-arcpy-mcp-plugin\plugins\arcpy-mcp\assets\arcpy-mcp-ca.crt'
```

Verify the copied file before continuing:

```powershell
Get-FileHash -Algorithm SHA256 'plugins\arcpy-mcp\assets\arcpy-mcp-ca.crt'
```

Expected SHA-256:

```text
3D875F739F3200E8CB6E351E0C2C6976D3686DE11DD7E915FE069EE8535957CD
```

- [ ] **Step 4: Change every shipped client endpoint to the new host**

Set `plugins/arcpy-mcp/.mcp.json` to:

```json
{
  "mcpServers": {
    "arcpy": {
      "type": "http",
      "url": "https://192.168.50.170:8765/mcp",
      "bearer_token_env_var": "ARCPY_MCP_TOKEN"
    }
  }
}
```

Use these exact URL assignments in the scripts:

```bash
# configure-macos.sh
HEALTH_URL="https://192.168.50.170:8765/healthz"

# verify-connection.sh
HEALTH_URL="https://192.168.50.170:8765/healthz"
MCP_URL="https://192.168.50.170:8765/mcp"
```

Replace the old host in `README.md` so the introduction, prerequisites,
troubleshooting, and fixed MCP URL all name `192.168.50.170:8765`. Do not add
the migration procedure yet; that is tested and implemented in Task 3.

- [ ] **Step 5: Run the focused tests and confirm they pass**

Run:

```powershell
python -m pytest tests/test_scripts.py tests/test_manifests.py tests/test_repository.py -v
```

Expected: all tests pass.

- [ ] **Step 6: Commit the endpoint and certificate migration**

```powershell
git add .gitattributes README.md tests/test_scripts.py tests/test_manifests.py tests/test_repository.py plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt plugins/arcpy-mcp/.mcp.json plugins/arcpy-mcp/scripts/configure-macos.sh plugins/arcpy-mcp/scripts/verify-connection.sh
git commit -m "chore: migrate ArcPy endpoint and CA"
```

### Task 2: Add Token-Preserving CA Refresh Mode

**Files:**
- Modify: `plugins/arcpy-mcp/scripts/configure-macos.sh`
- Modify: `tests/test_scripts.py`

- [ ] **Step 1: Write a failing static contract test for the refresh branch**

Add to `tests/test_scripts.py`:

```python
def test_configure_script_refreshes_ca_without_touching_token():
    text = CONFIGURE.read_text(encoding="utf-8")

    required = [
        "--refresh-ca",
        'LEGACY_CA_SHA1="609AD1A4FD4707958587A7C2B4E1DBDEA87F5800"',
        'CURRENT_CA_SHA1="33FB760A998BE34BE3A7972290AD49C15F1E886F"',
        "security find-certificate",
        "security delete-certificate",
        "security add-trusted-cert",
        "refresh_ca",
        "refresh_plugin",
    ]
    for phrase in required:
        assert phrase in text

    case_body = text.rsplit('case "$MODE" in', maxsplit=1)[1].split(
        "esac", maxsplit=1
    )[0]
    install_branch = case_body.split("install)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    rotate_branch = case_body.split("--rotate-token)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    refresh_branch = case_body.split("--refresh-ca)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    assert "store_token" in install_branch
    assert "install_token_loader" in install_branch
    assert "refresh_ca" in install_branch
    assert "refresh_plugin" in install_branch
    assert "store_token" in rotate_branch
    assert "install_token_loader" in rotate_branch
    assert "refresh_ca" in refresh_branch
    assert "refresh_plugin" in refresh_branch
    assert "store_token" not in refresh_branch
    assert "install_token_loader" not in refresh_branch
```

- [ ] **Step 2: Run the new test and confirm the mode is absent**

Run:

```powershell
python -m pytest tests/test_scripts.py::test_configure_script_refreshes_ca_without_touching_token -v
```

Expected: FAIL because `--refresh-ca` and the fingerprint constants are not in
the script.

- [ ] **Step 3: Implement mode parsing and certificate fingerprint lookup**

Replace the current two-mode validation with:

```bash
MODE="${1:-install}"
case "$MODE" in
  install|--rotate-token|--refresh-ca) ;;
  *)
    printf 'Usage: %s [--rotate-token|--refresh-ca]\n' "$0" >&2
    exit 2
    ;;
esac
```

Add `tr` to the required command loop and define exact fingerprints after the
Keychain paths:

```bash
for required_command in codex git security launchctl curl grep id tr; do
```

```bash
LEGACY_CA_SHA1="609AD1A4FD4707958587A7C2B4E1DBDEA87F5800"
CURRENT_CA_SHA1="33FB760A998BE34BE3A7972290AD49C15F1E886F"
```

Add the fingerprint helper and refresh function:

```bash
ca_present() {
  local fingerprint="$1"

  security find-certificate -a -Z "$LOGIN_KEYCHAIN" 2>/dev/null \
    | tr '[:lower:]' '[:upper:]' \
    | grep -Fq "$fingerprint"
}

refresh_ca() {
  if ca_present "$LEGACY_CA_SHA1"; then
    if ! security delete-certificate \
      -Z "$LEGACY_CA_SHA1" \
      "$LOGIN_KEYCHAIN" >/dev/null; then
      printf 'Failed to remove the legacy ArcPy MCP CA.\n' >&2
      return 1
    fi
  fi

  if ! ca_present "$CURRENT_CA_SHA1"; then
    security add-trusted-cert \
      -r trustRoot \
      -p ssl \
      -k "$LOGIN_KEYCHAIN" \
      "$CA_CERT"
  fi

  if ! ca_present "$CURRENT_CA_SHA1"; then
    printf 'The replacement ArcPy MCP CA is not installed.\n' >&2
    return 1
  fi
}
```

- [ ] **Step 4: Separate plugin refresh from CA refresh and route each mode**

Replace `install_plugin` with:

```bash
refresh_plugin() {
  if codex plugin marketplace list | grep -Fq "$MARKETPLACE_NAME"; then
    codex plugin marketplace upgrade "$MARKETPLACE_NAME"
  else
    codex plugin marketplace add "$MARKETPLACE_SOURCE"
  fi
  codex plugin add arcpy-mcp@zhouning-arcpy
}
```

Replace the unconditional token setup and install branch with:

```bash
case "$MODE" in
  install)
    store_token
    install_token_loader
    refresh_ca
    refresh_plugin
    ;;
  --rotate-token)
    store_token
    install_token_loader
    ;;
  --refresh-ca)
    refresh_ca
    refresh_plugin
    ;;
esac
```

Keep the existing CA file validation and final `curl --cacert` health check
outside the mode branch so every successful mode checks the new endpoint.

- [ ] **Step 5: Run the script tests and shell parser**

Run:

```powershell
python -m pytest tests/test_scripts.py -v
bash -n plugins/arcpy-mcp/scripts/configure-macos.sh
```

Expected: all script tests pass and `bash -n` exits 0 with no output.

- [ ] **Step 6: Commit the migration mode**

```powershell
git add tests/test_scripts.py plugins/arcpy-mcp/scripts/configure-macos.sh
git commit -m "feat: add macOS CA refresh workflow"
```

### Task 3: Document Migration and Signed URL Renewal

**Files:**
- Modify: `plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md`
- Modify: `README.md`
- Modify: `tests/test_manifests.py`

- [ ] **Step 1: Write failing documentation and skill contract assertions**

Add these phrases to the `required` list in
`test_skill_contains_required_safety_and_workflow_rules`:

```python
"call `create_download` again",
"Never rewrite the hostname of a signed URL",
```

Add these phrases to the `required` list in
`test_readme_documents_install_update_rotation_and_removal`:

```python
"configure-macos.sh --refresh-ca",
"The Bearer Token does not change",
"call `create_download` again",
"Do not rewrite or reuse a signed URL issued for the old host",
```

- [ ] **Step 2: Run the two focused tests and confirm the migration guidance is absent**

Run:

```powershell
python -m pytest tests/test_manifests.py::test_skill_contains_required_safety_and_workflow_rules tests/test_manifests.py::test_readme_documents_install_update_rotation_and_removal -v
```

Expected: both tests fail on the newly required phrases.

- [ ] **Step 3: Add the signed download URL rule to the ArcPy skill**

Insert this as step 4 under `## Download Results`, renumbering the current
checksum and extraction steps to 5 and 6:

```markdown
4. If a signed URL was issued for a different host or has expired, discard it
   and call `create_download` again. Never rewrite the hostname of a signed URL.
```

- [ ] **Step 4: Add an explicit host and CA migration section to README**

Insert this section after `## Update` and before Bearer token rotation:

````markdown
## Migrate The Host And CA

When the Windows host or local CA changes, update the checkout and refresh the
client trust and plugin registration:

```bash
git -C codex-arcpy-mcp-plugin pull --ff-only
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh --refresh-ca
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh
```

The refresh removes only the known legacy CA fingerprint, imports the bundled
replacement CA into the login Keychain, and reinstalls the plugin configuration.
The Bearer Token does not change and the command does not read or rewrite it.

Restart Codex and open a new thread after the refresh. Signed artifact download
URLs contain the issuing host, so URLs created before this migration are no
longer valid. Do not rewrite or reuse a signed URL issued for the old host; keep
the artifact ID and call `create_download` again.
````

- [ ] **Step 5: Run the documentation contract tests**

Run:

```powershell
python -m pytest tests/test_manifests.py -v
```

Expected: all manifest, skill, and README tests pass.

- [ ] **Step 6: Commit the operator and agent guidance**

```powershell
git add README.md tests/test_manifests.py plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md
git commit -m "docs: document ArcPy client migration"
```

### Task 4: Complete Repository Verification

**Files:**
- Verify only; no production files should change.

- [ ] **Step 1: Run the complete Python test suite**

Run:

```powershell
python -m pytest -v
```

Expected: 10 tests pass.

- [ ] **Step 2: Parse both macOS scripts with Bash**

Run:

```powershell
bash -n plugins/arcpy-mcp/scripts/configure-macos.sh
bash -n plugins/arcpy-mcp/scripts/verify-connection.sh
```

Expected: both commands exit 0 with no output.

- [ ] **Step 3: Confirm the old endpoint and private material are absent from shipped files**

Run:

```powershell
rg -n "192\.168\.25\.228" README.md plugins/arcpy-mcp/.mcp.json plugins/arcpy-mcp/scripts plugins/arcpy-mcp/skills
```

Expected: no matches; `rg` exits 1 because the address is absent.

Run:

```powershell
rg -n "BEGIN (RSA |EC )?PRIVATE KEY|Bearer [A-Za-z0-9_-]{20,}" README.md plugins tests .agents
```

Expected: no matches; `rg` exits 1 because no private key or literal Bearer
credential is present.

- [ ] **Step 4: Inspect certificate hash, diff hygiene, and repository state**

Run:

```powershell
Get-FileHash -Algorithm SHA256 plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt
git diff --check
git status --short
```

Expected: the certificate hash is
`3D875F739F3200E8CB6E351E0C2C6976D3686DE11DD7E915FE069EE8535957CD`,
`git diff --check` is silent, and `git status --short` is clean after the three
task commits.

- [ ] **Step 5: Record the remaining platform acceptance boundary**

Do not change the README verification status. Report that live Keychain
deletion/import, LaunchAgent behavior, TLS, authenticated MCP initialization,
and Codex plugin loading remain pending on the target Mac. The exact target-Mac
commands are:

```bash
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh --refresh-ca
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh
```
