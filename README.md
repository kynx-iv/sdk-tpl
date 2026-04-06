# sdk-tpl

A scaffold for multi-language SDK monorepos. One command generates production-ready client libraries for 12 languages with shared infrastructure baked in.

Built for API providers who need consistent, high-quality SDKs across the ecosystem without maintaining 12 separate repos.

---

## What it generates

12 idiomatic SDKs from a single config file:

| Language | Package Manager | Registry |
|----------|----------------|----------|
| TypeScript | npm | npmjs.com |
| React | npm | npmjs.com |
| Python | pip | PyPI |
| Go | go get | pkg.go.dev |
| Java | Maven | Maven Central |
| Kotlin | Gradle | Maven Central |
| PHP | Composer | Packagist |
| Swift | SPM | GitHub |
| Ruby | gem | RubyGems |
| Rust | Cargo | crates.io |
| Dart | pub | pub.dev |
| .NET | NuGet | nuget.org |

## What's baked in

Every generated SDK includes:

- **Retry with Jitter** — exponential backoff with full jitter, prevents thundering herd. Respects `Retry-After` headers.
- **Circuit Breaker** — 3-state machine (closed → open → half-open). Opens after 5 failures, resets after 30s.
- **HMAC Request Signing** — SHA-256 payload signatures with timestamp freshness validation.
- **API Key Rotation** — primary + secondary key support. Auto-rotates to secondary on 401.
- **PII Detection** — 40+ field patterns (email, ssn, credit card, password, token…). Warns before sensitive data leaves the client.
- **Error Sanitization** — redacts file paths, IPs, API keys, and emails from error messages.
- **Unified Error Codes** — structured error ranges across all languages (1000–1699).
- **80% Test Coverage** — enforced in CI across all 12 SDKs.

---

## Usage

### 1. Clone the template

```bash
git clone https://github.com/kynx-iv/sdk-tpl.git
cd sdk-tpl
```

### 2. Create your config

```json
{
  "SDK_NAME": "Acme",
  "SDK_SLUG": "acme",
  "SDK_SLUG_UPPER": "ACME",
  "SDK_SLUG_PASCAL": "Acme",
  "ORG_NAME": "@acme",
  "ORG_SLUG": "acme",
  "API_BASE_URL": "https://api.acme.dev/api/v1/sdk",
  "API_LOCAL_URL": "https://api.acme.localhost/api/v1/sdk",
  "SDK_VERSION": "1.0.0",
  "GITHUB_ORG": "acme",
  "ENV_MODE_VAR": "ACME_MODE"
}
```

See [`sdk-tpl.config.json`](./sdk-tpl.config.json) for full placeholder reference.

### 3. Scaffold

```bash
./scripts/scaffold.sh --config my-config.json --output ../acme-sdk
```

This copies the template, replaces all placeholders, renames files and directories, and initializes a git repo with an initial commit.

### 4. Start building

```bash
cd ../acme-sdk
task setup    # Install dependencies for all 12 SDKs
task build    # Build all SDKs
task test     # Run tests (80% coverage enforced)
```

---

## Project structure

```
sdk-tpl/
├── sdk-tpl.config.json     # Placeholder definitions and examples
├── scripts/
│   ├── scaffold.sh         # Template instantiation
│   ├── bump-version.sh     # Version management across all SDKs
│   └── release.sh          # Publish to all registries
├── Taskfile.yml            # Task automation (build, test, release, version)
└── sdks/
    ├── typescript/
    ├── react/
    ├── python/
    ├── go/
    ├── java/
    ├── kotlin/
    ├── php/
    ├── swift/
    ├── ruby/
    ├── rust/
    ├── dart/
    └── dotnet/
```

## Version management

A single `VERSION` file at the repo root is the source of truth. All 12 SDKs read from it.

```bash
task version              # Show current version
task version-check        # Verify all 12 SDKs match VERSION
task bump-version -- minor   # Bump minor (1.0.0 → 1.1.0)
task bump-version -- 2.0.0   # Set explicit version
```

## Release

```bash
task validate                   # Pre-release checks
task release -- --dry-run all   # Simulate publishing
task release -- all             # Publish all 12 SDKs to their registries
```

---

## Requirements

- [Task](https://taskfile.dev) (go-task)
- Language runtimes for SDKs you want to build/test
- Registry credentials configured per language (npm, PyPI, Maven Central, etc.)

---

## License

MIT