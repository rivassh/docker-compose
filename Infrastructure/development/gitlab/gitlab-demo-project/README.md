# GitLab Local Ecosystem Demo Project

This directory contains starter templates for testing GitLab CI/CD, Terraform state management, and Docker-in-Docker pipelines with a local GitLab Container Registry.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Update /etc/hosts](#step-1-update-etchosts)
- [Step 2: Launch the GitLab Stack](#step-2-launch-the-gitlab-stack)
- [Step 3: Retrieve the Initial Root Password](#step-3-retrieve-the-initial-root-password)
- [Step 4: Configure GitLab Runner (if not auto-registered)](#step-4-configure-gitlab-runner-if-not-auto-registered)
- [Step 5: Create a New Project](#step-5-create-a-new-project)
- [Step 6: Set Up Terraform Backend (Optional)](#step-6-set-up-terraform-backend-optional)
- [Step 7: Test the CI/CD Pipeline](#step-7-test-the-cicd-pipeline)
- [Step 7.5: Auto Code Review Pipeline](#step-75-auto-code-review-pipeline)
- [Step 8: Test Locally Before Pushing to Production](#step-8-test-locally-before-pushing-to-production)
- [Step 9: Pipeline Troubleshooting Checklist](#step-9-pipeline-troubleshooting-checklist)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Docker and Docker Compose installed (version >= 2.0)
- 4 GB RAM available (GitLab needs at least 2 GB, plus runner)
- Git installed
- Terraform installed (for the Terraform demo)
- curl and bash

---

## Step 1: Update /etc/hosts

Add the following line to your `/etc/hosts` file (requires sudo):

```bash
# For Linux/macOS:
sudo sh -c 'echo "127.0.0.1 gitlab.local" >> /etc/hosts'

# For Windows (run PowerShell as Administrator):
# Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 gitlab.local"
```

This allows your browser and Git to resolve `gitlab.local` to the local GitLab instance.

---

## Step 2: Launch the GitLab Stack

From the repository root, run:

```bash
# Option 1: Baseline only (no GitLab)
./scripts/run-lab.sh 1

# Option 2: Baseline + GitLab (full stack)
./scripts/run-lab.sh 2

# Option 3: Auto-register runner (requires full stack)
./scripts/run-lab.sh 3
```

For this demo, choose **Option 2** to start everything.

The first launch may take 5–10 minutes while GitLab initializes (pulling the Docker image, etc.).

---

## Step 3: Retrieve the Initial Root Password

Once GitLab is up, retrieve the auto-generated root password:

```bash
docker exec gitlab-ce gitlab-rake gitlab:initial_root_password
```

You will see output like:

```
Password: PASSWORD_PLACEHOLDER
```

Copy this password.

1. Open your browser and go to: **http://gitlab.local:8080**
2. Log in with:
   - Username: `root`
   - Password: `<password from above>`
3. Change the password when prompted.

---

## Step 4: Configure GitLab Runner (if not auto-registered)

If you chose Option 1 (baseline only), you need to register a runner manually:

1. Get the runner registration token from GitLab:
   - Log in to GitLab → Menu → Admin Area → Overview → Runners
   - Copy the **Registration Token**

2. Set the token in `.env` (or as an environment variable):

   ```bash
   export GITLAB_RUNNER_REGISTRATION_TOKEN="your-token-here"
   ```

3. Run the auto-registration script:

   ```bash
   ./scripts/run-lab.sh 3
   ```

The runner should now appear in GitLab's runner list.

---

## Step 5: Create a New Project

1. In GitLab, click **New Project**.
2. Choose **Create from template** → **Import project** (or create blank).
3. Name it `gitlab-demo-project` and set the visibility to **Private** or **Internal**.
4. Initialize with a README (optional).
5. Push this demo project to GitLab:

   ```bash
   cd gitlab-demo-project
   git init
   git remote add origin http://gitlab.local:8080/root/gitlab-demo-project.git
   git add .
   git commit -m "Initial commit"
   git push -u origin main
   ```

---

## Step 6: Set Up Terraform Backend (Optional)

In the demo `main.tf`, replace the following variables:

- `var.gitlab_project_id`: Your GitLab project ID (found in **Settings > General**)
- Set the `GITLAB_TOKEN` environment variable:

  ```bash
  export GITLAB_TOKEN="your-gitlab-personal-access-token"
  ```

Then run:

```bash
terraform init
terraform plan
terraform apply
```

Terraform state will now be stored in GitLab's Terraform State backend.

---

## Step 7: Test the CI/CD Pipeline

The `.gitlab-ci.yml` file defines a 3-stage pipeline:

1. **test** – Runs basic checks.
2. **build** – Builds a Docker image and pushes to `gitlab.local:5050`.
3. **deploy** – Deploys the container to a staging host (requires SSH credentials).

To trigger the pipeline:

1. Push a commit to the repository:

   ```bash
   git add .
   git commit -m "Trigger pipeline"
   git push
   ```

2. Watch the pipeline in GitLab:
   - Go to **Project → Pipelines**.
   - Click the pipeline ID to see the stages.

---

## Step 7.5: Auto Code Review Pipeline

The file `.gitlab-ci.review.yml` defines a 3-stage review pipeline that runs **automatically on every push and merge request**, producing findings visible directly in the GitLab UI under **Security & Compliance → Vulnerability Report** and **Pipelines → Code Quality**.

### Overview

```
Push → [review] → [security] → [quality] → MR Comment with findings
```

### What Gets Checked

| Job | Tool | What it scans |
|---|---|---|
| `shellcheck:scripts` | [ShellCheck](https://www.shellcheck.net/) | All `.sh` scripts in the repo |
| `hadolint:dockerfile` | [Hadolint](https://github.com/hadolint/hadolint) | All `Dockerfile`s |
| `tflint:terraform` | [TFLint](https://github.com/terraform-linters/tflint) | All `.tf` files |
| `trivy:scan` | [Trivy](https://aquasecurity.github.io/trivy/) | Filesystem: secrets, config, vulnerabilities |
| `detect:secrets` | [detect-secrets](https://github.com/Yelp/detect-secrets) | Git-tracked files for committed secrets |
| `codequality:report` | GitLab Code Quality | Generic code quality metrics |

### How to Enable

1. The review pipeline is **automatically included** via the `include:` directive at the top of `.gitlab-ci.yml`:

   ```yaml
   include:
     - local: '.gitlab-ci.review.yml'
   ```

2. All jobs use `allow_failure: true`, meaning they **report issues but never block a merge request**. This lets you see the findings without breaking the flow.

### CI/CD Variables Needed

| Variable | Value | Where |
|---|---|---|
| `CI_REGISTRY_USER` | `root` | Project → Settings → CI/CD → Variables |
| `CI_REGISTRY_PASSWORD` | your GitLab password or token | same |

> **Note:** No additional CI variables are required for the review pipeline — all tools are installed inside the job containers at runtime.

### Viewing the Results

After a pipeline runs:

1. **In the pipeline view** — each job shows green (passed) or orange (warnings found).
2. **Artifacts** — expand any review job → **Browse artifacts** → `review-output/` folder.
3. **SARIF reports** — Trivy and Hadolint SARIF files appear under **Security & Compliance → Vulnerability Report** (if GitLab Ultimate, otherwise visible in artifacts).
4. **Code Quality tab** — under **Analyze → Quality**.

### Adding to an Existing Project

To add this review pipeline to any existing GitLab project:

1. Copy `.gitlab-ci.review.yml` into the project root.
2. Add the `include:` block to the existing `.gitlab-ci.yml`.
3. Ensure the runner has the `local` and `docker` tags.
4. Push and open a merge request — the review runs automatically.

### Customising Thresholds

To make a job **block the pipeline** instead of just warning, remove `allow_failure: true` from that job in `.gitlab-ci.review.yml`.

To add SonarQube as a real code quality engine:

```yaml
sonarqube:check:
  stage: quality
  image: sonarsource/sonar-scanner-cli:latest
  variables:
    SONAR_HOST_URL: "http://sonarqube:9000"
    SONAR_TOKEN: "${SONAR_TOKEN}"
  script:
    - sonar-scanner -Dsonar.projectKey=my-project
  allow_failure: true
  tags: [local, docker]
```

### Example MR Comment

Once the pipeline completes, the runner's `review:summary` job prints a summary table in the job log:

```
═══════════════════════════════════════════
  Auto Code Review Summary
═══════════════════════════════════════════

📋 Pipeline: http://gitlab.local:8080/root/demo/-/pipelines/12
🌿 Branch:   feature/new-endpoint
📝 Commit:   a3f8b1c

✅ All review jobs finished. Check the artifacts:
   • ShellCheck   → review-output/shellcheck/
   • Hadolint     → review-output/hadolint/
   • Trivy        → review-output/trivy/
   • Secrets      → review-output/secrets/
```

---

## Step 8: Test Locally Before Pushing to Production

This section describes how to run a complete, isolated CI/CD cycle on your local GitLab stack before pushing any code to the production/original GitLab instance. The local environment mirrors production behavior — including Docker-in-Docker builds, registry pushes, and staging deployments — without affecting any live systems.

### Overview of the Workflow

```
develop locally → commit → push to local GitLab → pipeline runs → inspect results → if OK → push to production
```

### 8.1 Set Up the Local GitLab Project

Once GitLab is running and you have logged in as `root`:

1. Create a new project called `gitlab-demo-project` (or any name you prefer):
   - Click **New Project** → **Create blank project**
   - Visibility: **Internal** (or **Private**)
   - Do NOT initialize with a README yet (we will push our own content)

2. Get the runner registration token (if not auto-registered):
   - Go to **Menu → Admin Area → Overview → Runners**
   - Copy the **Registration Token** shown under "Set up a specific Runner manually"

3. Update your `.env` file with the token:

   ```bash
   cp env.example .env
   # Edit .env and set:
   GITLAB_RUNNER_REGISTRATION_TOKEN="<your-token>"
   ```

4. Start (or restart) the full stack so the runner registers:

   ```bash
   ./scripts/run-lab.sh 2
   ```

5. Verify the runner appears in **Admin Area → Overview → Runners** — you should see a runner tagged `local, docker`.

### 8.2 Push the Demo Project to the Local GitLab

```bash
cd gitlab-demo-project

# Initialize git (if not already initialized)
git init

# Configure git identity (use any values — this is local only)
git config user.name  "Local Dev"
git config user.email "dev@gitlab.local"

# Add the local GitLab as origin
git remote add origin http://gitlab.local:8080/root/gitlab-demo-project.git

# Stage all files
git add .

# Initial commit
git commit -m "feat: initial demo project setup"

# Push to local GitLab
git push -u origin main
# When prompted for credentials:
#   Username: root
#   Password: <your GitLab password or a personal access token>
```

To generate a personal access token for password-less pushes:

1. In GitLab UI: **User Settings → Access Tokens**
2. Name: `local-push`, Scope: `write_repository`
3. Copy the token and use it as the password above.

### 8.3 Configure CI/CD Variables (Required for Build and Deploy Stages)

Before the pipeline can run all three stages, you need to set project-level CI/CD variables:

1. In GitLab UI, go to **Project → Settings → CI/CD → Variables**
2. Add the following variables:

| Variable | Value | Options |
|---|---|---|
| `CI_REGISTRY_USER` | `root` | Protected: No |
| `CI_REGISTRY_PASSWORD` | `<your-password-or-token>` | Protected: No |
| `SSH_PRIVATE_KEY` | *(leave empty for local-only testing)* | — |
| `DEPLOY_HOST` | `deploy-test` | Protected: No |

> **Note:** For the **build** stage to push to the local registry (`gitlab.local:5050`), the `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` variables must match your GitLab login credentials.

### 8.4 Option A: Test the Build Stage Only (Simplest)

If you only want to verify the Docker build and registry push without a real deploy target:

1. In `.gitlab-ci.yml`, comment out the `deploy:staging` job temporarily.
2. Push a new commit:

   ```bash
   git add .gitlab-ci.yml
   git commit -m "chore: test build stage only"
   git push
   ```

3. Watch the pipeline at **Project → Pipelines**. You should see:
   - `test:app` → green
   - `build:docker` → green (image pushed to `gitlab.local:5050`)

4. Verify the image exists in the local registry:

   ```bash
   docker login -u root -p '<password>' gitlab.local:5050
   curl -s http://gitlab.local:5050/v2/_catalog | jq .
   ```

### 8.5 Option B: Test the Full Pipeline (Build + Deploy)

To test all three stages including deployment, set up a local deploy target:

```bash
# Spin up a disposable container that acts as a "staging server"
docker run -d \
  --name deploy-test \
  --network gitlab-net \
  -p 9090:80 \
  --restart unless-stopped \
  nginx:alpine
```

Set `DEPLOY_HOST=deploy-test` in the CI/CD variables (as shown in the table above).

Now push a commit — the full pipeline will:

1. **test** – run checks
2. **build** – build and push the Docker image to `gitlab.local:5050`
3. **deploy** – SSH into `deploy-test` (if SSH is configured), pull, and restart the container

To verify the deploy worked:

```bash
# Check if the new image is running
curl http://localhost:9090/health
```

### 8.6 Iterative Development Loop

For ongoing development, follow this cycle:

```bash
# 1. Make code changes
vim app.py  # (or any file)

# 2. Commit on a feature branch
git checkout -b feature/my-change
git add .
git commit -m "fix: resolve issue in X"

# 3. Push to local GitLab to trigger the pipeline
git push origin feature/my-change

# 4. Watch the pipeline in the UI:
#    http://gitlab.local:8080/root/gitlab-demo-project/-/pipelines

# 5. If pipeline passes → create a Merge Request locally
#    (GitLab UI: Merge Requests → New Merge Request)
#    Review the diff, merge into main, then push to production

# 6. When satisfied with local results, push to the real GitLab
git remote add production https://gitlab.com/your-org/your-project.git
git push production feature/my-change
```

### 8.7 Simulate a Production-Like Environment

To make local testing even more realistic:

- **Use a separate Docker Compose override** for staging: `stacks/gitlab/docker-compose.staging.yml`
- **Mirror environment variables** from your production GitLab CI/CD settings
- **Test `.gitlab-ci.yml` templates** before committing them to the main repository

### 8.8 Compare Local vs. Production Pipeline Results

After running pipelines in both environments, compare:

| Check | Local GitLab | Production GitLab |
|---|---|---|
| Build time | `gitlab-runner` logs | Production runner logs |
| Image tag | `${CI_COMMIT_SHA}` | Same format |
| Registry | `gitlab.local:5050` | `registry.gitlab.com` |
| Deploy target | `deploy-test` | Staging/production server |
|.tfstate | Local project | Remote project |

---

## Step 9: Pipeline Troubleshooting Checklist

When the local pipeline fails, work through this checklist in order. Each item is followed by the exact command(s) to verify the state. Most issues are caused by a few recurring root causes — start from the top.

### 9.1 Pre-flight: Verify the Stack is Healthy

Before debugging a specific job, confirm that the foundation is solid.

```bash
# 1. All GitLab containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "gitlab"

# 2. GitLab web UI is reachable
curl -sf http://gitlab.local:8080/-/health
# Expected: "GitLab OK" or HTTP 200

# 3. GitLab API responds
curl -sf http://gitlab.local:8080/api/v4/version

# 4. Registry responds
curl -sf http://gitlab.local:5050/v2/

# 5. Runner is registered and online
docker exec gitlab-runner gitlab-runner list
# Expected output: a runner with status "online"
```

If any of these fail, fix the foundation first — re-read **Step 2** and **Step 4**.

### 9.2 Job Status: "pending" Forever (Runner Never Picks Up)

**Symptoms:** Pipeline shows the job with a yellow dot that never becomes green or red.

**Checklist:**

1. **Runner is online in GitLab UI**
   - `Admin Area → Overview → Runners` → look for a green dot.
   - If red, restart it: `docker restart gitlab-runner`.

2. **Runner has tags matching the job**
   - The job has `tags: [local, docker]`. The registered runner must have at least one of these.
   - Inspect:
     ```bash
     docker exec gitlab-runner cat /etc/gitlab-runner/config.toml | grep -A2 "\[runners"
     ```
   - If tags are missing, re-register with option 3 of `run-lab.sh`.

3. **Runner is not paused or locked**
   - In GitLab UI: **Admin Area → Runners → click the runner → verify "Paused" is off and "Locked to this project" matches the repo**.

4. **Job-level "Run untagged jobs"** is enabled on the runner.

### 9.3 Build Stage Fails: "permission denied" on /var/run/docker.sock

**Symptoms:** Job log contains:
```
ERROR: permission denied while trying to connect to the Docker daemon socket
```

**Fixes:**

```bash
# 1. Verify the socket is mounted into the runner container
docker inspect gitlab-runner | grep -A2 "Source.*docker.sock"

# 2. On the HOST, ensure your user is in the docker group
sudo usermod -aG docker $USER
# Then log out and back in (or run: newgrp docker)

# 3. Confirm the socket is readable
ls -la /var/run/docker.sock
# Should be: srw-rw---- 1 root docker ... /var/run/docker.sock

# 4. Restart the runner after fixing permissions
docker restart gitlab-runner
```

### 9.4 Build Stage Fails: Cannot Push to `gitlab.local:5050`

**Symptoms:** Job log contains:
```
denied: requested access to the resource is denied
```
or
```
Error response from daemon: Get "https://gitlab.local:5050/v2/": dial tcp: lookup gitlab.local: no such host
```

**Checklist:**

1. **DNS resolution inside the build container**
   The `docker build` step uses `--network gitlab-net`, so DNS should work. Verify:
   ```bash
   docker run --rm --network gitlab-net alpine nslookup gitlab.local
   ```

2. **Registry credentials in CI variables**
   - Project → Settings → CI/CD → Variables
   - `CI_REGISTRY_USER` = `root`
   - `CI_REGISTRY_PASSWORD` = your GitLab password or a token with `api` scope

3. **Registry is actually enabled**
   ```bash
   docker exec gitlab-ce gitlab-rails console -e production <<< "puts Gitlab::Registry.config.enabled"
   # Expected: true
   ```

4. **Image tag format**
   The pipeline tags as `${REGISTRY_IMAGE}:${CI_COMMIT_SHA}`. If `CI_PROJECT_PATH` is empty (e.g., the project lives under a group), the tag becomes `gitlab.local:5050/:sha256...`. Add a project-level CI/CD variable:
   - `PROJECT_PATH = root/gitlab-demo-project`

5. **Manual login test from the runner**
   ```bash
   docker exec -it gitlab-runner sh
   docker login -u root -p '<password>' gitlab.local:5050
   docker push gitlab.local:5050/root/gitlab-demo-project:test
   ```

### 9.5 Deploy Stage Fails: SSH Connection Refused

**Symptoms:** Job log contains:
```
ssh: connect to host <DEPLOY_HOST> port 22: Connection refused
```

**Checklist:**

1. **The deploy target container is running**
   ```bash
   docker ps | grep deploy-test
   ```
   If absent, recreate it:
   ```bash
   docker run -d --name deploy-test --network gitlab-net -p 9090:80 nginx:alpine
   ```

2. **`DEPLOY_HOST` resolves from inside the build container**
   ```bash
   docker run --rm --network gitlab-net alpine getent hosts deploy-test
   ```
   If empty, the build container is not on `gitlab-net`. Either:
   - Add the runner to `gitlab-net`, or
   - Set `DEPLOY_HOST=gitlab.local` in CI/CD variables and use the GitLab host as the SSH endpoint.

3. **SSH is actually running on the target**
   The simple `nginx:alpine` container does NOT run sshd. Either:
   - Use a different test target (e.g., `linuxserver/openssh-server`):
     ```bash
     docker run -d --name deploy-test --network gitlab-net \
       -e USER_NAME=root -e USER_PASSWORD=rootpass \
       -p 2223:2222 lscr.io/linuxserver/openssh-server:latest
     ```
   - Or skip the deploy stage for local testing (see **Step 8.4**).

### 9.6 Test Stage Fails: "Connection refused" on localhost

**Symptoms:** `curl http://localhost:8080/health` fails inside the test job.

This is normal — the test job is running in an isolated container, not on the host network. Either:

- Replace the curl target with a placeholder test, or
- Run the test as a `services:` entry in the CI job so they share a network.

The default test stage is intentionally tolerant:
```yaml
- curl -s http://localhost:8080/health || true
```

### 9.7 Pipeline Fails Immediately: "Invalid CI configuration"

**Symptoms:** Red banner on the pipeline page: "Pipeline cannot be created because of syntax error in .gitlab-ci.yml".

**Fixes:**

1. Validate the file locally with GitLab's CLI or an online linter:
   ```bash
   # Using Docker:
   docker run --rm -v "$PWD/.gitlab-ci.yml:/yaml:ro" \
     registry.gitlab.com/gitlab-org/cli:latest glab ci lint /yaml
   ```

2. Common mistakes to check:
   - Inconsistent indentation (must be 2 spaces).
   - Missing colon after `image:`, `script:`, etc.
   - Typos in job names (job names must be unique).
   - `extends:` referring to a job that doesn't exist.

### 9.8 Runner Cannot Pull the `docker:24-dind` Image

**Symptoms:** Job stuck on "Preparing the 'docker' executor" or "image not found".

**Fixes:**

1. **Network access** — the runner needs to pull from Docker Hub. If behind a corporate proxy, configure the runner:
   ```toml
   # /etc/gitlab-runner/config.toml on the host
   [runners.docker]
     network_mode = "gitlab-net"
     extra_hosts = ["gitlab.local:gitlab"]
   ```
   Plus HTTP_PROXY env vars on the runner container.

2. **Pre-pull the image manually:**
   ```bash
   docker pull docker:24-dind
   ```

3. **Use a different image mirror** by setting `image: <your-registry>/docker:24-dind` in `.gitlab-ci.yml`.

### 9.9 Pipeline Runs But No Image in the Registry

**Symptoms:** Build stage shows green, but the image is missing from the registry UI or `/v2/_catalog`.

**Checklist:**

1. **The push step actually executed** — look for `docker push` lines in the job log.
2. **Wrong registry path** — `gitlab.local:5050` (host) is correct; `localhost:5050` (from inside a job container) is NOT.
3. **Check the registry catalog:**
   ```bash
   curl -s -u root:'<password>' http://gitlab.local:5050/v2/_catalog | jq .
   curl -s -u root:'<password>' http://gitlab.local:5050/v2/<project-path>/tags/list | jq .
   ```

### 9.10 "Out of Memory" or Container Restarts During Build

**Symptoms:** GitLab or runner containers restart mid-build; jobs are killed with exit code 137.

**Fixes:**

- **Increase Docker Desktop memory** to at least 4 GB (GitLab) + 2 GB (runner) = 6 GB total.
- **Reduce resource usage** by lowering `PUMA_WORKERS` and `SIDEKIQ_CONCURRENCY` in `.env` (already set to 2 and 10).
- **Disable unused services** by setting `PROMETHEUS_ENABLED=false` (already the default).
- **Limit DinD memory** in `.gitlab-ci.yml`:
  ```yaml
  services:
    - name: docker:24-dind
      command: ["--storage-driver=overlay2"]
  ```

### 9.11 Quick Diagnostic Script

A standalone version of this script lives at `scripts/diagnose.sh` and covers all checks in this section automatically. Run it with:

```bash
# Full diagnostic (all 12 checks)
./scripts/diagnose.sh

# Quick check only (containers + health endpoints)
./scripts/diagnose.sh --quick

# Attempt automatic fixes
./scripts/diagnose.sh --fix

# Nuclear reset (destroys all data, prompts for confirmation)
./scripts/diagnose.sh --reset

# Help
./scripts/diagnose.sh --help
```

What it checks automatically:

| Check | Description |
|---|---|
| 9.1 | Container status (gitlab-ce, gitlab-runner, deploy-test, gitlab-net) |
| 9.2 | GitLab web health endpoint |
| 9.3 | GitLab API `/api/v4/version` response |
| 9.4 | Container Registry reachability |
| 9.5 | Runner process aliveness and registration |
| 9.6 | Runner tags, locked/paused status |
| 9.7 | Docker socket permissions and docker-group membership |
| 9.8 | Registry DNS resolution and push access |
| 9.9 | Deploy target status and SSH availability |
| 9.10 | `.gitlab-ci.yml` YAML syntax validation |
| 9.11 | DinD image pre-pull status |
| 9.12 | System memory, disk, and Docker disk usage |

### 9.12 Nuclear Option: Full Reset

If everything is broken and you just want a clean slate:

```bash
# 1. Stop and remove everything (including volumes)
docker-compose -f docker-compose.yml -f stacks/gitlab/docker-compose.yml down -v

# 2. Remove local volume directories
rm -rf volumes/

# 3. Remove the runner config (forces re-registration)
rm -rf stacks/gitlab/runner-config stacks/gitlab/runner-cache

# 4. Start fresh
./scripts/run-lab.sh 2
```

> **Warning:** Step 1 and 2 destroy ALL GitLab data, including projects, users, and registered runners. Use only when truly necessary.

---

## Cleanup

To stop and remove all containers:

```bash
# Stop all services
docker-compose -f docker-compose.yml -f stacks/gitlab/docker-compose.yml down

# Remove volumes (WARNING: destroys all GitLab data)
docker-compose -f docker-compose.yml -f stacks/gitlab/docker-compose.yml down -v

# Remove images (optional)
docker rmi gitlab/gitlab-ce:latest gitlab/gitlab-runner:latest
```

---

## Troubleshooting

### GitLab takes too long to start

GitLab can take 5–10 minutes to start for the first time. Check the logs:

```bash
docker logs -f gitlab-ce
```

If it fails, increase memory (4 GB recommended) and ensure ports 8080, 5050, and 2222 are free.

### Runner is not registering

1. Check the runner logs:

   ```bash
   docker logs -f gitlab-runner
   ```

2. Ensure GitLab is healthy:

   ```bash
   curl http://gitlab.local:8080/api/v4/version
   ```

3. Verify the runner token is set in `.env`.

### Cannot push to repository

1. Ensure you are using the correct remote URL:

   ```bash
   git remote -v
   ```

2. Check your GitLab credentials:

   ```bash
   git config user.name "Your Name"
   git config user.email "you@example.com"
   ```

3. Use a personal access token for HTTPS:

   ```bash
   git remote set-url origin http://gitlab.local:8080/root/gitlab-demo-project.git
   # Then push with token:
   # git push https://gitlab.local:8080/root/gitlab-demo-project.git
   ```

### Pipeline fails with "docker not found"

The runner needs Docker-in-Docker (DinD). Ensure the `docker:dind` service is running and the runner has access to the Docker socket.

Check the runner's `config.toml`:

```bash
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml
```

---

## References

- [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)
- [GitLab Runner Docker executor](https://docs.gitlab.com/runner/executors/docker.html)
- [Terraform GitLab Backend](https://developer.hashicorp.com/terraform/language/settings/backends/http)
- [GitLab CI/CD documentation](https://docs.gitlab.com/ee/ci/)

---

**Happy coding!** 🚀
