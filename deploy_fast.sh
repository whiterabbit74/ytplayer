#!/bin/bash
# 🚀 MusicPlay Deploy
# Сборка Docker образа ЛОКАЛЬНО (cross-compile linux/amd64)
# На сервер отправляется ГОТОВЫЙ образ — ноль нагрузки на VPS
# Использование: ./deploy.sh

set -e

SERVER="ubuntu@146.235.212.239"
REMOTE_DIR="/home/ubuntu/ytplayer"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="ytplayer-musicplay"

echo "🚀 MusicPlay DEPLOY"
echo "==================="


GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")
GIT_DATE=$(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
echo "✅ Код актуален. Версия: ${GIT_COMMIT} от ${GIT_DATE}"

# 2. ЛОКАЛЬНАЯ СБОРКА DOCKER ОБРАЗА (cross для amd64 сервера)
echo ""
echo "🔨 Сборка Docker образа локально (linux/amd64)..."
cd "$PROJECT_DIR"

docker build \
    --platform linux/amd64 \
    --build-arg COMMIT_HASH="$GIT_COMMIT" \
    -t "${IMAGE_NAME}:latest" \
    -f Dockerfile .

echo "✅ Образ собран"

# 3. СОХРАНЕНИЕ И ОТПРАВКА
echo ""
echo "💾 Сохранение и отправка образа..."
docker save "${IMAGE_NAME}:latest" | gzip | \
    ssh -o StrictHostKeyChecking=no "$SERVER" "cat > /tmp/${IMAGE_NAME}.tar.gz"
echo "✅ Образ отправлен"

# 4. СИНХРОНИЗАЦИЯ КОНФИГОВ
echo ""
echo "📁 Синхронизация конфигурации..."
scp -o StrictHostKeyChecking=no \
    "$PROJECT_DIR/deploy/docker-compose.yml" \
    "${SERVER}:${REMOTE_DIR}/docker-compose.yml"
scp -o StrictHostKeyChecking=no \
    "$PROJECT_DIR/deploy/Caddyfile" \
    "${SERVER}:${REMOTE_DIR}/Caddyfile"
echo "✅ Конфиги обновлены"

# 5. РАЗВЕРТЫВАНИЕ НА СЕРВЕРЕ
echo ""
echo "🚀 Развертывание..."
ssh -o StrictHostKeyChecking=no "$SERVER" "
set -e

echo '📦 Загрузка Docker образа...'
docker load < /tmp/${IMAGE_NAME}.tar.gz
rm -f /tmp/${IMAGE_NAME}.tar.gz

echo '🔄 Перезапуск musicplay...'
cd ${REMOTE_DIR}
docker compose up -d musicplay --force-recreate

echo '⏳ Ожидание (5 сек)...'
sleep 5

echo ''
echo '✅ Контейнеры:'
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'NAME|musicplay|bgutil|cookie'

echo ''
echo '🧹 Очистка старых образов...'
docker image prune -f 2>/dev/null || true

echo ''
echo '✅ Деплой завершён!'
"

echo ""
echo "🎉 ГОТОВО!"
echo "📋 Версия: ${GIT_COMMIT} от ${GIT_DATE}"
echo "🌐 https://tradingibs.site/music/"
