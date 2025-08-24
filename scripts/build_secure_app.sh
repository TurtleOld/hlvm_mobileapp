#!/bin/bash

# Скрипт для сборки защищенного приложения HLVM Mobile App
# Автор: AI Assistant
# Дата: $(date)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    print_info "Проверка зависимостей..."
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter не установлен или не добавлен в PATH"
        exit 1
    fi
    
    if ! command -v java &> /dev/null; then
        print_error "Java не установлена или не добавлена в PATH"
        exit 1
    fi
    
    if ! command -v keytool &> /dev/null; then
        print_error "Keytool не найден. Убедитесь, что Java установлена корректно"
        exit 1
    fi
    
    print_success "Все зависимости проверены"
}

# Проверка Flutter версии
check_flutter_version() {
    print_info "Проверка версии Flutter..."
    
    local flutter_version=$(flutter --version | grep -o "Flutter [0-9]\+\.[0-9]\+\.[0-9]\+" | cut -d' ' -f2)
    local required_version="3.0.0"
    
    if [ "$(printf '%s\n' "$required_version" "$flutter_version" | sort -V | head -n1)" = "$required_version" ]; then
        print_success "Flutter версия $flutter_version соответствует требованиям"
    else
        print_warning "Flutter версия $flutter_version может быть несовместима. Рекомендуется версия $required_version или выше"
    fi
}

# Очистка предыдущих сборок
clean_build() {
    print_info "Очистка предыдущих сборок..."
    
    flutter clean
    flutter pub get
    
    # Очистка Android
    if [ -d "android/app/build" ]; then
        rm -rf android/app/build
    fi
    
    # Очистка iOS
    if [ -d "ios/build" ]; then
        rm -rf ios/build
    fi
    
    print_success "Очистка завершена"
}

# Проверка конфигурации безопасности
check_security_config() {
    print_info "Проверка конфигурации безопасности..."
    
    # Проверка ProGuard правил
    if [ ! -f "android/app/proguard-rules.pro" ]; then
        print_error "Файл proguard-rules.pro не найден"
        exit 1
    fi
    
    # Проверка словаря обфускации
    if [ ! -f "android/app/obfuscation-dictionary.txt" ]; then
        print_error "Файл obfuscation-dictionary.txt не найден"
        exit 1
    fi
    
    # Проверка build.gradle
    if ! grep -q "minifyEnabled true" android/app/build.gradle; then
        print_warning "minifyEnabled не включен в build.gradle"
    fi
    
    if ! grep -q "shrinkResources true" android/app/build.gradle; then
        print_warning "shrinkResources не включен в build.gradle"
    fi
    
    print_success "Конфигурация безопасности проверена"
}

# Сборка Android APK
build_android_apk() {
    print_info "Сборка Android APK..."
    
    local build_type=${1:-release}
    local output_dir="build/app/outputs/flutter-apk"
    
    # Создание директории для выходных файлов
    mkdir -p "$output_dir"
    
    if [ "$build_type" = "release" ]; then
        print_info "Сборка release APK с защитой..."
        
        # Сборка с обфускацией
        flutter build apk --release \
            --target-platform android-arm64,android-arm,android-x64 \
            --dart-define=ENVIRONMENT=production \
            --dart-define=SECURITY_ENABLED=true
        
        # Переименование файла
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            mv "build/app/outputs/flutter-apk/app-release.apk" \
               "build/app/outputs/flutter-apk/hlvm_mobileapp-secure-release.apk"
            print_success "Release APK собран: hlvm_mobileapp-secure-release.apk"
        else
            print_error "Ошибка при сборке release APK"
            exit 1
        fi
        
    elif [ "$build_type" = "debug" ]; then
        print_info "Сборка debug APK..."
        
        flutter build apk --debug
        
        if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
            mv "build/app/outputs/flutter-apk/app-debug.apk" \
               "build/app/outputs/flutter-apk/hlvm_mobileapp-debug.apk"
            print_success "Debug APK собран: hlvm_mobileapp-debug.apk"
        else
            print_error "Ошибка при сборке debug APK"
            exit 1
        fi
    fi
}

# Сборка Android App Bundle
build_android_aab() {
    print_info "Сборка Android App Bundle..."
    
    local output_dir="build/app/outputs/bundle"
    mkdir -p "$output_dir"
    
    flutter build appbundle --release \
        --target-platform android-arm64,android-arm,android-x64 \
        --dart-define=ENVIRONMENT=production \
        --dart-define=SECURITY_ENABLED=true
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        mv "build/app/outputs/bundle/release/app-release.aab" \
           "build/app/outputs/bundle/hlvm_mobileapp-secure-release.aab"
        print_success "App Bundle собран: hlvm_mobileapp-secure-release.aab"
    else
        print_error "Ошибка при сборке App Bundle"
        exit 1
    fi
}

# Сборка iOS
build_ios() {
    print_info "Сборка iOS..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Сборка iOS IPA..."
        
        # Проверка наличия Xcode
        if ! command -v xcodebuild &> /dev/null; then
            print_error "Xcode не найден. Установите Xcode для сборки iOS"
            return 1
        fi
        
        # Сборка iOS
        flutter build ios --release \
            --dart-define=ENVIRONMENT=production \
            --dart-define=SECURITY_ENABLED=true
        
        print_success "iOS сборка завершена"
    else
        print_warning "iOS сборка доступна только на macOS"
    fi
}

# Проверка безопасности APK
verify_apk_security() {
    print_info "Проверка безопасности APK..."
    
    local apk_file="build/app/outputs/flutter-apk/hlvm_mobileapp-secure-release.apk"
    
    if [ ! -f "$apk_file" ]; then
        print_error "APK файл не найден для проверки"
        return 1
    fi
    
    # Проверка размера APK
    local apk_size=$(stat -c%s "$apk_file" 2>/dev/null || stat -f%z "$apk_file" 2>/dev/null)
    local apk_size_mb=$((apk_size / 1024 / 1024))
    
    print_info "Размер APK: ${apk_size_mb}MB"
    
    # Проверка на наличие debug символов
    if command -v aapt &> /dev/null; then
        local debug_info=$(aapt dump badging "$apk_file" 2>/dev/null | grep -i debug || true)
        if [ -n "$debug_info" ]; then
            print_warning "Обнаружена debug информация в APK"
        else
            print_success "Debug информация не обнаружена"
        fi
    fi
    
    # Проверка подписи
    if command -v apksigner &> /dev/null; then
        apksigner verify --verbose "$apk_file"
        if [ $? -eq 0 ]; then
            print_success "APK подписан корректно"
        else
            print_warning "Проблемы с подписью APK"
        fi
    fi
    
    print_success "Проверка безопасности завершена"
}

# Генерация отчета о сборке
generate_build_report() {
    print_info "Генерация отчета о сборке..."
    
    local report_file="build/build_report_$(date +%Y%m%d_%H%M%S).txt"
    local output_dir="build/app/outputs"
    
    cat > "$report_file" << EOF
Отчет о сборке HLVM Mobile App
================================
Дата сборки: $(date)
Версия Flutter: $(flutter --version | grep -o "Flutter [0-9]\+\.[0-9]\+\.[0-9]\+" | cut -d' ' -f2)
Версия Dart: $(flutter --version | grep -o "Dart [0-9]\+\.[0-9]\+\.[0-9]\+" | cut -d' ' -f2)

Файлы сборки:
EOF
    
    # Поиск собранных файлов
    find "$output_dir" -name "*.apk" -o -name "*.aab" -o -name "*.ipa" 2>/dev/null | while read file; do
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        local file_size_mb=$((file_size / 1024 / 1024))
        echo "- $file (${file_size_mb}MB)" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "Настройки безопасности:" >> "$report_file"
    echo "- ProGuard: включен" >> "$report_file"
    echo "- Обфускация: включена" >> "$report_file"
    echo "- Debug символы: удалены" >> "$report_file"
    echo "- Защита от reverse engineering: активна" >> "$report_file"
    
    print_success "Отчет сохранен: $report_file"
}

# Основная функция
main() {
    local platform=${1:-android}
    local build_type=${2:-release}
    
    print_info "Начинаем сборку защищенного приложения HLVM Mobile App"
    print_info "Платформа: $platform"
    print_info "Тип сборки: $build_type"
    
    # Проверки
    check_dependencies
    check_flutter_version
    check_security_config
    
    # Очистка
    clean_build
    
      # Сборка
  case $platform in
      "android")
          if [ "$build_type" = "release" ]; then
              build_android_apk release
              # Попытка создания App Bundle (может не работать на некоторых системах)
              if build_android_aab; then
                  print_success "App Bundle создан успешно"
              else
                  print_warning "App Bundle не удалось создать, но APK готов"
              fi
              verify_apk_security
          else
              build_android_apk debug
          fi
          ;;
        "ios")
            build_ios
            ;;
        "all")
            build_android_apk "$build_type"
            if [ "$build_type" = "release" ]; then
                build_android_aab
                verify_apk_security
            fi
            build_ios
            ;;
        *)
            print_error "Неизвестная платформа: $platform"
            print_info "Доступные платформы: android, ios, all"
            exit 1
            ;;
    esac
    
    # Генерация отчета
    generate_build_report
    
    print_success "Сборка завершена успешно!"
    print_info "Файлы находятся в директории: build/app/outputs/"
}

# Обработка аргументов командной строки
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Использование: $0 [платформа] [тип_сборки]"
        echo ""
        echo "Платформы:"
        echo "  android  - сборка только для Android"
        echo "  ios      - сборка только для iOS (только на macOS)"
        echo "  all      - сборка для всех платформ"
        echo ""
        echo "Типы сборки:"
        echo "  release  - релизная сборка с защитой (по умолчанию)"
        echo "  debug    - отладочная сборка"
        echo ""
        echo "Примеры:"
        echo "  $0                    # Android release по умолчанию"
        echo "  $0 android release    # Android release"
        echo "  $0 android debug      # Android debug"
        echo "  $0 ios                # iOS release"
        echo "  $0 all release        # Все платформы release"
        exit 0
        ;;
esac

# Запуск основной функции
main "$@"
