# GitLab CI/CD Pipeline Setup Guide for PicoCluster

Complete guide for implementing Continuous Integration and Continuous Deployment on your PicoCluster.

## Overview

GitLab CI/CD automates testing, building, and deploying applications on every code change.

### CI/CD Pipeline Workflow

```
Developer commits code
        ↓
Pushes to GitLab repository
        ↓
GitLab detects .gitlab-ci.yml
        ↓
Creates pipeline with defined jobs
        ↓
GitLab Runner picks up job
        ↓
Executes build/test/deploy steps
        ↓
Reports results back to GitLab
        ↓
Merge request passes/fails checks
        ↓
Merge or reject PR based on results
```

### Why CI/CD?

- **Automated Testing**: Catch bugs before merge
- **Faster Feedback**: Minutes instead of hours
- **Consistent Deployments**: Same process every time
- **Reduced Manual Work**: Automation handles repetitive tasks
- **Audit Trail**: Complete history of changes
- **Quality Gates**: Only good code makes it to production

## Quick Start

### Step 1: Install GitLab Runner

```bash
# Install and configure runner
ansible-playbook infrastructure/cicd/install_gitlab_runner.ansible
```

Runner will:
- Install gitlab-runner service
- Configure Docker executor
- Be ready for CI/CD jobs

### Step 2: Register Runner with GitLab

```bash
# Get registration token from GitLab:
# Go to Admin → Runners or Project → Settings → CI/CD → Runners

sudo gitlab-runner register \
  --url https://gitlab.example.com/ \
  --registration-token <token> \
  --executor docker \
  --docker-image ubuntu:latest \
  --description "PicoCluster Runner"
```

### Step 3: Create Pipeline Configuration

Create `.gitlab-ci.yml` in repository root:

```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  script:
    - make test
  tags:
    - docker

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t myapp:latest .
  tags:
    - docker

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/myapp myapp=myapp:latest
  tags:
    - kubernetes
```

### Step 4: Commit and Push

```bash
git add .gitlab-ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

Pipeline automatically starts! Monitor in GitLab UI.

## Pipeline Configuration

### .gitlab-ci.yml Structure

```yaml
# Define execution stages
stages:
  - test
  - build
  - deploy

# Global variables
variables:
  DOCKER_DRIVER: overlay2

# Global image (can override per job)
image: ubuntu:latest

# Job definition
test-job:
  stage: test
  image: ubuntu:latest
  script:
    - make test
  tags:
    - docker
  only:
    - main
```

### Jobs and Stages

**Stages**: Groups of jobs that run sequentially
- All jobs in stage 1 complete before stage 2 starts
- If any job fails, dependent stages don't run

**Jobs**: Individual tasks within a stage
- Run in parallel within same stage
- Can be on different runners (using tags)

Example:

```yaml
stages:
  - test      # Stage 1
  - build     # Stage 2
  - deploy    # Stage 3

# These run in parallel in test stage
unit_test:
  stage: test
  script: pytest

lint:
  stage: test
  script: pylint

# Only runs after test stage completes
build:
  stage: build
  script: make build

# Only runs after build stage completes
deploy:
  stage: deploy
  script: kubectl apply -f deployment.yaml
```

### Job Configuration

```yaml
my-job:
  stage: build
  image: ubuntu:latest          # Job-specific image
  tags:
    - docker                    # Runner must have this tag
  script:
    - echo "Building..."
    - make build
  after_script:
    - cleanup
  artifacts:
    paths:
      - dist/                   # Keep these files
    expire_in: 1 week
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - vendor/                 # Cache dependencies
  only:
    - main                      # Only run on main branch
    - /^release\/.*$/           # Or release branches
  except:
    - tags
  retry:
    max: 2
    when: failed                # Retry on failure
  timeout: 1h                   # Job timeout
  allow_failure: true           # Don't fail pipeline
```

### Conditional Execution

```yaml
# Only on specific branches
only:
  - main
  - develop
  - /^hotfix\/.*$/              # Regex patterns

# Exclude branches/tags
except:
  - tags

# Manual trigger
when: manual

# After success
when: on_success

# Even after failure
when: on_failure

# Always run
when: always
```

## Docker Executor Configuration

### Basic Docker Setup

```yaml
image: ubuntu:latest

script:
  - apt-get update
  - apt-get install -y build-essential
  - make build
```

### Docker-in-Docker (DinD)

For building container images:

```yaml
build:image:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t myapp:$CI_COMMIT_SHA .
    - docker push myapp:$CI_COMMIT_SHA
```

### Service Containers

For testing databases, caches:

```yaml
test:database:
  image: ubuntu:latest
  services:
    - postgres:13              # PostgreSQL for tests
    - redis:7                  # Redis for tests
  script:
    - apt-get install -y postgresql-client redis-tools
    - pytest
```

## Variables and Secrets

### Predefined Variables

GitLab provides automatic variables:

```bash
CI_COMMIT_SHA          # Current commit hash
CI_COMMIT_REF_BRANCH   # Current branch name
CI_PROJECT_NAME        # Project name
CI_PROJECT_PATH        # Project path
CI_PIPELINE_ID         # Pipeline ID
CI_JOB_ID              # Job ID
CI_JOB_NAME            # Job name
```

### Custom Variables

Define in `.gitlab-ci.yml`:

```yaml
variables:
  DOCKER_DRIVER: overlay2
  REGISTRY: registry.example.com
  KUBE_NAMESPACE: production
```

### Secret Variables

Store in GitLab project settings:

1. Go to **Settings → CI/CD → Variables**
2. Add variable: `DOCKER_PASSWORD`
3. Mark as **Masked** (hide in logs)
4. Mark as **Protected** (only on protected branches)

Usage in pipeline:

```yaml
script:
  - docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
  - docker push myapp:latest
```

## Artifacts and Caching

### Artifacts

Keep files between jobs:

```yaml
build:
  stage: build
  script:
    - make build
  artifacts:
    paths:
      - dist/
      - build/
    expire_in: 1 week           # Auto-delete after 1 week
    when: always                # Keep even on failure

deploy:
  stage: deploy
  dependencies:
    - build                     # Download build artifacts
  script:
    - kubectl apply -f dist/manifest.yaml
```

### Caching

Speed up builds with dependency caching:

```yaml
variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

cache:
  key:
    files:
      - requirements.txt        # Cache key based on file
  paths:
    - .cache/pip
    - venv/

build:
  stage: build
  cache:
    - key: $CI_COMMIT_REF_SLUG
      paths:
        - node_modules/
  script:
    - npm install               # Cached after first run
    - npm run build
```

## Kubernetes Integration

### Deploy to Kubernetes

```yaml
deploy:production:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config use-context cluster-name
    - kubectl set image deployment/myapp myapp=myapp:$CI_COMMIT_SHA
    - kubectl rollout status deployment/myapp
  environment:
    name: production
    kubernetes:
      namespace: production
    url: https://example.com
  only:
    - main
```

### Kubernetes Context

Configure in **Settings → CI/CD → Kubernetes integration**:

```bash
# Or set via variable
KUBE_CONFIG: <base64-encoded-kubeconfig>
KUBE_URL: https://kubernetes.example.com
KUBE_TOKEN: <token>
KUBE_CA_CERT: <certificate>
```

### Helm Deployments

```yaml
deploy:helm:
  stage: deploy
  image: alpine/helm:latest
  script:
    - helm repo add myrepo https://repo.example.com
    - helm upgrade --install myapp myrepo/myapp
    - helm rollout status deployment/myapp
  only:
    - main
```

## Environments

Track deployments:

```yaml
deploy:staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
    kubernetes:
      namespace: staging
  script:
    - kubectl apply -f staging-deployment.yaml

deploy:production:
  stage: deploy
  environment:
    name: production
    url: https://example.com
    auto_stop_in: 1 week
  script:
    - kubectl apply -f prod-deployment.yaml
```

## Security

### Secure Variables

1. **Don't commit secrets** to repository
2. **Use CI/CD variables** for sensitive data
3. **Mark as masked**: Hides value in logs
4. **Mark as protected**: Only on protected branches
5. **Use separate tokens** for different purposes

### Signing Commits

```yaml
before_script:
  - echo "$GPG_PRIVATE_KEY" | gpg --import
  - git config user.signingkey $GPG_KEY_ID
  - git config commit.gpgsign true
  - git config user.email $GIT_EMAIL
  - git config user.name $GIT_USER
```

### SAST (Static Application Security Testing)

```yaml
sast:
  stage: test
  image: returntocorp/semgrep:latest
  script:
    - semgrep --json --output=report.json .
  artifacts:
    reports:
      sast: report.json
```

## Monitoring and Troubleshooting

### View Pipeline Status

1. Go to **Project → CI/CD → Pipelines**
2. Click pipeline to see job details
3. View logs for each job

### Common Issues

**Runner not picking up jobs:**
```bash
# Check runner status
gitlab-runner status

# Check tags match
# Ensure job has tags: [docker]
# And runner has tag configured
```

**Build failing silently:**
```bash
# Check script output
# Add set -x for verbose output
script:
  - set -x
  - make build
```

**Out of memory/disk:**
```bash
# Check available resources
df -h
free -h

# Configure build limits
# Settings → CI/CD → Runners
```

**Slow builds:**
```bash
# Enable caching
cache:
  paths:
    - node_modules/
    - vendor/

# Use FastZip
FF_USE_FASTZIP=true
```

## Best Practices

### 1. Keep Pipeline Simple

Start small, grow complexity gradually:

```yaml
# Bad: Single job doing everything
test_and_build_and_deploy:
  script:
    - npm test
    - npm run build
    - kubectl apply -f deployment.yaml

# Good: Separate jobs per responsibility
test:
  stage: test
  script: npm test

build:
  stage: build
  script: npm run build

deploy:
  stage: deploy
  script: kubectl apply -f deployment.yaml
```

### 2. Use Matrix/Parallel Builds

Test against multiple versions:

```yaml
test:
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ["14", "16", "18"]
  image: node:$NODE_VERSION
  script:
    - npm test
```

### 3. Cache Dependencies

Significantly speeds up builds:

```yaml
cache:
  key:
    files:
      - package-lock.json    # Different cache per dependency version
  paths:
    - node_modules/
```

### 4. Use When Conditionals

Run jobs selectively:

```yaml
test:heavy:
  stage: test
  when: manual                 # Don't run automatically
  script: npm run test:heavy

test:quick:
  stage: test
  script: npm run test:quick
```

### 5. Set Timeout

Prevent hung jobs:

```yaml
build:
  stage: build
  timeout: 30m                 # Kill after 30 minutes
  script: make build
```

### 6. Artifacts Expiration

Clean up old artifacts:

```yaml
build:
  artifacts:
    paths:
      - dist/
    expire_in: 1 week          # Auto-delete after 1 week
```

## Examples

### Python Project

```yaml
stages:
  - test
  - build

test:
  stage: test
  image: python:3.10
  script:
    - pip install -r requirements.txt
    - pytest
    - pylint *.py

build:
  stage: build
  script:
    - python setup.py sdist bdist_wheel
  artifacts:
    paths:
      - dist/
```

### Node.js Project

```yaml
image: node:18

stages:
  - test
  - build

test:
  stage: test
  cache:
    paths:
      - node_modules/
  script:
    - npm ci
    - npm test
    - npm run lint

build:
  stage: build
  cache:
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
```

### Go Project

```yaml
stages:
  - test
  - build

test:
  stage: test
  image: golang:1.20
  script:
    - go test ./...
    - go vet ./...

build:
  stage: build
  image: golang:1.20
  script:
    - go build -o myapp .
  artifacts:
    paths:
      - myapp
```

## See Also

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Pipeline Syntax Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [Runner Installation](https://docs.gitlab.com/runner/install/)
- [Runner Configuration](https://docs.gitlab.com/runner/configuration/)
- [Pipeline Editor](https://docs.gitlab.com/ee/ci/pipeline_editor.html)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
