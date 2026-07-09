# Docker Compose Collection

A curated collection of Docker Compose configurations for various stacks, services, and infrastructure tools.

## Quick Start

1. Install Docker Compose: https://docs.docker.com/compose/install
2. Clone this repository
3. Navigate to the desired project directory
4. Copy `.env.example` to `.env` and configure your values
5. Run `docker compose up -d`

## Projects

### Server (Self-Hosted Applications)
Ready-to-deploy self-hosted services.
- [Watchtower](server/watchtower/) - Automated container updates
- [Portainer](server/portainer/) - Docker management UI
- [Jellyfin](server/jellyfin/) - Media server
- [Plex](server/plexmediaserver/) - Media server
- [Sonarr](server/sonarr/) - TV series management
- [Radarr](server/radarr/) - Movie management
- [Lidarr](server/lidarr/) - Music management
- [Prowlarr](server/prowlarr/) - Indexer manager
- [Bazarr](server/bazarr/) - Subtitle management
- [Overseerr](server/overseerr/) - Request management
- [Transmission](server/transmission-openvpn/) - BitTorrent client with VPN
- [Paperless-ngx](server/paperless-ngx/) - Document management
- [Home Assistant](server/home-assistant/) - Home automation
- [Immich](server/immich/) - Photo management
- [Navidrome](server/navidrome/) - Music streaming
- [TubeTube](server/tubearchivist/) - YouTube archiving

### Infrastructure
Core infrastructure and DevOps tools.
- [Keycloak](Infrastructure/keycloak/) - Identity and access management
- [Jenkins](Infrastructure/jenkins/) - CI/CD server
- [Sentry](Infrastructure/sentry/) - Error tracking
- [LDAP](Infrastructure/ldap/) - Directory service
- [Kibana](Infrastructure/kibana/) - Elasticsearch dashboard
- [Monitoring](Infrastructure/Monitoring/) - ELK + Zabbix + Grafana stack
- [Prometheus](Infrastructure/prometheus/) - Metrics collection
- [Grafana](Infrastructure/monitoring/grafana/) - Metrics visualization
- [Nginx Proxy Manager](Infrastructure/nginx-proxy-manager/) - Reverse proxy
- [SonarQube](Infrastructure/development/sonarqube/) - Code quality
- [GitLab](Infrastructure/development/gitlab/) - Git hosting
- [pgAdmin](Infrastructure/development/pgadmin/) - PostgreSQL admin

### Communication
VoIP and messaging platforms.
- [Asterisk](Communication/docker-asterisk/) - PBX system
- [Chatwoot](Communication/chatwoot/) - Customer engagement
- [BigBlueButton](Communication/bbb/) - Video conferencing

### Stacks
Language and framework-specific stacks.
- [Python / Odoo](Stacks/Python/odoo-16-docker-compose/) - ERP system
- [PHP 7.4](Stacks/PHP/php7.4/) - PHP development
- [PHP Latest](Stacks/PHP/php-latest/) - PHP development
- [EspoCRM](Stacks/PHP/espocrm/) - CRM system
- [Camunda 8.6](Stacks/BPMN/camunda-8.6/) - BPM platform
- [Oracle APEX](Stacks/BPMN/OracleApex/) - Low-code development
- [Go REST API](Stacks/Go/simple/) - Go with nginx load balancer

### Frameworks
Web framework templates.
- [Django](Frameworks/Django/) - Python web framework
- [Express](Frameworks/Express/) - Node.js web framework
- [Next.js](Frameworks/nextjs/) - React framework

### CMS
Content management systems.
- [Strapi](CMS/strapi/) - Headless CMS

### Laravel
PHP Laravel framework setups.
- [Laravel](Laravel/) - Basic Laravel
- [Laravel Webhook](Laravel/LaravelWebhook/) - Webhook handler
- [Laravel Envoy](Laravel/LaravelEnvoy/) - Task runner

### VPN
VPN configurations.
- [SoftEther VPN](VPN/SoftetherVPN/) - Multi-protocol VPN

### Awesome Compose
Collection of Docker Compose samples from various sources.
- [awesome/](awesome/) - 37+ curated compose files for popular stacks

## Contributing

1. Ensure your docker-compose file validates: `docker compose -f <file> config`
2. Use `.env.example` for any required secrets (never commit real passwords)
3. Add `restart: unless-stopped` to all services
4. Add health checks where applicable
