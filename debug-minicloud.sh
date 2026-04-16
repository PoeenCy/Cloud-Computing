#!/bin/bash

# ============================================================================
# MiniCloud Debug & Fix Script
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 MiniCloud System Debug & Fix${NC}"
echo "================================================"

# Function to check service health
check_service() {
    local service=$1
    local container_name=$2
    
    echo -n "Checking $service... "
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
        echo -e "${GREEN}✅ Running${NC}"
        return 0
    else
        echo -e "${RED}❌ Not running${NC}"
        return 1
    fi
}

# Function to check service logs
check_logs() {
    local container_name=$1
    echo -e "${YELLOW}📋 Last 10 lines of $container_name logs:${NC}"
    docker logs --tail 10 "$container_name" 2>&1 || echo "No logs available"
    echo ""
}

# 1. Check if we're in the right directory
echo -e "${YELLOW}📁 Checking current directory...${NC}"
if [ ! -f "docker-compose.cloud.yml" ] && [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Not in MiniCloud directory. Please cd to MiniCloud folder first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ In MiniCloud directory${NC}"
echo ""

# 2. Check Docker
echo -e "${YELLOW}🐳 Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running${NC}"
    echo "Try: sudo systemctl start docker"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# 3. Check which compose file to use
COMPOSE_FILE=""
if [ -f "docker-compose.cloud.yml" ]; then
    COMPOSE_FILE="docker-compose.cloud.yml"
    echo -e "${GREEN}📄 Using docker-compose.cloud.yml${NC}"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
    echo -e "${GREEN}📄 Using docker-compose.yml${NC}"
else
    echo -e "${RED}❌ No docker-compose file found${NC}"
    exit 1
fi
echo ""

# 4. Check .env file
echo -e "${YELLOW}⚙️  Checking .env file...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating...${NC}"
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "localhost")
    cat > .env << EOF
SERVER_IP=${SERVER_IP}
DB_NAME=minicloud
DB_USER=admin
REDIS_PASSWORD=redis_secret_123
EOF
    echo -e "${GREEN}✅ .env file created with SERVER_IP=${SERVER_IP}${NC}"
else
    echo -e "${GREEN}✅ .env file exists${NC}"
    cat .env
fi
echo ""

# 5. Check secrets
echo -e "${YELLOW}🔐 Checking secrets...${NC}"
mkdir -p secrets

check_secret() {
    local file="secrets/$1"
    local default="$2"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  $file missing. Creating with default...${NC}"
        echo -n "$default" > "$file"
        chmod 600 "$file"
    fi
    echo -e "${GREEN}✅ $file exists${NC}"
}

check_secret "db_root_password.txt" "RootPass@2024!"
check_secret "db_password.txt" "DbPass@2024!"
check_secret "kc_admin_password.txt" "KcAdmin@2024!"
check_secret "storage_root_user.txt" "minioadmin"
check_secret "storage_root_pass.txt" "MinioPass@2024!"
echo ""

# 6. Check container status
echo -e "${YELLOW}📊 Checking container status...${NC}"
echo ""

# Get container status
CONTAINERS=$(docker compose -f "$COMPOSE_FILE" ps --format "json" 2>/dev/null || echo "[]")

if [ "$CONTAINERS" = "[]" ] || [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No containers running${NC}"
    echo -e "${YELLOW}🔄 Starting containers...${NC}"
    docker compose -f "$COMPOSE_FILE" up -d
    echo -e "${YELLOW}⏳ Waiting 30 seconds for containers to start...${NC}"
    sleep 30
fi

# Check individual services
echo -e "${CYAN}=== Service Health Check ===${NC}"
check_service "DNS Server" "minicloud-dns"
check_service "Database" "minicloud-db"
check_service "Redis" "minicloud-redis"
check_service "Keycloak Auth" "minicloud-auth"
check_service "App Instance 1" "minicloud-app"
check_service "App Instance 2" "minicloud-app2"
check_service "Web Instance 1" "minicloud-web1"
check_service "Web Instance 2" "minicloud-web2"
check_service "Nginx Proxy" "minicloud-proxy"
check_service "Grafana" "minicloud-grafana"
check_service "Prometheus" "minicloud-monitoring"
echo ""

# 7. Check problematic services
echo -e "${CYAN}=== Checking Failed Services ===${NC}"
FAILED_CONTAINERS=$(docker compose -f "$COMPOSE_FILE" ps --filter "status=exited" --format "{{.Name}}" 2>/dev/null || true)

if [ -n "$FAILED_CONTAINERS" ]; then
    echo -e "${RED}❌ Failed containers found:${NC}"
    for container in $FAILED_CONTAINERS; do
        echo -e "${RED}  - $container${NC}"
        check_logs "$container"
    done
else
    echo -e "${GREEN}✅ No failed containers${NC}"
fi
echo ""

# 8. Test connectivity
echo -e "${CYAN}=== Testing Connectivity ===${NC}"

# Test internal connectivity
echo -n "Testing internal web connectivity... "
if docker exec minicloud-proxy wget -q --spider http://10.10.1.11/ 2>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo -n "Testing database connectivity... "
if docker exec minicloud-app wget -q --spider http://minicloud-db:3306 2>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo -n "Testing Redis connectivity... "
if docker exec minicloud-app redis-cli -h minicloud-redis -a redis_secret_123 ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi
echo ""

# 9. Test external access
echo -e "${CYAN}=== Testing External Access ===${NC}"
SERVER_IP=$(grep SERVER_IP .env | cut -d'=' -f2 2>/dev/null || echo "localhost")

echo -n "Testing website access... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|302"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo -n "Testing API access... "
if curl -s http://localhost/api/hello | grep -q "Hello"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi
echo ""

# 10. Show access URLs
echo -e "${CYAN}=== Access Information ===${NC}"
echo -e "Server IP: ${GREEN}$SERVER_IP${NC}"
echo -e "Website:   ${GREEN}http://$SERVER_IP/${NC}"
echo -e "API:       ${GREEN}http://$SERVER_IP/api/hello${NC}"
echo -e "Keycloak:  ${GREEN}http://$SERVER_IP/auth/admin/${NC}"
echo -e "Grafana:   ${GREEN}http://$SERVER_IP/grafana/${NC}"
echo ""

# 11. Show credentials
echo -e "${CYAN}=== Default Credentials ===${NC}"
echo -e "Keycloak Admin:"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}$(cat secrets/kc_admin_password.txt 2>/dev/null || echo 'KcAdmin@2024!')${NC}"
echo ""
echo -e "Grafana:"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin${NC}"
echo ""

# 12. Recommendations
echo -e "${CYAN}=== Recommendations ===${NC}"

# Check if Keycloak is the main issue
if ! check_service "Keycloak Auth" "minicloud-auth" &>/dev/null; then
    echo -e "${YELLOW}🔧 Keycloak Fix Commands:${NC}"
    echo "  docker compose -f $COMPOSE_FILE restart minicloud-auth"
    echo "  docker logs -f minicloud-auth"
    echo ""
fi

# Check if database is the issue
if ! check_service "Database" "minicloud-db" &>/dev/null; then
    echo -e "${YELLOW}🔧 Database Fix Commands:${NC}"
    echo "  docker compose -f $COMPOSE_FILE restart minicloud-db"
    echo "  docker logs -f minicloud-db"
    echo ""
fi

echo -e "${YELLOW}🔧 General Fix Commands:${NC}"
echo "  # Restart all services:"
echo "  docker compose -f $COMPOSE_FILE restart"
echo ""
echo "  # View logs:"
echo "  docker compose -f $COMPOSE_FILE logs -f"
echo ""
echo "  # Rebuild and restart:"
echo "  docker compose -f $COMPOSE_FILE down"
echo "  docker compose -f $COMPOSE_FILE up -d --build"
echo ""

echo -e "${GREEN}🎉 Debug completed!${NC}"