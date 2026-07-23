.PHONY: bootstrap validate prepare start setup stop status logs smoke metrics test

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
test: validate bootstrap
