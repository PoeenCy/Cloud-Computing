#!/bin/bash

# ============================================================================
# Script push MiniCloud lên nhánh cloud-deployment
# ============================================================================

set -e

echo "🌿 Creating cloud deployment branch..."

# 1. Tạo và checkout nhánh mới
git checkout -b cloud-deployment 2>/dev/null || git checkout cloud-deployment

# 2. Add tất cả thay đổi
git add .

# 3. Commit với message rõ ràng
git commit -m "🚀 Cloud deployment version

✨ Features:
- Port 80:80 for standard HTTP
- Fixed nginx auth routing (IP-based)
- Shell TCP healthcheck for redis-exporter  
- Auto deployment script
- Cloud-ready configuration

🔧 Changes:
- docker-compose.yml: port 8088→80
- nginx.conf: auth hostname→IP (10.10.1.13)
- Added deploy-cloud-final.sh
- Added README-CLOUD.md

🎯 Ready for: GCP, AWS, Azure deployment"

# 4. Push lên remote
echo "📤 Pushing to remote..."
git push -u origin cloud-deployment

echo ""
echo "✅ Successfully pushed to cloud-deployment branch!"
echo ""
echo "🔗 To deploy on cloud server:"
echo "   git clone <your-repo>"
echo "   git checkout cloud-deployment"
echo "   cd MiniCloud"
echo "   chmod +x deploy-cloud-final.sh"
echo "   ./deploy-cloud-final.sh"
echo ""
echo "🌐 Branch URL: https://github.com/<username>/<repo>/tree/cloud-deployment"