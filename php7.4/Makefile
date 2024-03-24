hamidshariati = -f docker-compose.hamidshariati-full.yml
prod_yml = -f docker-compose.yml -f docker-compose.prod.yml
all_yml = -f docker-compose.yml  -f docker-compose.hamidshariati-full.yml

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# If the first argument is "run"...
ifeq (run,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

up:
	@echo "Upping the docker containers..."
	@docker-compose $(dev_yml) up -d --remove-orphans

up_hamidshariati:
	@echo "Upping the docker containers..."
	@docker-compose $(hamidshariati) up -d --remove-orphans

up_no_daemon:
	@echo "Upping the docker containers..."
	@docker-compose $(dev_yml) up --remove-orphans

up_all:
	@echo "Upping the docker containers..."
	@docker-compose $(all_yml) up -d --remove-orphans

stop:
	@echo "Stopping the docker containers..."
	@docker-compose $(all_yml) stop

down:
	@echo "Downing the docker containers..."
	@docker-compose $(all_yml) down --remove-orphans

restart:
	@echo "Restarting the docker containers..."
	@docker-compose $(dev_yml) restart

build:
	@echo "Building the docker containers..."
	@docker-compose $(prod_yml) build --compress --no-cache --force-rm --pull --parallel
	@docker-compose $(dev_yml) build --compress --no-cache --force-rm --pull --parallel

push:
	@echo "Pushing the docker images..."
	@docker-compose $(prod_yml) push
	@docker-compose $(dev_yml) push

art:
	@docker-compose exec app php artisan $(filter-out $@,$(MAKECMDGOALS))

__migrate_fresh_seed:
	@echo "Creating migration table if not exists..."
	@docker-compose exec app php artisan migrate
	@echo "Rollback Elasticsearch indexes..."
	@docker-compose exec app php artisan elastic:migrate:rollback
	@echo "Running migrations with seeders..."
	@docker-compose exec app php artisan migrate:fresh --seed
	@echo "Creating Elasticsearch indexes..."
	@docker-compose exec app php artisan elastic:migrate

composer_install:
    # docker-compose run app composer install --ignore-platform-reqs --no-scripts
	docker-compose run app composer install

prod_composer_install:
	docker-compose run app composer install --prefer-dist --no-dev -o

composer_update:
    # docker-compose run app composer update --ignore-platform-reqs --no-scripts
	docker-compose run app composer update

composer_autoload:
	docker-compose run app composer dump-autoload

test:
	@echo "Running tests..."
	@docker-compose exec app "./vendor/bin/phpunit" \
		--configuration="./phpunit.xml" \
		--process-isolation \
		--do-not-cache-result \
		--stop-on-defect \
		--stop-on-error \
        --stop-on-failure \
        --stop-on-warning \
        --stop-on-risky \
        --stop-on-skipped \
        --stop-on-incomplete \
        --fail-on-warning \
        --fail-on-risky

analyse:
	@echo "Running phpstan analyse..."
	@docker-compose $(prod_yml) run --no-deps app vendor/bin/phpstan analyse --memory-limit=-1

pint:
	@echo "Running laravel pint..."
	@docker-compose $(prod_yml) run --no-deps app vendor/bin/pint

cache:
	docker-compose exec app php artisan route:cache
	docker-compose exec app php artisan config:cache
	docker-compose exec app php artisan view:cache
	docker-compose exec app php artisan event:cache

clear_cache:
	docker-compose exec app php artisan cache:clear

restart_queue:
	docker-compose exec app php artisan queue:restart

clear_config:
	docker-compose exec app php artisan config:clear
	docker-compose exec app php artisan route:clear
	make restart_queue

deploy:
	make pull
	docker-compose -f $(ROOT_DIR)/docker-compose.yml -f $(ROOT_DIR)/docker-compose.prod.yml up -d
	make clear_config
	make cache

deploy_with_build:
	make pull
	docker-compose -f $(ROOT_DIR)/docker-compose.yml -f $(ROOT_DIR)/docker-compose.prod.yml up -d --build
	make clear_config
	make cache

#empty
%:
    @:
