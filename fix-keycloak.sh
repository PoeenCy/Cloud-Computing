#!/bin/bash

# ============================================================================
# Keycloak Fix Script - Chuyên sửa lỗi Keycloak
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔐 Keycloak Fix Script${NC}"
echo "================================================"

# Kiểm tra Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi

# Kiểm tra compose file
COMPOSE_FILE=""
if [ -f "docker-compose.cloud.yml" ]; then
    COMPOSE_FILE="docker-compose.cloud.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo -e "${RED}❌ No docker-compose file found${NC}"
    exit 1
fi

echo -e "${GREEN}📄 Using: $COMPOSE_FILE${NC}"

# 1. Kiểm tra trạng thái Keycloak
echo -e "${YELLOW}🔍 Checking Keycloak status...${NC}"
KC_STATUS=$(docker ps --filter "name=minicloud-auth" --format "{{.Status}}" 2>/dev/null || echo "Not running")
echo -e "Status: ${YELLOW}$KC_STATUS${NC}"

# 2. Kiểm tra logs Keycloak
echo -e "${YELLOW}📋 Recent Keycloak logs:${NC}"
echo "----------------------------------------"
docker logs --tail 20 minicloud-auth 2>/dev/null || echo "No logs available"
echo "----------------------------------------"
echo ""

# 3. Kiểm tra database connection
echo -e "${YELLOW}🗄️  Checking database connection...${NC}"
DB_STATUS=$(docker ps --filter "name=minicloud-db" --format "{{.Status}}" 2>/dev/null || echo "Not running")
echo -e "Database status: ${YELLOW}$DB_STATUS${NC}"

if docker ps --filter "name=minicloud-db" | grep -q "Up"; then
    echo -e "${GREEN}✅ Database is running${NC}"
    
    # Test database connection
    echo -n "Testing database connection... "
    if docker exec minicloud-db mysql -u admin -p$(cat secrets/db_password.txt 2>/dev/null || echo "DbPass@2024!") -e "SELECT 1;" &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
        echo -e "${YELLOW}🔧 Database connection issue detected${NC}"
    fi
else
    echo -e "${RED}❌ Database not running${NC}"
fi
echo ""

# 4. Kiểm tra cấu hình Keycloak
echo -e "${YELLOW}⚙️  Checking Keycloak configuration...${NC}"

# Lấy SERVER_IP từ .env
SERVER_IP=$(grep SERVER_IP .env 2>/dev/null | cut -d'=' -f2 || echo "localhost")
echo -e "Server IP: ${GREEN}$SERVER_IP${NC}"

# Kiểm tra environment variables
echo -e "${YELLOW}Environment variables:${NC}"
docker exec minicloud-auth env | grep -E "KC_|KEYCLOAK_" 2>/dev/null || echo "Container not running"
echo ""

# 5. Fix functions
fix_keycloak() {
    echo -e "${CYAN}🔧 Applying Keycloak fixes...${NC}"
    
    # Stop Keycloak
    echo "1. Stopping Keycloak..."
    docker compose -f "$COMPOSE_FILE" stop minicloud-auth
    
    # Remove container
    echo "2. Removing container..."
    docker compose -f "$COMPOSE_FILE" rm -f minicloud-auth
    
    # Ensure database is running
    echo "3. Ensuring database is running..."
    docker compose -f "$COMPOSE_FILE" up -d minicloud-db
    sleep 10
    
    # Start Keycloak
    echo "4. Starting Keycloak..."
    docker compose -f "$COMPOSE_FILE" up -d minicloud-auth
    
    echo -e "${GREEN}✅ Keycloak restart completed${NC}"
}

fix_database() {
    echo -e "${CYAN}🗄️  Fixing database...${NC}"
    
    # Restart database
    echo "1. Restarting database..."
    docker compose -f "$COMPOSE_FILE" restart minicloud-db
    sleep 15
    
    # Restart Keycloak after database
    echo "2. Restarting Keycloak..."
    docker compose -f "$COMPOSE_FILE" restart minicloud-auth
    
    echo -e "${GREEN}✅ Database fix completed${NC}"
}

fix_network() {
    echo -e "${CYAN}🌐 Fixing network issues...${NC}"
    
    # Recreate networks
    echo "1. Stopping all services..."
    docker compose -f "$COMPOSE_FILE" down
    
    echo "2. Removing networks..."
    docker network prune -f
    
    echo "3. Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    echo -e "${GREEN}✅ Network fix completed${NC}"
}

# 6. Menu lựa chọn
echo -e "${CYAN}=== Fix Options ===${NC}"
echo "1. Quick Keycloak restart"
echo "2. Fix database connection"
echo "3. Fix network issues"
echo "4. Full system restart"
echo "5. View detailed logs"
echo "6. Test Keycloak health"
echo "0. Exit"
echo ""

read -p "Choose an option (0-6): " choice

case $choice in
    1)
        fix_keycloak
        ;;
    2)
        fix_database
        ;;
    3)
        fix_network
        ;;
    4)
        echo -e "${CYAN}🔄 Full system restart...${NC}"
        docker compose -f "$COMPOSE_FILE" down
        sleep 5
        docker compose -f "$COMPOSE_FILE" up -d
        echo -e "${GREEN}✅ Full restart completed${NC}"
        ;;
    5)
        echo -e "${CYAN}📋 Detailed logs:${NC}"
        echo "=== Keycloak logs ==="
        docker logs minicloud-auth 2>/dev/null || echo "No logs"
        echo ""
        echo "=== Database logs ==="
        docker logs minicloud-db 2>/dev/null || echo "No logs"
        ;;
    6)
        echo -e "${CYAN}🏥 Testing Keycloak health...${NC}"
        
        # Wait for startup
        echo "Waiting for Keycloak to start (60s)..."
        sleep 60
        
        # Test health endpoints
        echo -n "Testing health endpoint... "
        if curl -s -f http://localhost/auth/health/ready &>/dev/null; then
            echo -e "${GREEN}✅ OK${NC}"
        elif curl -s -f http://localhost/auth/health &>/dev/null; then
            echo -e "${YELLOW}⚠️  Starting${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
        
        # Test admin console
        echo -n "Testing admin console... "
        if curl -s -o /dev/null -w "%{http_code}" http://localhost/auth/admin/ | grep -q "200\|302"; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# 7. Post-fix check
echo ""
echo -e "${YELLOW}⏳ Waiting for services to stabilize (30s)...${NC}"
sleep 30

echo -e "${CYAN}=== Post-Fix Status ===${NC}"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo -e "${CYAN}=== Access Information ===${NC}"
echo -e "Keycloak Admin: ${GREEN}http://$SERVER_IP/auth/admin/${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}$(cat secrets/kc_admin_password.txt 2>/dev/null || echo 'KcAdmin@2024!')${NC}"
echo ""
echo -e "${YELLOW}💡 If Keycloak still doesn't work, try:${NC}"
echo "1. Wait 2-3 more minutes for full startup"
echo "2. Check firewall rules: gcloud compute firewall-rules list"
echo "3. Check VM external IP: gcloud compute instances list"
echo ""
echo -e "${GREEN}🎉 Fix script completed!${NC}"