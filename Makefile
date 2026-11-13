SHELL := /bin/sh

DOCKER ?= docker
COMPOSE ?= docker compose
COMPOSE_PROJECT_NAME ?= docker_laravel-p5

ENV_FILE := $(firstword $(wildcard .env) .env.example)
COMPOSE_ENV := --env-file $(ENV_FILE)

IMAGE ?= docker_laravel-p5-app:local
TEST_IMAGE ?= docker_laravel-p5-test:local
BASE_IMAGE ?= docker_laravel-p5-base:local
WEB_IMAGE ?= docker_laravel-p5-web:local

.DEFAULT_GOAL := help

.PHONY: help build test verify up run down logs ps shell install migrate migrate-fresh seed lint format security clean

help:
	@echo "Docker baseline for docker_laravel"
	@echo "  make build          build the runtime image"
	@echo "  make test           build the test stage (runs PHPUnit)"
	@echo "  make verify         build + test"
	@echo "  make up             verify, then start the stack detached"
	@echo "  make run            verify, then start the stack in the foreground"
	@echo "  make down           stop the stack"
	@echo "  make logs           follow logs"
	@echo "  make ps             show stack status"
	@echo "  make shell          shell into the php container"
	@echo "  make install        composer install into ./src"
	@echo "  make migrate        run migrations"
	@echo "  make migrate-fresh  drop all tables and re-run migrations"
	@echo "  make seed           run database seeders"
	@echo "  make lint           run Laravel Pint in test mode"
	@echo "  make format         run Laravel Pint"
	@echo "  make security       composer audit + Docker Scout image scan"
	@echo "  make clean CONFIRM=yes  stop the stack and delete the MySQL volume"

build:
	$(DOCKER) build --target runtime -t $(IMAGE) .

test:
	$(DOCKER) build --target test -t $(TEST_IMAGE) .

verify: build test
	@echo "verify: build + test passed"

up: verify
	$(COMPOSE) $(COMPOSE_ENV) up -d --wait

run: verify
	$(COMPOSE) $(COMPOSE_ENV) up

down:
	$(COMPOSE) $(COMPOSE_ENV) down

logs:
	$(COMPOSE) $(COMPOSE_ENV) logs -f

ps:
	$(COMPOSE) $(COMPOSE_ENV) ps

shell:
	$(COMPOSE) $(COMPOSE_ENV) exec php sh

install:
	$(COMPOSE) $(COMPOSE_ENV) run --rm composer install --no-interaction --prefer-dist

migrate:
	$(COMPOSE) $(COMPOSE_ENV) run --rm artisan migrate --force

migrate-fresh:
	$(COMPOSE) $(COMPOSE_ENV) run --rm artisan migrate:fresh --force

seed:
	$(COMPOSE) $(COMPOSE_ENV) run --rm artisan db:seed --force

lint:
	$(COMPOSE) $(COMPOSE_ENV) run --rm --entrypoint vendor/bin/pint phpunit --test

format:
	$(COMPOSE) $(COMPOSE_ENV) run --rm --entrypoint vendor/bin/pint phpunit

security:
	$(COMPOSE) $(COMPOSE_ENV) run --rm composer audit --no-interaction
	$(DOCKER) scout cves $(IMAGE) --only-severity critical,high

clean:
ifeq ($(CONFIRM),yes)
	$(COMPOSE) $(COMPOSE_ENV) down --volumes --remove-orphans
else
	@echo "Refusing to delete the MySQL volume. Re-run: make clean CONFIRM=yes"
endif