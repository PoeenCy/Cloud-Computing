#!/bin/bash

# ============================================================================
# Script để SSH vào GCP và fix MiniCloud
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 MiniCloud GCP Fix Script${NC}"
echo "================================================"

# Thông tin GCP
INSTANCE_NAME="minicloud-demo"
ZONE="asia-southeast1-a"

echo -e "${YELLOW}📡 Checking GCP connection...${NC}"

# Kiểm tra gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK first.${NC}"
    exit 1
fi

# Kiểm tra authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ Not authenticated with gcloud. Please run: gcloud auth login${NC}"
    exit 1
fi

echo -e "${GREEN}✅ gcloud authenticated${NC}"

# Kiểm tra VM status
echo -e "${YELLOW}🖥️  Checking VM status...${NC}"
VM_STATUS=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="value(status)" 2>/dev/null || echo "NOT_FOUND")

case $VM_STATUS in
    "RUNNING")
        echo -e "${GREEN}✅ VM is running${NC}"
        ;;
    "STOPPED"|"TERMINATED")
        echo -e "${YELLOW}⚠️  VM is stopped. Starting...${NC}"
        gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
        echo -e "${YELLOW}⏳ Waiting for VM to start (60s)...${NC}"
        sleep 60
        ;;
    "NOT_FOUND")
        echo -e "${RED}❌ VM not found. Please check instance name and zone.${NC}"
        echo "Available instances:"
        gcloud compute instances list
        exit 1
        ;;
    *)
        echo -e "${YELLOW}⚠️  VM status: $VM_STATUS${NC}"
        ;;
esac

# Lấy IP của VM
VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
echo -e "${GREEN}📍 VM IP: $VM_IP${NC}"
echo ""

# Copy debug script lên VM
echo -e "${YELLOW}📤 Copying debug script to VM...${NC}"
gcloud compute scp debug-minicloud.sh $INSTANCE_NAME:~/ --zone=$ZONE

# SSH vào VM và chạy debug
echo -e "${YELLOW}🔧 Running debug on VM...${NC}"
echo "================================================"

gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    cd ~/MiniCloud 2>/dev/null || cd ~/ 
    chmod +x ~/debug-minicloud.sh
    ~/debug-minicloud.sh
"

echo ""
echo "================================================"
echo -e "${CYAN}🎯 Quick Access Commands:${NC}"
echo ""
echo -e "${YELLOW}SSH to VM:${NC}"
echo "gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo "Website:   http://$VM_IP/"
echo "API:       http://$VM_IP/api/hello"
echo "Keycloak:  http://$VM_IP/auth/admin/"
echo "Grafana:   http://$VM_IP/grafana/"
echo ""
echo -e "${YELLOW}VM Management:${NC}"
echo "Stop VM:   gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE"
echo "Start VM:  gcloud compute instances start $INSTANCE_NAME --zone=$ZONE"
echo "Restart:   gcloud compute instances reset $INSTANCE_NAME --zone=$ZONE"
echo ""
echo -e "${GREEN}🎉 Fix script completed!${NC}"