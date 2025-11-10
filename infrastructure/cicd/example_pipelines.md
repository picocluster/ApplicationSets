# GitLab CI/CD Pipeline Examples for PicoCluster

Ready-to-use `.gitlab-ci.yml` examples for common use cases.

## 1. Basic Testing Pipeline

For applications with unit tests:

```yaml
stages:
  - test
  - build

image: ubuntu:latest

test:unit:
  stage: test
  tags:
    - docker
  script:
    - apt-get update && apt-get install -y build-essential
    - make test
  artifacts:
    reports:
      junit: test-results.xml

build:dist:
  stage: build
  script:
    - make build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week
  only:
    - main
```

## 2. Docker Build and Push Pipeline

For containerized applications:

```yaml
stages:
  - build
  - push

variables:
  REGISTRY: registry.example.com
  IMAGE_NAME: $REGISTRY/myapp
  DOCKER_DRIVER: overlay2

build:image:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  tags:
    - docker
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
  artifacts:
    paths:
      - .docker-build-success
  only:
    - main
    - /^release\/.*$/

push:image:
  stage: push
  image: docker:latest
  services:
    - docker:dind
  tags:
    - docker
  script:
    - docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $REGISTRY
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker push $IMAGE_NAME:latest
  only:
    - main
```

## 3. Kubernetes Deployment Pipeline

For automatic deployments to K8s:

```yaml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  REGISTRY: registry.example.com
  IMAGE_NAME: $REGISTRY/myapp

test:
  stage: test
  image: ubuntu:latest
  tags:
    - docker
  script:
    - apt-get update && apt-get install -y golang-go
    - go test ./...

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  tags:
    - docker
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
  only:
    - main

deploy:production:
  stage: deploy
  image: bitnami/kubectl:latest
  tags:
    - kubernetes
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/myapp -n production
  environment:
    name: production
    kubernetes:
      namespace: production
  only:
    - main

deploy:staging:
  stage: deploy
  image: bitnami/kubectl:latest
  tags:
    - docker
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n staging
    - kubectl rollout status deployment/myapp -n staging
  environment:
    name: staging
  when: manual
```

## 4. Manifest Validation Pipeline

For validating Kubernetes manifests and Kustomizations:

```yaml
stages:
  - validate
  - scan

image: ubuntu:latest

validate:manifests:
  stage: validate
  tags:
    - docker
  before_script:
    - curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v4.5.7/kustomize_v4.5.7_linux_amd64.tar.gz | tar xz
    - mv kustomize /usr/local/bin/
    - apt-get update && apt-get install -y wget
    - wget -q https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
    - tar xf kubeval-linux-amd64.tar.gz && mv kubeval /usr/local/bin/
  script:
    - kustomize build clusters/production > /tmp/manifests.yaml
    - kubeval /tmp/manifests.yaml
    - kustomize build clusters/development > /tmp/manifests-dev.yaml
    - kubeval /tmp/manifests-dev.yaml

scan:security:
  stage: scan
  tags:
    - docker
  before_script:
    - apt-get update && apt-get install -y wget
    - wget -q https://github.com/aquasecurity/trivy/releases/download/v0.35.0/trivy_0.35.0_Linux-64bit.tar.gz
    - tar xf trivy_0.35.0_Linux-64bit.tar.gz && mv trivy /usr/local/bin/
  script:
    - trivy config clusters/ --exit-code 0 --no-progress --format json --output report.json
  artifacts:
    reports:
      sast: report.json
  allow_failure: true
```

## 5. Documentation Generation Pipeline

For auto-generating documentation:

```yaml
stages:
  - generate
  - publish

variables:
  DOCS_PATH: docs/

generate:docs:
  stage: generate
  image: pandoc/core:latest
  tags:
    - docker
  script:
    - mkdir -p $DOCS_PATH
    - pandoc README.md -o $DOCS_PATH/index.html
    - find . -name "*.md" -type f | xargs -I {} pandoc {} -o $DOCS_PATH/{}.html
  artifacts:
    paths:
      - $DOCS_PATH/
    expire_in: 30 days

pages:
  stage: publish
  dependencies:
    - generate:docs
  script:
    - mkdir -p public
    - cp -r $DOCS_PATH/* public/
  artifacts:
    paths:
      - public
  only:
    - main
```

## 6. Helm Chart Testing Pipeline

For Helm chart validation:

```yaml
stages:
  - lint
  - test
  - deploy

image: alpine/helm:latest

lint:chart:
  stage: lint
  tags:
    - docker
  script:
    - helm lint ./helm/myapp
    - helm template myapp ./helm/myapp > /tmp/rendered.yaml
    - kubeval /tmp/rendered.yaml

test:chart:
  stage: test
  tags:
    - kubernetes
  script:
    - helm install test-release ./helm/myapp --debug --namespace test
    - kubectl rollout status deployment/myapp -n test
    - helm uninstall test-release -n test

deploy:chart:
  stage: deploy
  tags:
    - kubernetes
  script:
    - helm upgrade --install myapp ./helm/myapp -n production
  environment:
    name: production
  only:
    - main
```

## 7. Multi-Environment Pipeline

For managing dev/staging/production:

```yaml
stages:
  - build
  - test
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  REGISTRY: registry.example.com
  IMAGE_NAME: $REGISTRY/myapp

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  tags:
    - docker
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA

test:
  stage: test
  image: ubuntu:latest
  tags:
    - docker
  script:
    - apt-get update && apt-get install -y python3-pytest
    - pytest tests/

deploy:dev:
  stage: deploy-dev
  image: alpine/kubectl:latest
  tags:
    - kubernetes
  environment:
    name: development
    url: https://dev.example.com
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n dev

deploy:staging:
  stage: deploy-staging
  image: alpine/kubectl:latest
  tags:
    - kubernetes
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n staging
  when: manual

deploy:production:
  stage: deploy-prod
  image: alpine/kubectl:latest
  tags:
    - kubernetes
  environment:
    name: production
    url: https://example.com
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/myapp -n production
  when: manual
  only:
    - main
```

## 8. GitOps Trigger Pipeline

For triggering Flux synchronization:

```yaml
stages:
  - validate
  - commit
  - trigger-sync

validate:flux:
  stage: validate
  image: ubuntu:latest
  tags:
    - docker
  before_script:
    - apt-get update && apt-get install -y curl
    - curl -L https://github.com/fluxcd/flux2/releases/download/v0.40.0/flux_linux_amd64.tar.gz | tar xz
    - mv flux /usr/local/bin/
  script:
    - flux build kustomization flux-system --path ./clusters/production
    - flux build kustomization flux-system --path ./clusters/development

commit:changes:
  stage: commit
  image: alpine/git:latest
  tags:
    - docker
  script:
    - git config user.name "GitLab CI"
    - git config user.email "ci@example.com"
    - git commit -m "CI: Update manifests [skip ci]" || true
    - git push origin $CI_COMMIT_BRANCH
  only:
    - main

trigger:flux:
  stage: trigger-sync
  image: alpine/curl:latest
  tags:
    - docker
  script:
    - |
      curl -X POST http://flux-reconciliation-webhook:8080/sync \
        -H "Content-Type: application/json" \
        -d '{"repository": "cluster-config", "branch": "'$CI_COMMIT_BRANCH'"}'
  only:
    - main
```

## 9. Security Scanning Pipeline

For comprehensive security checks:

```yaml
stages:
  - scan

variables:
  REGISTRY: registry.example.com

scan:sast:
  stage: scan
  image: returntocorp/semgrep:latest
  tags:
    - docker
  script:
    - semgrep --config=p/owasp-top-ten --json --output=sast-report.json .
  artifacts:
    reports:
      sast: sast-report.json
  allow_failure: true

scan:dependency:
  stage: scan
  image: owasp/dependency-check:latest
  tags:
    - docker
  script:
    - /usr/share/dependency-check/bin/dependency-check.sh --project "MyApp" --scan . --format JSON --out report.json
  artifacts:
    reports:
      dependency_scanning: report.json
  allow_failure: true

scan:container:
  stage: scan
  image: aquasec/trivy:latest
  tags:
    - docker
  script:
    - trivy image --severity HIGH,CRITICAL $REGISTRY/myapp:$CI_COMMIT_SHA
  allow_failure: true
```

## 10. Performance Testing Pipeline

For automated performance testing:

```yaml
stages:
  - build
  - deploy
  - test
  - report

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  tags:
    - docker
  script:
    - docker build -t myapp:$CI_COMMIT_SHA .
    - docker push myapp:$CI_COMMIT_SHA

deploy:performance:
  stage: deploy
  image: bitnami/kubectl:latest
  tags:
    - kubernetes
  script:
    - kubectl set image deployment/myapp-perf myapp=myapp:$CI_COMMIT_SHA -n performance
    - kubectl rollout status deployment/myapp-perf -n performance

test:performance:
  stage: test
  image: grafana/k6:latest
  tags:
    - docker
  script:
    - k6 run --vus 100 --duration 30s performance-test.js
  allow_failure: true

test:load:
  stage: test
  image: grafana/k6:latest
  tags:
    - docker
  script:
    - k6 run --vus 500 --duration 60s load-test.js
  allow_failure: true

report:metrics:
  stage: report
  image: ubuntu:latest
  tags:
    - docker
  script:
    - apt-get update && apt-get install -y curl jq
    - curl http://prometheus:9090/api/v1/query?query=http_request_duration_seconds
  allow_failure: true
```

## Common Variables and Secrets

```yaml
# In GitLab project: Settings → CI/CD → Variables

DOCKER_USERNAME: your-registry-username
DOCKER_PASSWORD: your-registry-password  # Mark as masked
KUBECTL_CONFIG: <base64-encoded-kubeconfig>  # Mark as masked
DEPLOY_KEY: <deploy-key>  # Mark as masked
REGISTRY: registry.example.com
KUBE_NAMESPACE: production
```

## Best Practices

1. **Use specific tags**: Match runner tags in jobs
2. **Set timeouts**: Prevent hung jobs
3. **Cache dependencies**: Speed up builds
4. **Use environments**: Track deployments
5. **Mask secrets**: Hide sensitive data in logs
6. **Parallel stages**: Run jobs concurrently
7. **Artifacts**: Keep build outputs
8. **Conditions**: Use only/except for selective execution

## See Also

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Pipeline Syntax Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [Pipeline Editor](https://docs.gitlab.com/ee/ci/pipeline_editor.html)
