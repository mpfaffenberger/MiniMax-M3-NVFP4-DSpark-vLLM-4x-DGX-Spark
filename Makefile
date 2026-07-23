.PHONY: bootstrap validate prepare start setup stop status logs smoke metrics test container-build container-audit container-publish container-install

bootstrap:
	./scripts/bootstrap.sh
validate:
	./scripts/validate.sh
prepare:
	./scripts/prepare-models.sh
start:
	./scripts/start.sh
setup:
	./scripts/start.sh --setup
stop:
	./scripts/stop.sh
status:
	./scripts/status.sh
logs:
	./scripts/logs.sh -f
smoke:
	python3 scripts/smoke.py
metrics:
	python3 scripts/metrics.py
container-build:
	./scripts/build-container.sh
container-audit:
	./scripts/audit-container.sh
container-publish:
	./scripts/publish-container.sh
container-install:
	./scripts/install-container.sh "$(CLUSTER_NODES)"
test: validate bootstrap
