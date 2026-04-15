PORT_FORWARD_DIR := .port-forward

.PHONY: port-forward-open port-forward-check port-forward-close call-services feature-open feature-check feature-close call-feature _require-feature-name

port-forward-open:
	mkdir -p $(PORT_FORWARD_DIR)
	@$(MAKE) _start-port-forward NAME=servicea-develop NAMESPACE=develop SERVICE=servicea LOCAL_PORT=18081
	@$(MAKE) _start-port-forward NAME=serviceb-develop NAMESPACE=develop SERVICE=serviceb LOCAL_PORT=18082
	@$(MAKE) _start-port-forward NAME=servicea-main NAMESPACE=main SERVICE=servicea LOCAL_PORT=18083
	@$(MAKE) _start-port-forward NAME=serviceb-main NAMESPACE=main SERVICE=serviceb LOCAL_PORT=18084
	@$(MAKE) port-forward-check

_start-port-forward:
	@if [ -f "$(PORT_FORWARD_DIR)/$(NAME).pid" ] && kill -0 "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null; then \
		echo "$(NAME) already running on localhost:$(LOCAL_PORT)"; \
	else \
		existing_pid="$$(lsof -tiTCP:$(LOCAL_PORT) -sTCP:LISTEN 2>/dev/null | head -n1)"; \
		if [ -n "$$existing_pid" ]; then \
			existing_cmd="$$(ps -p "$$existing_pid" -o command= 2>/dev/null)"; \
			case "$$existing_cmd" in \
				*kubectl*"-n $(NAMESPACE) port-forward svc/$(SERVICE) $(LOCAL_PORT):80"*) \
					echo "$$existing_pid" >"$(PORT_FORWARD_DIR)/$(NAME).pid"; \
					echo "$(NAME) already running on localhost:$(LOCAL_PORT)"; \
					;; \
				*) \
					echo "port $(LOCAL_PORT) is already in use by pid $$existing_pid"; \
					echo "$$existing_cmd"; \
					exit 1; \
					;; \
			esac; \
		else \
			rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
			started=0; \
			for attempt in 1 2 3; do \
				nohup kubectl -n $(NAMESPACE) port-forward svc/$(SERVICE) $(LOCAL_PORT):80 >"$(PORT_FORWARD_DIR)/$(NAME).log" 2>&1 & echo $$! >"$(PORT_FORWARD_DIR)/$(NAME).pid"; \
				for _ in 1 2 3 4 5; do \
					if kill -0 "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null && lsof -nP -iTCP:$(LOCAL_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
						started=1; \
						break; \
					fi; \
					sleep 1; \
				done; \
				if [ "$$started" -eq 1 ]; then \
					break; \
				fi; \
				if [ -f "$(PORT_FORWARD_DIR)/$(NAME).pid" ] && kill -0 "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null; then \
					kill "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null || true; \
				fi; \
				rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
				sleep 1; \
			done; \
			if [ "$$started" -eq 1 ]; then \
				echo "started $(NAME) on localhost:$(LOCAL_PORT)"; \
			else \
				echo "failed to start $(NAME) on localhost:$(LOCAL_PORT)"; \
				if [ -f "$(PORT_FORWARD_DIR)/$(NAME).log" ]; then cat "$(PORT_FORWARD_DIR)/$(NAME).log"; fi; \
				rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
				exit 1; \
			fi; \
		fi; \
	fi

port-forward-check:
	@$(MAKE) _check-port-forward NAME=servicea-develop LOCAL_PORT=18081
	@$(MAKE) _check-port-forward NAME=serviceb-develop LOCAL_PORT=18082
	@$(MAKE) _check-port-forward NAME=servicea-main LOCAL_PORT=18083
	@$(MAKE) _check-port-forward NAME=serviceb-main LOCAL_PORT=18084
	@echo "URLs:"
	@echo "  http://localhost:18081/hello"
	@echo "  http://localhost:18082/hello"
	@echo "  http://localhost:18083/hello"
	@echo "  http://localhost:18084/hello"

_check-port-forward:
	@if [ -f "$(PORT_FORWARD_DIR)/$(NAME).pid" ] && kill -0 "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null; then \
		echo "$(NAME): running on localhost:$(LOCAL_PORT) (pid $$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid"))"; \
	else \
		echo "$(NAME): not running"; \
	fi

port-forward-close:
	@$(MAKE) _stop-port-forward NAME=servicea-develop
	@$(MAKE) _stop-port-forward NAME=serviceb-develop
	@$(MAKE) _stop-port-forward NAME=servicea-main
	@$(MAKE) _stop-port-forward NAME=serviceb-main

call-services:
	@echo "servicea-develop  -> $$(curl -fsS http://localhost:18081/hello || echo 'request failed')"
	@echo "serviceb-develop  -> $$(curl -fsS http://localhost:18082/hello || echo 'request failed')"
	@echo "servicea-main     -> $$(curl -fsS http://localhost:18083/hello || echo 'request failed')"
	@echo "serviceb-main     -> $$(curl -fsS http://localhost:18084/hello || echo 'request failed')"

FEATURE_NAME ?=
FEATURE_PORT_A ?= 28085
FEATURE_PORT_B ?= 28086

feature-open:
	@$(MAKE) _require-feature-name
	@$(MAKE) _start-port-forward NAME=feature-servicea NAMESPACE=$(FEATURE_NAME) SERVICE=servicea LOCAL_PORT=$(FEATURE_PORT_A)
	@$(MAKE) _start-port-forward NAME=feature-serviceb NAMESPACE=$(FEATURE_NAME) SERVICE=serviceb LOCAL_PORT=$(FEATURE_PORT_B)
	@$(MAKE) feature-check

feature-check:
	@$(MAKE) _require-feature-name
	@$(MAKE) _check-port-forward NAME=feature-servicea LOCAL_PORT=$(FEATURE_PORT_A)
	@$(MAKE) _check-port-forward NAME=feature-serviceb LOCAL_PORT=$(FEATURE_PORT_B)
	@echo "Feature URLs (namespace $(FEATURE_NAME)):"
	@echo "  http://localhost:$(FEATURE_PORT_A)/hello"
	@echo "  http://localhost:$(FEATURE_PORT_B)/hello"

feature-close:
	@$(MAKE) _stop-port-forward NAME=feature-servicea
	@$(MAKE) _stop-port-forward NAME=feature-serviceb

call-feature:
	@$(MAKE) _require-feature-name
	@echo "servicea-feature ($(FEATURE_NAME)) -> $$(curl -fsS http://localhost:$(FEATURE_PORT_A)/hello || echo 'request failed')"
	@echo "serviceb-feature ($(FEATURE_NAME)) -> $$(curl -fsS http://localhost:$(FEATURE_PORT_B)/hello || echo 'request failed')"

_require-feature-name:
	@if [ -z "$(FEATURE_NAME)" ]; then \
		echo "FEATURE_NAME is required, e.g. FEATURE_NAME=feature-oas-4715 make feature-open"; \
		exit 1; \
	fi
	
_stop-port-forward:
	@if [ -f "$(PORT_FORWARD_DIR)/$(NAME).pid" ]; then \
		pid="$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")"; \
		if kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid"; \
			echo "stopped $(NAME) (pid $$pid)"; \
		else \
			echo "$(NAME) already stopped"; \
		fi; \
		rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
	else \
		echo "$(NAME): no pid file"; \
	fi
