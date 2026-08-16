#!/bin/bash
# ============================================================
# Los Mooscles — Build + TestFlight Upload Script
# ============================================================
# Pré-requisitos:
#   • macOS Ventura 13+ ou superior
#   • Xcode 15 ou 16 instalado
#   • Certificados "Apple Distribution" instalados no Keychain
#   • Provisioning profiles "match AppStore" instalados
#
# Para gerar a API Key:
#   1. App Store Connect → Users & Access → Keys
#   2. Gere uma nova chave com role "App Manager"
#   3. Baixe o .p8 e anote o Key ID e Issuer ID
# ============================================================

set -e
set -o pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export RUBYOPT="-E utf-8"

# ── Configuração ──────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$PROJECT_DIR/ios/Runner.xcworkspace"
SCHEME="Runner"
CONFIGURATION="Release"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/Runner.xcarchive"
IPA_PATH="$PROJECT_DIR/build/ios/ipa"

# App Store Connect (preencha com seus dados)
# Opção 1: API Key (recomendado)
API_KEY_ID=""          # Ex: ABC123DEF456
API_KEY_ISSUER_ID=""   # Ex: 12345678-1234-1234-1234-123456789012
API_KEY_PATH=""        # Ex: ~/private_keys/AuthKey_ABC123DEF456.p8

# Opção 2: Apple ID (alternativa)
APPLE_ID=""            # Ex: seu@email.com
APP_SPECIFIC_PASSWORD="" # Gere em appleid.apple.com → Security → App-Specific Passwords
# ─────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     Los Mooscles → TestFlight Upload         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Verificar Xcode
XCODE_VERSION=$(xcrun xcodebuild -version | head -1)
echo "✓ Xcode: $XCODE_VERSION"

REQUIRED_MAJOR=14
XCODE_MAJOR=$(echo "$XCODE_VERSION" | grep -oE '[0-9]+' | head -1)
if [ "$XCODE_MAJOR" -lt "$REQUIRED_MAJOR" ]; then
    echo "✗ Erro: Xcode $REQUIRED_MAJOR+ é necessário. Instale via https://developer.apple.com/download/"
    exit 1
fi

# ── Incrementar Build Number ───────────────────────────
cd "$PROJECT_DIR"
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUM=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
NEW_BUILD=$((BUILD_NUM + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD}"

echo "▶ Versão atual: $CURRENT_VERSION"
echo "▶ Nova versão: $NEW_VERSION (build $NEW_BUILD)"

sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
echo "✓ pubspec.yaml atualizado"

# ── Flutter pub get ────────────────────────────────────
echo ""
echo "▶ Instalando dependências Flutter..."
flutter pub get
echo "✓ Dependências instaladas"

# ── Pod install ────────────────────────────────────────
echo ""
echo "▶ Instalando CocoaPods..."
cd ios
pod install --repo-update
cd ..
echo "✓ CocoaPods instalado"

# ── Criar ExportOptions.plist ──────────────────────────
cat > "$EXPORT_OPTIONS" << EXPORTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>PJ32UPL29J</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EXPORTEOF
echo "✓ ExportOptions.plist criado"

# ── Limpar build anterior ──────────────────────────────
rm -rf "$ARCHIVE_PATH" "$IPA_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")"
echo "✓ Build directory limpo"

# ── Archive ────────────────────────────────────────────
echo ""
echo "▶ Gerando archive (isso pode levar 5-15 minutos)..."
xcrun xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    FLUTTER_BUILD_NUMBER="$NEW_BUILD" \
    FLUTTER_BUILD_NAME="$VERSION_NAME"

echo ""
if [ -d "$ARCHIVE_PATH" ]; then
    echo "✓ Archive gerado: $ARCHIVE_PATH"
else
    echo "✗ Falha ao gerar archive"
    exit 1
fi

# ── Export IPA ─────────────────────────────────────────
echo ""
echo "▶ Exportando IPA..."
xcrun xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$IPA_PATH" \
    -allowProvisioningUpdates

IPA_FILE=$(find "$IPA_PATH" -name "*.ipa" | head -1)
if [ -z "$IPA_FILE" ]; then
    echo "✗ Falha ao encontrar IPA exportado"
    exit 1
fi
echo "✓ IPA exportado: $IPA_FILE"

# ── Upload ao TestFlight ───────────────────────────────
echo ""
echo "▶ Fazendo upload ao TestFlight..."

if [ -n "$API_KEY_ID" ] && [ -n "$API_KEY_ISSUER_ID" ] && [ -n "$API_KEY_PATH" ]; then
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "$API_KEY_ID" \
        --apiIssuer "$API_KEY_ISSUER_ID" \
        --private-key "$API_KEY_PATH" \
        --verbose
elif [ -n "$APPLE_ID" ] && [ -n "$APP_SPECIFIC_PASSWORD" ]; then
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --username "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --verbose
else
    echo ""
    echo "⚠️  Credenciais não configuradas."
    echo "   Configure API_KEY_ID / API_KEY_ISSUER_ID / API_KEY_PATH"
    echo "   ou APPLE_ID / APP_SPECIFIC_PASSWORD no início deste script."
    echo ""
    echo "   IPA disponível em: $IPA_FILE"
    echo "   Faça upload manualmente via Transporter.app ou Xcode → Organizer"
    exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ Upload concluído! Build $NEW_BUILD enviado  ║"
echo "║                                              ║"
echo "║  Acesse App Store Connect em ~30 minutos:    ║"
echo "║  https://appstoreconnect.apple.com           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
