#!/bin/bash
# Script tự động import Grafana dashboards

set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARD_DIR="./grafana-dashboards"

echo "🔍 Kiểm tra Grafana..."
if ! docker exec minicloud-grafana curl -s -f "$GRAFANA_URL/api/health" > /dev/null; then
    echo "❌ Grafana không chạy hoặc không truy cập được"
    exit 1
fi
echo "✅ Grafana đang chạy"

echo ""
echo "📊 Cập nhật Prometheus data source..."
# Xóa datasource cũ nếu có
docker exec minicloud-grafana curl -s -X DELETE \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    "$GRAFANA_URL/api/datasources/name/Prometheus" > /dev/null

# Tạo datasource mới với đúng uid
docker exec minicloud-grafana curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://minicloud-monitoring:9090/prometheus",
        "access": "proxy",
        "isDefault": true,
        "uid": "prometheus"
    }' \
    "$GRAFANA_URL/api/datasources" 2>/dev/null || echo "⚠️  Lỗi khi tạo Prometheus data source"

echo ""
echo "📊 Cập nhật Loki data source..."
# Xóa datasource cũ nếu có
docker exec minicloud-grafana curl -s -X DELETE \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    "$GRAFANA_URL/api/datasources/name/Loki" > /dev/null

# Tạo datasource mới với đúng uid
docker exec minicloud-grafana curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d '{
        "name": "Loki",
        "type": "loki",
        "url": "http://minicloud-loki:3100",
        "access": "proxy",
        "uid": "loki"
    }' \
    "$GRAFANA_URL/api/datasources" 2>/dev/null || echo "⚠️  Lỗi khi tạo Loki data source"

echo ""
echo "📂 Import dashboards từ $DASHBOARD_DIR..."

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
    if [ -f "$dashboard_file" ]; then
        dashboard_name=$(basename "$dashboard_file")
        echo ""
        echo "📥 Đang import: $dashboard_name"
        
        # Đọc nội dung dashboard
        dashboard_json=$(cat "$dashboard_file")
        
        # Tạo payload cho Grafana API
        payload=$(cat <<EOF
{
  "dashboard": $dashboard_json,
  "overwrite": true,
  "message": "Imported via script"
}
EOF
)
        
        # Import dashboard
        response=$(docker exec -i minicloud-grafana curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "$GRAFANA_USER:$GRAFANA_PASS" \
            -d "$payload" \
            "$GRAFANA_URL/api/dashboards/db")
        
        if echo "$response" | grep -q '"status":"success"'; then
            echo "✅ Import thành công: $dashboard_name"
        else
            echo "⚠️  Lỗi khi import $dashboard_name:"
            echo "$response" | head -3
        fi
    fi
done

echo ""
echo "🎉 Hoàn tất! Truy cập Grafana tại: http://136.110.61.46:8088/grafana/"
echo "   Username: admin"
echo "   Password: admin"
