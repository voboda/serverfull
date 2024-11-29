#!/bin/bash

# Ensure a directory name was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory-name>"
    echo "Example: $0 myapp"
    exit 1
fi

APP_NAME="$1"
CURRENT_DIR="$(pwd)"

# Create the basic directory structure
echo "Creating directory structure for $APP_NAME..."
mkdir -p "$APP_NAME"/{repo,deployments,config/{prod,feature}}

# Initialize the bare git repository
cd "$APP_NAME/repo"
git init --bare

# Create the post-receive hook
cat > hooks/post-receive << 'EOF'
#!/bin/bash

# The script runs from the bare git repository directory (.git)
REPO_ROOT="$(dirname "$(dirname "$GIT_DIR")")"
DEPLOY_ROOT="$REPO_ROOT/deployments"
CONFIG_ROOT="$REPO_ROOT/config"
MAIN_BRANCHES="main|master"
TRAEFIK_NETWORK="traefik-proxy"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_repo_name() {
    basename "$(dirname "$GIT_DIR")"
}

for cmd in docker-compose docker git yq; do
    if ! command -v $cmd &> /dev/null; then
        log "Error: $cmd is required but not installed"
        exit 1
    fi
done

setup_traefik_labels() {
    local compose_file="$1"
    local domain="$2"
    local repo_name=$(get_repo_name)

    if ! yq e '.services.web.labels[] | select(contains("traefik"))' "$compose_file" &>/dev/null; then
        yq e -i '
            .services.web.networks += ["traefik-proxy"] |
            .services.web.labels += [
                "traefik.enable=true",
                "traefik.http.routers.'$repo_name'.rule=Host(`'$domain'`)",
                "traefik.http.routers.'$repo_name'.entrypoints=websecure",
                "traefik.http.routers.'$repo_name'.tls=true"
            ] |
            .networks.["traefik-proxy"].external = true
        ' "$compose_file"
    fi
}

deploy() {
    local branch="$1"
    local repo_name=$(get_repo_name)
    local target_dir="$DEPLOY_ROOT/$repo_name"
    local config_dir="$CONFIG_ROOT/$repo_name"
    
    if echo "$branch" | grep -E "^($MAIN_BRANCHES)$" > /dev/null; then
        override_dir="$config_dir/prod"
        if [[ ! -f "$override_dir/.env" ]]; then
            log "Error: Production .env file not found at $override_dir/.env"
            exit 1
        fi
        DEPLOY_DOMAIN=$(grep '^DOMAIN=' "$override_dir/.env" | cut -d '=' -f2)
    else
        if [[ ! -f "$config_dir/feature/.env" ]]; then
            log "Feature branch deployments not configured. Skipping deployment of branch '$branch'"
            return 0
        fi
        
        FEATURE_DOMAIN=$(grep '^DOMAIN=' "$config_dir/feature/.env" | cut -d '=' -f2)
        if [[ -z "$FEATURE_DOMAIN" ]]; then
            log "Feature branch domain not configured. Skipping deployment of branch '$branch'"
            return 0
        fi
        
        override_dir="$config_dir/feature"
        DEPLOY_DOMAIN="${branch}.${FEATURE_DOMAIN}"
        target_dir="${target_dir}_${branch}"
    fi

    mkdir -p "$target_dir"
    
    log "Deploying branch '$branch' to $target_dir"
    git --work-tree="$target_dir" --git-dir="$GIT_DIR" checkout -f "$branch"
    
    if [[ -d "$override_dir" ]]; then
        cp -rf "$override_dir/." "$target_dir/"
    fi
    
    if [[ ! -f "$target_dir/docker-compose.yml" ]]; then
        log "Error: docker-compose.yml not found in repository"
        exit 1
    fi
    
    setup_traefik_labels "$target_dir/docker-compose.yml" "$DEPLOY_DOMAIN"
    
    cd "$target_dir"
    log "Building containers..."
    docker-compose build --no-cache
    log "Stopping old containers..."
    docker-compose down
    log "Starting new containers..."
    docker-compose up -d
}

while read oldrev newrev ref; do
    branch=$(echo "$ref" | sed 's|refs/heads/||')
    log "Received push to branch: $branch"
    deploy "$branch"
done
EOF

# Make the hook executable
chmod +x hooks/post-receive

# Create example environment files
cd "$CURRENT_DIR/$APP_NAME/config"

# Production environment example
cat > prod/.env.example << EOF
DOMAIN=example.com
# Add your production environment variables here
EOF

# Feature branch environment example
cat > feature/.env.example << EOF
DOMAIN=dev.example.com
# Add your feature branch environment variables here
EOF

echo "Setup complete! Directory structure created at $CURRENT_DIR/$APP_NAME"
