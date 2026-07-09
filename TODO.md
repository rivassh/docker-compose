# TODO

## Completed

* [x] Rearrange directories (fixed typos: promotheus, docker-registery, squach, docker-composer)
* [x] Add contents link to README
* [x] Remove hardcoded secrets from all docker-compose files
* [x] Fix .gitignore to cover .env.prod, .env.dev, *.key, *.pem
* [x] Add restart policies to all services
* [x] Fix broken healthcheck in hopscotch
* [x] Remove atlassian-agent.jar from Jira Dockerfile
* [x] Remove SSL private key from repo
* [x] Fix Jenkins privileged mode
* [x] Add LICENSE file
* [x] Add pre-commit hook for secret detection
* [x] Remove deprecated version directives
* [x] Add set -e to shell scripts
* [x] Fix directory naming (Readme.md -> README.md)

## Remaining

* [ ] Add health checks to all services (80%+ still missing)
* [ ] Move vendored projects (airbyte, sentry, chatwoot, iredmail) to git submodules
* [ ] Enforce TLS on nginx configurations
* [ ] Add CI/CD pipeline for the repo itself
* [ ] Add CONTRIBUTING.md
* [ ] Complete README entries for all projects

# RoadMap

## integration flows

* cached storages
* share network
* make file

## resource management

## Load Test 

## Orchestration/Virtualization Section

* repo link
* openshift
* openstack
* esxi
* kubernetes
* Swarm
