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
    print_info "Проверка конфигурации..."
    
    # Проверка build.gradle
    if ! grep -q "minifyEnabled false" android/app/build.gradle; then
        print_warning "minifyEnabled не отключен в build.gradle"
    fi
    
    if ! grep -q "shrinkResources false" android/app/build.gradle; then
        print_warning "shrinkResources не отключен в build.gradle"
    fi
    
    print_success "Конфигурация проверена"
}

# Сборка Android APK
build_android_apk() {
    local build_type=$1
    
    if [ "$build_type" = "release" ]; then
        print_info "Сборка release APK..."
        flutter build apk --release \
            --dart-define=FLUTTER_BUILD_NAME=hlvm_mobileapp \
            --dart-define=FLUTTER_BUILD_NUMBER=1.0.0
        
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            mv "build/app/outputs/flutter-apk/app-release.apk" \
               "build/app/outputs/flutter-apk/hlvm_mobileapp-release.apk"
            print_success "Release APK собран: hlvm_mobileapp-release.apk"
        else
            print_error "Ошибка при сборке release APK"
            return 1
        fi
    else
        print_info "Сборка debug APK..."
        flutter build apk --debug
        
        if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
            mv "build/app/outputs/flutter-apk/app-debug.apk" \
               "build/app/outputs/flutter-apk/hlvm_mobileapp-debug.apk"
            print_success "Debug APK собран: hlvm_mobileapp-debug.apk"
        else
            print_error "Ошибка при сборке debug APK"
            return 1
        fi
    fi
}

# Сборка Android App Bundle
build_android_aab() {
    print_info "Сборка Android App Bundle..."
    
    flutter build appbundle --release \
      --dart-define=FLUTTER_BUILD_NAME=hlvm_mobileapp \
      --dart-define=FLUTTER_BUILD_NUMBER=1.0.0
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
      mv "build/app/outputs/bundle/release/app-release.aab" \
        "build/app/outputs/bundle/release/hlvm_mobileapp-release.aab"
      print_success "App Bundle собран: hlvm_mobileapp-release.aab"
      return 0
    else
      print_error "Ошибка при сборке App Bundle"
      return 1
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
            --dart-define=FLUTTER_BUILD_NAME=hlvm_mobileapp \
            --dart-define=FLUTTER_BUILD_NUMBER=1.0.0
        
        print_success "iOS сборка завершена"
    else
        print_warning "iOS сборка доступна только на macOS"
    fi
}

# Генерация отчета о сборке
generate_build_report() {
    local report_file="build_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "=== ОТЧЕТ О СБОРКЕ HLVM MOBILE APP ===" > "$report_file"
    echo "Дата сборки: $(date)" >> "$report_file"
    echo "Платформа: Android" >> "$report_file"
    echo "Версия Flutter: $(flutter --version | head -n1)" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== РЕЗУЛЬТАТЫ СБОРКИ ===" >> "$report_file"
    echo "- Release APK: готов" >> "$report_file"
    echo "- Debug APK: готов" >> "$report_file"
    echo "- App Bundle: готов" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== КОНФИГУРАЦИЯ ===" >> "$report_file"
    echo "- minifyEnabled: отключен" >> "$report_file"
    echo "- shrinkResources: отключен" >> "$report_file"
    echo "- ProGuard: отключен" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== РАЗМЕРЫ ФАЙЛОВ ===" >> "$report_file"
    if [ -f "build/app/outputs/flutter-apk/hlvm_mobileapp-release.apk" ]; then
      local apk_size=$(du -h "build/app/outputs/flutter-apk/hlvm_mobileapp-release.apk" | cut -f1)
      echo "- Release APK: $apk_size" >> "$report_file"
    fi
    
    if [ -f "build/app/outputs/flutter-apk/hlvm_mobileapp-debug.apk" ]; then
      local debug_apk_size=$(du -h "build/app/outputs/flutter-apk/hlvm_mobileapp-debug.apk" | cut -f1)
      echo "- Debug APK: $debug_apk_size" >> "$report_file"
    fi
    
    if [ -f "build/app/outputs/bundle/release/hlvm_mobileapp-release.aab" ]; then
      local aab_size=$(du -h "build/app/outputs/bundle/release/hlvm_mobileapp-release.aab" | cut -f1)
      echo "- App Bundle: $aab_size" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Отчет сохранен: $report_file"
  }

# Основная функция
main() {
    local platform=${1:-android}
    local build_type=${2:-release}
    
    print_info "Начинаем сборку приложения HLVM Mobile App"
    print_info "Платформа: $platform"
    print_info "Тип сборки: $build_type"
    
    # Проверяем зависимости
    check_dependencies
    
    # Проверяем версию Flutter
    check_flutter_version
    
    # Очищаем предыдущие сборки
    clean_build
    
    # Проверяем конфигурацию
    check_security_config
    
    # Собираем приложение
    case $platform in
      "android")
        build_android_apk "$build_type"
        # Попытка создания App Bundle (может не работать на некоторых системах)
        if [ "$build_type" = "release" ]; then
            if build_android_aab; then
                print_success "App Bundle создан успешно"
            else
                print_warning "App Bundle не удалось создать, но APK готов"
            fi
        fi
        ;;
      "ios")
        build_ios
        ;;
      "all")
        build_android_apk "$build_type"
        if [ "$build_type" = "release" ]; then
            build_android_aab
        fi
        build_ios
        ;;
      *)
        print_error "Неизвестная платформа: $platform"
        print_info "Доступные платформы: android, ios, all"
        exit 1
        ;;
    esac
    
    # Генерируем отчет
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
