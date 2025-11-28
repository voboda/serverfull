# Serverfull

Serverfull is a lightweight deployment system for self-hosted Docker Compose applications. It provides a serverless-style deployment experience for your self-hosted projects, making it easy to deploy both production and feature branches with automatic domain routing through Traefik.

## Why Serverfull?

While serverless platforms offer great convenience, sometimes you want or need to host your own applications. Serverfull brings some of that convenience to self-hosted environments by:

- Automating deployments through git pushes
- Managing multiple environments (production and feature branches)
- Handling domain routing automatically
- Keeping configuration separate from code
- Requiring minimal server setup

## Prerequisites

- A Linux server with:
  - Git
  - Docker and Docker Compose
  - Traefik (configured as reverse proxy)
  - yq (YAML processor)

## Quick Start

1. On your production server, Clone this repository and save `serverfull.sh` where accessible.:
   ```bash
   git clone https://github.com/voboda/serverfull.git

   cp serverfull.sh ~/scripts/

   chmod +x ~/scripts/serverfull.sh

   
   ```

2. In a directory where you want to setup your project, run the setup script:
 
   cd /var/containers/
   ```bash
   ~/scripts/serverfull.sh myapp
   ```

3. Configure your environments:
   ```bash
   # Production environment
   cp myapp/config/prod/.env.example myapp/config/prod/.env
   # Edit .env with your production domain and variables

   # Feature branch environment (optional)
   cp myapp/config/feature/.env.example myapp/config/feature/.env
   # Edit .env with your feature branch domain and variables
   ```

4. On your development machine, add the remote to your project:
   ```bash
   git remote add production ssh://user@yourserver/path/to/myapp/repo
   ```

5. Ensure your project has a `docker-compose.yml` file with a `web` service defined.

6. Push to deploy:
   ```bash
   git push production main     # Deploy to production
   git push production feature  # Deploy to feature.dev.example.com
   ```

## Directory Structure

```
myapp/
├── repo/                 # Bare git repository
├── deployments/          # Deployed applications
│   ├── myapp/           # Production deployment
│   └── myapp_feature/   # Feature branch deployment
└── config/
    ├── prod/            # Production configuration
    │   ├── .env        # Production environment variables
    │   └── ...         # Other production files
    └── feature/         # Feature branch configuration
        ├── .env        # Feature branch environment variables
        └── ...         # Other feature branch files
```

## Configuration

### Production Environment

Create `config/prod/.env` with your production settings:
```bash
DOMAIN=example.com
# Add other production variables
```

### Feature Branches

Create `config/feature/.env` to enable feature branch deployments:
```bash
DOMAIN=dev.example.com
# Add feature branch variables
```

Feature branches will be deployed to subdomains automatically:
- Branch `feature-login` -> `feature-login.dev.example.com`
- Branch `test-api` -> `test-api.dev.example.com`

The `DOMAIN` variable in your `.env` files specifies the base domain for your deployment:
- For production: This is the exact domain where your application will be accessible (e.g., `DOMAIN=example.com`)
- For feature branches: This is the base domain where feature branches will be deployed as subdomains (e.g., `DOMAIN=dev.example.com` means a `feature-login` branch becomes `feature-login.dev.example.com`)

## Docker Compose Requirements

Your `docker-compose.yml` should expose a web service. Serverfull will automatically add Traefik configuration for routing.

Example `docker-compose.yml`:
```yaml
version: '3'
services:
  web:
    build: .
    ports:
      - "3000"
```

## Project Repository Requirements

Your project repository must contain the following:

1. **docker-compose.yml**: A Docker Compose file in the root of your project repository. This file is required for deployment.

2. **Web Service**: A service named `web` must be defined in your `docker-compose.yml`. Serverfull automatically configures Traefik routing for this service.

Example minimal `docker-compose.yml`:
```yaml
version: '3'
services:
  web:
    build: .
    ports:
      - "3000"
```

3. **No strict directory structure**: Beyond the docker-compose.yml file, there are no strict requirements for your project's source code directory structure.

4. **Configuration files**: Environment-specific configuration files are managed separately in the Serverfull deployment directory's `config` folder (see Configuration section).

## Security Considerations

- Keep your `.env` files secure and never commit them to your repository
- Use different credentials for production and feature environments
- Review the automatic Traefik configuration for your specific needs

## Troubleshooting

Deployment logs echo through to your git client when you deploy.

Common issues and solutions:

1. Deployments not working:
   - Check the hook's execute permissions
   - Verify Git environment variables are available
   - Check directory permissions
2. Subdomains not routing:
   - Verify Traefik is running and configured
   - Check DNS settings for wildcard domains
   - Verify docker network configuration
3. Configuration not applying:
    - Check file permissions in config directories
    - Verify .env file syntax
    - Check deployment logs

## Contributing

Contributions are welcome! Some areas that could use improvement:

- Deployment rollback support
- Better logging and error handling
- Configuration validation
- Cleanup of old feature branch deployments
- Integration with other reverse proxies

## License

Copyright (C) 2024

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but will create a more open, decentralized web where developers maintain control of their infrastructure. See the GNU Affero General Public License for more details.
