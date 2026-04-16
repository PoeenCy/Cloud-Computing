#!/bin/bash

# ============================================================================
# MiniCloud GCP Fix - Main Script
# Chạy script này từ máy local để fix MiniCloud trên GCP
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 MiniCloud GCP Fix Tool${NC}"
echo "================================================"
echo ""

# Thông tin GCP
INSTANCE_NAME="minicloud-demo"
ZONE="asia-southeast1-a"

# Kiểm tra gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found${NC}"
    echo "Please install Google Cloud SDK first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Kiểm tra authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${YELLOW}🔐 Please authenticate with Google Cloud:${NC}"
    gcloud auth login
fi

echo -e "${GREEN}✅ gcloud authenticated${NC}"

# Menu chính
show_menu() {
    echo ""
    echo -e "${CYAN}=== MiniCloud Fix Options ===${NC}"
    echo "1. 🔍 Quick system check"
    echo "2. 🔧 Full system debug & fix"
    echo "3. 🔐 Fix Keycloak specifically"
    echo "4. 🖥️  VM management (start/stop/restart)"
    echo "5. 📊 View system status"
    echo "6. 🌐 Test website access"
    echo "7. 📋 View logs"
    echo "8. 🆘 Emergency full restart"
    echo "0. Exit"
    echo ""
}

# Function: Quick check
quick_check() {
    echo -e "${YELLOW}🔍 Quick system check...${NC}"
    
    # Check VM status
    VM_STATUS=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    echo -e "VM Status: ${GREEN}$VM_STATUS${NC}"
    
    if [ "$VM_STATUS" != "RUNNING" ]; then
        echo -e "${RED}❌ VM is not running${NC}"
        return 1
    fi
    
    # Get VM IP
    VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    echo -e "VM IP: ${GREEN}$VM_IP${NC}"
    
    # Test website
    echo -n "Testing website... "
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://$VM_IP/ | grep -q "200\|302"; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
    
    # Test API
    echo -n "Testing API... "
    if curl -s --connect-timeout 10 http://$VM_IP/api/hello | grep -q "Hello"; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
    
    # Test Keycloak
    echo -n "Testing Keycloak... "
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://$VM_IP/auth/admin/ | grep -q "200\|302"; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
}

# Function: Full debug
full_debug() {
    echo -e "${YELLOW}🔧 Running full system debug...${NC}"
    
    # Copy scripts to VM
    echo "Copying debug scripts..."
    gcloud compute scp debug-minicloud.sh fix-keycloak.sh $INSTANCE_NAME:~/ --zone=$ZONE
    
    # Run debug
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd ~/MiniCloud 2>/dev/null || cd ~/
        chmod +x ~/debug-minicloud.sh ~/fix-keycloak.sh
        ~/debug-minicloud.sh
    "
}

# Function: Fix Keycloak
fix_keycloak() {
    echo -e "${YELLOW}🔐 Fixing Keycloak...${NC}"
    
    # Copy Keycloak fix script
    gcloud compute scp fix-keycloak.sh $INSTANCE_NAME:~/ --zone=$ZONE
    
    # Run Keycloak fix
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd ~/MiniCloud 2>/dev/null || cd ~/
        chmod +x ~/fix-keycloak.sh
        echo '1' | ~/fix-keycloak.sh
    "
}

# Function: VM management
vm_management() {
    echo -e "${CYAN}🖥️  VM Management${NC}"
    echo "1. Start VM"
    echo "2. Stop VM"
    echo "3. Restart VM"
    echo "4. VM info"
    echo "0. Back to main menu"
    echo ""
    
    read -p "Choose option: " vm_choice
    
    case $vm_choice in
        1)
            echo "Starting VM..."
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
            ;;
        2)
            echo "Stopping VM..."
            gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE
            ;;
        3)
            echo "Restarting VM..."
            gcloud compute instances reset $INSTANCE_NAME --zone=$ZONE
            ;;
        4)
            gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function: View status
view_status() {
    echo -e "${YELLOW}📊 Viewing system status...${NC}"
    
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd ~/MiniCloud 2>/dev/null || cd ~/
        echo '=== Docker Containers ==='
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
        echo ''
        echo '=== System Resources ==='
        free -h
        df -h
        echo ''
        echo '=== Network ==='
        ss -tlnp | grep -E ':(80|443|8080|3306|6379)'
    "
}

# Function: Test access
test_access() {
    echo -e "${YELLOW}🌐 Testing website access...${NC}"
    
    VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    
    echo -e "VM IP: ${GREEN}$VM_IP${NC}"
    echo ""
    echo "Testing URLs:"
    
    urls=(
        "http://$VM_IP/"
        "http://$VM_IP/api/hello"
        "http://$VM_IP/auth/admin/"
        "http://$VM_IP/grafana/"
    )
    
    for url in "${urls[@]}"; do
        echo -n "  $url ... "
        response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url")
        if [[ "$response" =~ ^(200|302)$ ]]; then
            echo -e "${GREEN}✅ $response${NC}"
        else
            echo -e "${RED}❌ $response${NC}"
        fi
    done
}

# Function: View logs
view_logs() {
    echo -e "${YELLOW}📋 Viewing logs...${NC}"
    
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd ~/MiniCloud 2>/dev/null || cd ~/
        echo '=== Keycloak Logs (last 20 lines) ==='
        docker logs --tail 20 minicloud-auth 2>/dev/null || echo 'Container not found'
        echo ''
        echo '=== Database Logs (last 10 lines) ==='
        docker logs --tail 10 minicloud-db 2>/dev/null || echo 'Container not found'
        echo ''
        echo '=== Nginx Proxy Logs (last 10 lines) ==='
        docker logs --tail 10 minicloud-proxy 2>/dev/null || echo 'Container not found'
    "
}

# Function: Emergency restart
emergency_restart() {
    echo -e "${RED}🆘 Emergency full restart...${NC}"
    echo -e "${YELLOW}This will restart the entire system. Continue? (y/N)${NC}"
    read -p "> " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
            cd ~/MiniCloud 2>/dev/null || cd ~/
            echo 'Stopping all containers...'
            docker compose -f docker-compose.cloud.yml down 2>/dev/null || docker compose down
            echo 'Cleaning up...'
            docker system prune -f
            echo 'Starting all containers...'
            docker compose -f docker-compose.cloud.yml up -d 2>/dev/null || docker compose up -d
            echo 'Waiting for services to start...'
            sleep 60
            echo 'System restart completed!'
        "
    else
        echo "Cancelled."
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Choose an option (0-8): " choice
    
    case $choice in
        1)
            quick_check
            ;;
        2)
            full_debug
            ;;
        3)
            fix_keycloak
            ;;
        4)
            vm_management
            ;;
        5)
            view_status
            ;;
        6)
            test_access
            ;;
        7)
            view_logs
            ;;
        8)
            emergency_restart
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done