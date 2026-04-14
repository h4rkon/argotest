PORT_FORWARD_DIR := .port-forward

.PHONY: port-forward-open port-forward-check port-forward-close call-services

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
		rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
		nohup kubectl -n $(NAMESPACE) port-forward svc/$(SERVICE) $(LOCAL_PORT):80 >"$(PORT_FORWARD_DIR)/$(NAME).log" 2>&1 & echo $$! >"$(PORT_FORWARD_DIR)/$(NAME).pid"; \
		sleep 1; \
		if kill -0 "$$(cat "$(PORT_FORWARD_DIR)/$(NAME).pid")" 2>/dev/null && lsof -nP -iTCP:$(LOCAL_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
			echo "started $(NAME) on localhost:$(LOCAL_PORT)"; \
		else \
			echo "failed to start $(NAME) on localhost:$(LOCAL_PORT)"; \
			if [ -f "$(PORT_FORWARD_DIR)/$(NAME).log" ]; then cat "$(PORT_FORWARD_DIR)/$(NAME).log"; fi; \
			rm -f "$(PORT_FORWARD_DIR)/$(NAME).pid"; \
			exit 1; \
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
