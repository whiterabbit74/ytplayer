#!/bin/bash
# 📱 MusicPlay iOS Deploy to Physical Device (FINAL CLI)
# Скрипт для сборки и установки приложения на физический iPhone из терминала.

DEVICE_ID="00008140-001875A43082201C" # iPhone 16
BUNDLE_ID="com.musicplay.app"
SCHEME="MusicPlay"
PROJECT="MusicPlay.xcodeproj"
TEAM_ID="6QSB7UUV7B"
PROFILE_PATH="/Users/q/Library/Developer/Xcode/UserData/Provisioning Profiles/7ce0a054-64fd-4264-b6f1-7066d38b1f9b.mobileprovision"
SIGN_ID="126021DA680FD8DF110B2D03F82FBC79E8C878AD"

echo "🚀 Начинаю деплой на iPhone..."

# 1. Регенерация проекта
echo "🧬 Регенерация проекта через XcodeGen..."
xcodegen generate --spec project.yml --quiet

# 2. Очистка
echo "🧹 Очистка DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MusicPlay-*

# 3. Сборка (без подписи)
echo "🔨 Сборка проекта..."
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS,id=$DEVICE_ID" \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Ошибка сборки!"
    exit 1
fi

# 4. Поиск пути к .app
APP_PATH=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS,id=$DEVICE_ID" | grep -m 1 "CODESIGNING_FOLDER_PATH" | awk '{print $3}')

if [ -z "$APP_PATH" ]; then
    echo "❌ Не удалось найти путь к собранному приложению!"
    exit 1
fi

echo "📦 Путь к приложению: $APP_PATH"

# 5. Проверка версии
echo "🔍 Проверка версии в коде..."
grep -a "MusicPlay_BUILD_VERSION_2.1.0" "$APP_PATH/MusicPlay" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Код актуален (MusicPlay_BUILD_VERSION_2.1.0 найдена)."
else
    echo "⚠️ ПРЕДУПРЕЖДЕНИЕ: Маркер версии не найден в бинарнике!"
fi

# 6. Внедрение профайла и подпись
echo "✍️ Подпись приложения (Team ID: $TEAM_ID)..."
cp "$PROFILE_PATH" "$APP_PATH/embedded.mobileprovision"

# Явно подписываем все библиотеки, так как --deep игнорирует dylib в корне бандла
find "$APP_PATH" -name "*.dylib" -o -name "*.framework" | while read -r lib; do
    echo "Подпись библиотеки: $(basename "$lib")"
    codesign -f -s "$SIGN_ID" "$lib"
done

codesign -f -s "$SIGN_ID" --entitlements tmp.entitlements "$APP_PATH"

# 7. Установка на устройство
echo "📲 Установка на iPhone..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Ошибка установки!"
    exit 1
fi

# 8. Запуск приложения
echo "🏁 Запуск приложения..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "✅ ГОТОВО! Приложение версии v1.2.5 (v2.9) запущено на iPhone."
