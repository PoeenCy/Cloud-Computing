#!/bin/bash

# ============================================================================
# MiniCloud GCP Deployment Script - Final Version
# ============================================================================

set -e

echo "🚀 Starting MiniCloud deployment on GCP..."

# 1. Tạo secrets nếu chưa có
echo "📝 Creating secrets..."
mkdir -p secrets

# Tạo secrets với mật khẩu mạnh
echo "minicloud_db_secret_2024!" > secrets/db_password.txt
echo "minicloud_root_super_secret_2024!" > secrets/db_root_password.txt  
echo "keycloak_admin_super_secret_123!" > secrets/kc_admin_password.txt
echo "minioadmin" > secrets/storage_root_user.txt
echo "minioadmin_secret_2024!" > secrets/storage_root_pass.txt

echo "✅ Secrets created"

# 2. Dừng systemd-resolved để tránh conflict port 53
echo "🔧 Configuring DNS..."
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Tạo resolv.conf tạm thời
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

echo "✅ DNS configured"

# 3. Khởi động containers
echo "🐳 Starting containers..."
docker-compose down -v 2>/dev/null || true
docker-compose up -d --build

echo "⏳ Waiting for containers to start..."
sleep 60

# 4. Kiểm tra trạng thái
echo "📊 Checking container status..."
docker-compose ps

# 5. Kiểm tra website
echo "🌐 Testing website..."
curl -I http://localhost/ || echo "Website not ready yet"

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "📋 Access URLs:"
echo "   Website:    http://$(curl -s ifconfig.me)/"
echo "   Keycloak:   http://$(curl -s ifconfig.me)/auth/admin/"
echo "   Grafana:    http://$(curl -s ifconfig.me)/grafana/"
echo ""
echo "🔐 Default credentials:"
echo "   Keycloak Admin: admin / keycloak_admin_super_secret_123!"
echo "   Grafana:        admin / admin"
echo ""
echo "⚠️  Remember to:"
echo "   1. Create users in Keycloak"
echo "   2. Configure firewall rules"
echo "   3. Set up SSL certificates for production"