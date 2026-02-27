---
name: secret-scanning
description: Secret and PII awareness for code generation, committing, and pushing. MUST be applied when writing code, config, tests, or examples. MUST be applied when committing or pushing code to scan staged/changed files for hardcoded credentials and real PII.
---

# Secret & PII Scanning Awareness

**Scope:** Pattern tables for detecting secrets and PII, safe placeholder values, and the mandatory disposition process for evaluating matches.

Never generate code, config, tests, or examples containing real or realistic-looking secrets, credentials, or PII. Use obviously fake values instead.

This skill MUST be loaded for:
- **Writing** code, config, tests, examples, or documentation
- **Committing** code (scan staged files before commit)
- **Pushing** code (scan changed files before push)

## Secrets: Known Prefixes and Signatures

When generating code, NEVER produce strings that match these patterns. Use placeholder values like `<YOUR_API_KEY>` or clearly fake tokens instead.

### AWS

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `aws:access_key_id` | AWS Access Key ID | `AKIA` followed by 16 uppercase alphanumeric chars |
| `aws:secret_access_key` | AWS Secret Access Key | 40-char base64 string assigned to `aws_secret_access_key` |
| `aws:session_token` | AWS Session Token | 100+ char base64 string assigned to `aws_session_token` |
| `aws:mfa_arn` | AWS MFA ARN | `arn:aws:iam::<12-digit>:mfa/` |
| `aws:role_arn` | AWS Role ARN | `arn:aws:iam::<12-digit>:role/` |
| `aws:account_id` | AWS Account ID | 12-digit number in AWS account context |

### Google / GCP

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `gcp:api_key` | GCP API Key | `AIza` followed by 35 chars |
| `gcp:service_account_key` | GCP Service Account Key | JSON with `private_key` containing `-----BEGIN PRIVATE KEY` |
| `gcp:oauth_token` | Google OAuth Token | `ya29.` followed by alphanumeric chars |
| `gcp:oauth_client_secret` | GCP OAuth Client Secret | `client_secret` key in JSON, 24+ char value |
| `gcp:firebase_config` | Firebase Config | `apiKey` containing `AIza` prefix |

### Azure

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `azure:storage_key` | Azure Storage Key | 86-char base64 string ending `==` assigned to `AccountKey` |
| `azure:sas_token` | Azure SAS Token | `sv=` followed by date, `&s` followed by `b`, `q`, `e`, or `c` |
| `azure:connection_string` | Azure Connection String | `DefaultEndpointsProtocol=https;AccountName=...;AccountKey=` |
| `azure:ad_client_secret` | Azure AD Client Secret | 34+ char string assigned to `clientSecret` or `AZURE_CLIENT_SECRET` |
| `azure:tenant_id` | Azure Tenant ID | UUID assigned to `tenant_id` or `AZURE_TENANT_ID` |

### GitHub / GitLab / Bitbucket

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `github:pat` | GitHub Personal Access Token | `ghp_`, `ghu_`, `gho_`, `ghs_`, or `ghr_` followed by 36+ chars |
| `github:app_token` | GitHub App Token | `ghs_` followed by 36 chars |
| `github:oauth_token` | GitHub OAuth Token | `gho_` followed by 36 chars |
| `github:action_token` | GitHub Action Token | `github_pat_` followed by 82 chars |
| `gitlab:personal_token` | GitLab Personal Token | `glpat-` followed by 20 chars |
| `gitlab:runner_token` | GitLab Runner Token | `glrt-` followed by 20 chars |
| `bitbucket:app_password` | Bitbucket App Password | `BITBUCKET_TOKEN` or `bitbucket.*password` variable |

### Stripe / Payment

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `stripe:secret_key` | Stripe Secret Key | `sk_live_` or `sk_test_` followed by 24+ chars |
| `stripe:publishable_key` | Stripe Publishable Key | `pk_live_` or `pk_test_` followed by 24+ chars |
| `stripe:webhook_secret` | Stripe Webhook Secret | `whsec_` followed by 32+ chars |
| `paypal:client_secret` | PayPal Client Secret | `PAYPAL_CLIENT_SECRET` or `paypal.*secret` variable |
| `square:token` | Square Token | `sq0` followed by 3 lowercase + `-` + 22-43 chars |
| `payment:credit_card` | Credit Card Number | 13-16 digit patterns starting with 3 (AMEX), 4 (Visa), or 5 (MC) |

### Slack / Discord / Telegram

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `slack:bot_token` | Slack Bot Token | `xoxb-` followed by numeric-dash-alphanumeric segments |
| `slack:user_token` | Slack User Token | `xoxp-` followed by numeric-dash-alphanumeric segments |
| `slack:app_token` | Slack App Token | `xapp-` followed by numeric segments |
| `slack:webhook_url` | Slack Webhook URL | `hooks.slack.com/services/T.../B.../...` |
| `discord:bot_token` | Discord Bot Token | Starts with `M`, `N`, or `O` + 23 chars, dot-separated segments |
| `discord:webhook_url` | Discord Webhook URL | `discord(app).com/api/webhooks/` followed by numeric ID and token |
| `telegram:bot_token` | Telegram Bot Token | 8-10 digits `:` 35 chars |

### Communication Services

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `twilio:account_sid` | Twilio Account SID | `AC` followed by 32 hex chars |
| `twilio:auth_token` | Twilio Auth Token | `TWILIO_AUTH_TOKEN` or `twilio.*token` variable, 32 hex chars |
| `sendgrid:api_key` | SendGrid API Key | `SG.` followed by 22 chars `.` 43 chars |
| `mailgun:api_key` | Mailgun API Key | `key-` followed by 32 chars |
| `postmark:server_token` | Postmark Server Token | UUID format assigned to Postmark server token variable |

### AI / ML Services

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `anthropic:api_key` | Anthropic API Key | `sk-ant-` followed by 95+ chars |
| `openai:api_key` | OpenAI API Key | `sk-` followed by 48 chars |
| `openai:project_key` | OpenAI Project Key | `sk-proj-` followed by 90+ chars |
| `huggingface:token` | Hugging Face Token | `hf_` followed by 37 chars |

### Infrastructure

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `vault:token` | Vault Token | `s.` followed by 24 chars |
| `terraform:cloud_token` | Terraform Cloud Token | 14 chars `.` 6 chars `.` 32 chars |
| `newrelic:license_key` | New Relic License Key | `NRAK-` followed by 27 chars |
| `sentry:dsn` | Sentry DSN | `https://<32-hex>@<host>.ingest.sentry.io/` |
| `cloudflare:api_token` | Cloudflare API Token | 40 chars assigned to `CF_API_TOKEN` |
| `datadog:api_key` | Datadog API Key | 32 hex chars assigned to `DD_API_KEY` |
| `heroku:api_key` | Heroku API Key | UUID format assigned to `heroku` context |
| `k8s:service_account_token` | Kubernetes Service Account Token | JWT starting with `eyJhbGciOiJSUzI1NiIs` |
| `k8s:kubeconfig_credential` | kubeconfig Embedded Credential | `users:` block with `token:` field, 40+ char value |
| `ansible:vault_encrypted` | Ansible Vault Encrypted | `$ANSIBLE_VAULT;` prefix |
| `ssh:private_key_inline` | SSH Private Key (inline) | `ssh-rsa AAAA` prefix |

### Private Keys & Certificates

| Rule ID | Name | Signature |
|---------|------|-----------|
| `key:rsa_private` | RSA Private Key | `-----BEGIN RSA PRIVATE KEY-----` |
| `key:ec_private` | EC Private Key | `-----BEGIN EC PRIVATE KEY-----` |
| `key:dsa_private` | DSA Private Key | `-----BEGIN DSA PRIVATE KEY-----` |
| `key:openssh_private` | OpenSSH Private Key | `-----BEGIN OPENSSH PRIVATE KEY-----` |
| `key:pgp_private` | PGP Private Key | `-----BEGIN PGP PRIVATE KEY BLOCK-----` |
| `key:pkcs8_private` | PKCS8 Private Key | `-----BEGIN PRIVATE KEY-----` |
| `key:certificate` | Certificate (potential internal CA) | `-----BEGIN CERTIFICATE-----` |
| `key:keystore_password` | Keystore Password | `KEYSTORE_PASS` or `keystore.*password` variable |
| `key:pem_passphrase` | PEM Passphrase | `PEM_PASS` or `pem.*passphrase` variable |

### Generic Patterns

| Rule ID | Name | Signature |
|---------|------|-----------|
| `generic:jwt` | JWT Token | `eyJ` base64 dot-separated three segments |
| `generic:npm_auth` | npm Auth Token | `//registry.npmjs.org/:_authToken=` |
| `generic:pypi_token` | PyPI Token | `pypi-` followed by 150+ chars |
| `generic:basic_auth_url` | Basic auth in URL | `https://user:password@host` |
| `generic:auth_header` | Auth header with credential | `Authorization: Basic`, `Bearer`, or `Token` followed by credential string |
| `generic:db_connection_string` | Database connection string | `protocol://user:password@host` |
| `generic:netrc` | `.netrc` credentials | `machine ... login ... password` pattern |

### Database / Connection Strings

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `db:postgresql_dsn` | PostgreSQL DSN | `postgres://` or `postgresql://` with embedded credentials |
| `db:mysql_dsn` | MySQL DSN | `mysql://` with embedded credentials |
| `db:mongodb_dsn` | MongoDB DSN | `mongodb://` or `mongodb+srv://` with embedded credentials |
| `db:redis_dsn` | Redis DSN | `redis://` with embedded password |
| `db:jdbc_connection` | JDBC Connection String | `jdbc:` prefix with embedded credentials |
| `db:sqlserver_connection` | SQL Server Connection String | `Server=...;Password=` pattern |
| `db:password_in_config` | Database Password in Config | `DB_PASS`, `DATABASE_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `POSTGRES_PASSWORD` variables |

### Generic Password / Secret Patterns

| Rule ID | Name | Variable / Signature |
|---------|------|---------------------|
| `generic:password_in_code` | Password in code | `password`, `passwd`, `pwd`, `pass` assigned to a string literal |
| `generic:secret_in_code` | Secret in code | `secret`, `SECRET` assigned to a string literal |
| `generic:api_key_in_code` | API Key in code | `api_key`, `API_KEY`, `apikey`, `access_key` assigned to a string literal |
| `generic:token_in_code` | Token in code | `token`, `TOKEN` assigned to a string literal |
| `generic:private_key_var` | Private key variable | `private_key`, `PRIVATE_KEY` assigned to a string literal |
| `generic:bearer_token` | Hardcoded bearer token | `bearer` followed by 20+ char token string |

### Okta / Auth Providers

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `okta:api_token` | Okta API Token | `OKTA_API_TOKEN` variable, value starting with `00` followed by 40+ chars |
| `auth0:client_secret` | Auth0 Client Secret | `AUTH0_CLIENT_SECRET` or `auth0.*secret` variable |

### Social / API Services

| Rule ID | Name | Prefix / Signature |
|---------|------|-------------------|
| `twitter:bearer_token` | Twitter/X Bearer Token | `AAAAAAAAAAAAAAAAAAAAAA` prefix |
| `twitter:api_key` | Twitter/X API Key | `TWITTER_API_KEY` or `twitter.*api_key` variable |
| `facebook:app_secret` | Facebook App Secret | `FACEBOOK_APP_SECRET` or `fb.*secret` variable |

## PII: Never Use Real Values

When generating test data, examples, or mock content, NEVER use realistic PII. Use obviously fake values.

### Safe Placeholder Values

| Rule ID | PII Type | Use This | Never This |
|---------|----------|----------|------------|
| `pii:email` | Email | `test@example.uri` | Realistic-looking emails at real domains |
| `pii:phone_au` | Phone (AU) | `+61 400 000 000` | Real-looking mobile numbers |
| `pii:phone_us` | Phone (US) | `+1 555-000-0000` | Real-looking numbers outside 555 prefix |
| `pii:phone_intl` | Phone (International) | `+99 000 000 0000` | Real-looking international numbers |
| `pii:tfn_au` | TFN (AU) | `000 000 000` | 9-digit numbers that look real |
| `pii:medicare_au` | Medicare (AU) | `2000 00000 0 0` | Real-looking Medicare numbers |
| `pii:ssn_us` | SSN (US) | `000-00-0000` | Real-looking SSNs |
| `pii:ni_uk` | NI Number (UK) | `AA 00 00 00 A` | Real-looking NI numbers |
| `pii:passport` | Passport Number | `A0000000` | Real-looking passport numbers |
| `pii:credit_card` | Credit Card | `4000 0000 0000 0000` (Stripe test) | Real-looking card numbers |
| `pii:bsb_au` | BSB (AU) | `000-000` | Real-looking BSB numbers |
| `pii:iban` | IBAN | `XX00 0000 0000 0000` | Real-looking IBANs |
| `pii:bank_account` | Bank Account | `0000000000` | Real-looking account numbers |
| `pii:ip_address` | IP Address | `192.0.2.1` (TEST-NET) | Real public IPs |
| `pii:ip_rfc1918` | Private IP (RFC1918) | `10.0.0.1`, `192.168.0.1` | Real RFC1918 ranges in production code/config |
| `pii:hostname` | Hostname | `test.example.uri` | Real-looking internal hostnames (`.local`, `.corp`, `.lan`, `.priv`) |
| `pii:street_address` | Street Address | `123 Test Street, Testville` | Real street addresses |
| `pii:postcode_au` | Postcode (AU) | `0000` | Real-looking postcodes |
| `pii:full_name` | Full Name | `Jane Doe`, `John Smith`, `Test User` | Uncommon names that could be real people |
| `pii:dob` | DOB | `2000-01-01` | Specific dates that look real |

## When Writing Code

1. **Never generate** strings matching known secret prefixes — even in examples, comments, or documentation
2. **Never use** realistic PII in test data, fixtures, mocks, or examples
3. **Always use** obviously fake placeholder values from the tables above
4. **Config values**: Use `<PLACEHOLDER>` style (e.g. `<YOUR_API_KEY>`, `<DATABASE_URL>`)
5. **Environment variables**: Show the variable name, never a realistic value (e.g. `export API_KEY="<your-key-here>"`)
6. **Connection strings**: Use `localhost` or `example.com` with placeholder credentials

## When Checking / Verifying Code

When reviewing, auditing, or reading existing code — whether asked explicitly or as part of normal work:

1. **ONLY flag** strings that match a specific pattern defined in the tables in this skill
2. **Every finding MUST cite the Rule ID** from the table it matched (e.g. `db:sqlserver_connection`, `pii:email`). If you cannot cite a Rule ID, the finding is invalid and must not be reported
3. **Do NOT invent patterns** — if something looks suspicious but does not match a defined pattern, do not flag it as a finding. If you believe a new pattern should be added, suggest it as a skill improvement instead
4. **Report findings clearly**: state the file, the Rule ID, and the specific value (redacted if it looks real)
5. **Suggest remediation**: environment variable, secret manager, config file excluded from source control, or placeholder replacement

### Finding Disposition Process (MANDATORY)

Every finding MUST be explicitly resolved. No finding may be silently skipped, dismissed, or assumed safe.

**Step 1: Present ALL findings in a table**

| # | Rule ID | Severity | File:Line | Value (redacted if real) | Suggested Disposition | Remediation Action |
|---|---------|----------|-----------|--------------------------|----------------------|--------------------|

The **File:Line** column must include the file path and line number (e.g. `src/config.ts:42`). This allows the Supreme Commander to locate the finding immediately.

The **Remediation Action** column is REQUIRED for any finding with a "Remediate" disposition. It must specify the exact action from this table:

| Remediation Action | What Happens |
|--------------------|--------------|
| **Remove from file** | Delete the matched content from the file using edit tools |
| **Replace with placeholder** | Swap the real value for a safe placeholder from the PII/placeholder tables in this skill |
| **Move to env var** | Remove the hardcoded value and reference an environment variable instead |
| **Exclude from source control** | Add the file/path to `.gitignore` so it is no longer tracked |

When multiple findings are in the same block (e.g. multiple PII values in one JSON object), group them and specify a single remediation action for the block (e.g. "Remove entire `mssql.connections` block from file").

**Step 2: For each finding, suggest ONE disposition:**

| Disposition | Meaning | Who Decides |
|-------------|---------|-------------|
| **Remediate** | Apply the specified remediation action to fix the finding | Assistant suggests action, Supreme Commander confirms |
| **False Positive** | Matches a pattern but is not a real secret/PII (e.g. public cert, pattern definition file, test fixture) | Supreme Commander decides — assistant must explain WHY it appears to be a false positive |
| **Not In Scope** | File is not tracked in source control, or is a binary/generated file | Assistant must verify (e.g. `git ls-files`) before suggesting this disposition |

**Step 3: Ask the Supreme Commander to resolve each finding**

After presenting the table, use the `ask_questions` tool to collect a decision for each finding. Present one question per finding (batch up to 4 at a time). Each question must:

- State the finding (file, Rule ID, value)
- State the suggested disposition and remediation action (if Remediate)
- Offer these options:
  1. **Accept recommended** — confirm the suggested disposition (mark as `recommended`)
  2. **Needs discussion** — flag for further review before proceeding
  3. (Other is shown automatically — allows the Supreme Commander to type a custom disposition)
- Enable `allowFreeformInput: true` so the Supreme Commander can override with any disposition

Do NOT proceed with commit/push until every finding has an explicit decision. If any findings have "Needs discussion", the operation is blocked until resolved.

**Step 4: Execute remediation**

For each confirmed "Remediate" finding, execute the specified remediation action. Group related findings (e.g. same file/block) into a single edit operation.

**Step 4a: Commit remediated changes**

After remediation edits are applied, commit the changes. The working tree MUST be clean before history scrubbing can proceed (`git filter-branch` requires a clean working tree). Use the `git-commit` skill to commit.

**Step 5: Post-remediation — gidetermine whether the remediated values exist in git history and whether they've been pushed.

##### 5a: Determine current context

```sh
# What branch are we on?
git rev-parse --abbrev-ref HEAD

# What is the main branch?
git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'

# Are we on a feature branch or main?
```

##### 5b: Check if values exist in history

For each remediated value, check if it appears in any commit on the current branch:

```sh
git log --all -p -- "<file>" | grep -c "<value>"
```

If count is 0 for all values, no history scrub is needed — proceed to step 6.

##### 5c: Determine the scenario

If values are found in history, determine which commits contain them and whether those commits have been pushed:

```sh
# List unpushed commits on current branch
git log origin/<branch>..<branch> --oneline

# Check if the secret appears only in unpushed commits
git log origin/<branch>..<branch> -p -- "<file>" | grep -c "<value>"
```

Use this decision tree:

| Question | Yes | No |
|----------|-----|-----|
| Are we on main? | Check main history (→ Scenario A or D) | We're on a feature branch (→ next question) |
| Is the secret only in unpushed commits? | **Scenario B** — squash before pushing | Secret was already pushed (→ next question) |
| Is the secret also in main's history? | **Scenario D** — scrub both | **Scenario C** — scrub feature branch only |

##### 5d: Hand off to remediation

Present the scenario determination to the Supreme Commander and invoke the `secret-remediation` skill with:
- The identified scenario (A, B, C, or D)
- Which branches need scrubbing
- The list of values and their replacements

**Scenario B only**: no history scrub is needed — advise the Supreme Commander to squash-merge the feature branch before pushing. The secret never reaches remote.

**Scenarios A, C, D**: the secret has been pushed to a remote and must be considered **compromised**. Inform the Supreme Commander that credential rotation (revoke + replace) is mandatory in addition to history scrubbing. History scrubbing alone does not undo the exposure — platform PR diffs, cached clones, and CI logs may retain the value permanently.
2. If the count is > 0, the value exists in git history and must be scrubbed
3. If any values are found in history, inform the Supreme Commander and invoke the `secret-remediation` skill to handle the scrub

**Step 6: Record the outcome**

After all findings are resolved, summarise:
- How many findings were remediated (and which remediation action was taken)
- How many were confirmed as false positives
- How many were not in scope
- Whether git history was scrubbed (and which values)
- Whether any remain unresolved (blocks commit/push)

Then proceed with the operation (commit/push/scan complete).

### When Scanning (explicit review)

Present all findings using the disposition process above. The goal is awareness — the Supreme Commander decides every disposition.

### When Committing (via `git-commit` skill)

The `git-commit` skill scans staged files before committing. Present findings using the disposition process above. Do not commit until every finding has an explicit disposition.

**Commit-context adjustments**: When scanning is triggered during a commit (not a standalone review), skip steps 4a and 5 of the disposition process. Remediation is applied directly to staged files before committing — there is no need to commit remediation separately or check git history, because the secret has not entered history yet.

### When Pushing (via `git-push` skill)

The `git-push` skill loads this skill and scans all commits being pushed. Present findings using the disposition process above. Do not push until every finding has an explicit disposition.

### Skip Paths

These paths produce frequent false positives and should be treated with lower severity when scanning. Still flag findings, but note the path is in the skip list:

- `test/`, `tests/`, `spec/`, `__tests__/`, `fixtures/`
- `vendor/`, `node_modules/`, `.git/`
- `CHANGELOG`, `CHANGELOG.md`, `HISTORY.md`
- `*.example`, `*.sample`, `*.template`, `*.tmpl`
- `docs/`, `documentation/`

### Skip Extensions

Do not scan binary or generated files:

- Images: `.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp`, `.ico`, `.svg`, `.webp`, `.tiff`
- Media: `.mp3`, `.mp4`, `.wav`, `.ogg`, `.flac`, `.avi`, `.mov`, `.mkv`
- Archives: `.zip`, `.tar`, `.gz`, `.bz2`, `.xz`, `.7z`, `.rar`, `.jar`, `.war`
- Documents: `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`
- Binaries: `.exe`, `.dll`, `.so`, `.dylib`, `.a`, `.o`
- Fonts: `.woff`, `.woff2`, `.ttf`, `.eot`, `.otf`
- Compiled: `.pyc`, `.pyo`, `.class`, `.cache`
- Minified: `.min.js`, `.min.css`
- Lock files: `.lock`, `.sum`

## False Positives

Some matches are intentional and safe. When flagging a finding, consider whether it falls into a known false-positive category before reporting:

### Legitimate Checkins

| Category | Example | Why It's OK |
|----------|---------|-------------|
| Public certificates | CA certs, root certs, TLS chain certs | Certificates are public by design — only private keys are secrets |
| Public API keys / client IDs | API keys that act as identifiers, not secrets (e.g. Google Maps client-side key, Firebase `apiKey`, Stripe publishable keys `pk_test_`/`pk_live_`) | These are designed to be embedded in client code; the matching API secret is the actual credential |
| Domain-restricted API keys | Google Maps API key, reCAPTCHA site key, other keys secured by domain/referrer restrictions | These are public by design — security is enforced server-side via domain allowlists, not by keeping the key secret |
| Pattern definition files | Regex patterns listing secret formats (e.g. this skill itself, git hook configs) | Defining what to scan for is not a secret |

### Handling False Positives

False positives are handled through the Finding Disposition Process above. When a finding looks like a false positive:

1. **Still present it** in the findings table — never silently skip
2. **Suggest "False Positive" disposition** with a clear explanation of WHY (e.g. "public certificate, not a private key")
3. **Wait for the Supreme Commander to confirm** — do not assume it is safe
4. If the category is in the "Legitimate Checkins" table above, note that in your explanation
