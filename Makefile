COMPOSE := docker compose -f docker-compose.dev.yml
SERVICE := web
APP_PORT ?= 3000
APP_URL := http://localhost:$(APP_PORT)

export RAILS_MASTER_KEY ?= $(shell cat config/master.key 2>/dev/null)

SPEC ?=

.PHONY: help build bundle up down restart logs ps status shell console db-setup db-migrate db-reset rubocop rspec test ci clean

help:
	@echo "Development commands (Docker):"
	@echo "  make build       Build the development image"
	@echo "  make bundle      Install gems in Docker (run after Gemfile changes)"
	@echo "  make up          Start db + web in the foreground"
	@echo "  make upd         Start db + web in the background"
	@echo "  make down        Stop and remove containers"
	@echo "  make restart     Restart the web service"
	@echo "  make logs        Follow web logs"
	@echo "  make ps          Show running services"
	@echo "  make status      Check whether the app is reachable"
	@echo "  make shell       Open a bash shell in the web container"
	@echo "  make console     Open a Rails console"
	@echo "  make db-setup    Prepare the development database"
	@echo "  make db-migrate  Run pending migrations"
	@echo "  make db-reset    Reset the development database"
	@echo "  make rubocop     Run RuboCop"
	@echo "  make rspec       Run RSpec (optional: SPEC=path/to/spec.rb)"
	@echo "  make ci          Run rubocop + rspec"
	@echo "  make test        Alias for make rspec"
	@echo "  make clean       Remove containers, volumes, and images"
	@echo ""
	@echo "Optional env vars: APP_PORT (default 3000), DB_PORT (default 5433)"

build:
	$(COMPOSE) build

bundle:
	$(COMPOSE) run --rm $(SERVICE) bundle install

up:
	APP_PORT=$(APP_PORT) $(COMPOSE) up
	@echo "App: $(APP_URL)"

upd:
	APP_PORT=$(APP_PORT) $(COMPOSE) up -d --force-recreate
	@sleep 3
	@$(MAKE) --no-print-directory status

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart $(SERVICE)

logs:
	$(COMPOSE) logs -f $(SERVICE)

ps:
	APP_PORT=$(APP_PORT) $(COMPOSE) ps

status:
	@APP_PORT=$(APP_PORT) $(COMPOSE) ps
	@if curl -sf "$(APP_URL)/up" >/dev/null; then \
		echo "App is reachable at $(APP_URL)"; \
	else \
		echo "App is NOT reachable at $(APP_URL)"; \
		echo "Try: make down && make upd"; \
		exit 1; \
	fi

shell:
	$(COMPOSE) run --rm $(SERVICE) bash

console:
	$(COMPOSE) run --rm $(SERVICE) bin/rails console

db-setup:
	$(COMPOSE) run --rm $(SERVICE) bash -c "bundle check || bundle install; bin/rails db:prepare"
	$(COMPOSE) run --rm \
		-e RAILS_ENV=test \
		-e DATABASE_URL=postgres://postgres:postgres@db:5432/shogunx_api_test \
		$(SERVICE) bash -c "bundle check || bundle install; bin/rails db:test:prepare"

db-migrate:
	$(COMPOSE) run --rm $(SERVICE) bin/rails db:migrate

db-reset:
	$(COMPOSE) run --rm $(SERVICE) bin/rails db:reset

rubocop:
	$(COMPOSE) run --rm $(SERVICE) bash -c "bundle check || bundle install; bundle exec rubocop"

rspec:
	$(COMPOSE) run --rm \
		-e RAILS_ENV=test \
		-e DATABASE_URL=postgres://postgres:postgres@db:5432/shogunx_api_test \
		$(SERVICE) bash -c "bundle check || bundle install; bin/rails db:test:prepare && bundle exec rspec $(SPEC)"

test: rspec

ci: rubocop rspec

clean:
	$(COMPOSE) down -v --rmi local
