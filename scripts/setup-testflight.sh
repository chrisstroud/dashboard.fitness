#!/bin/bash
set -e

# ============================================================
# TestFlight CI/CD — One-Time Setup Script
# Run this on your Mac: ./scripts/setup-testflight.sh
# ============================================================

REPO="chrisstroud/dashboard.fitness"
BUNDLE_ID="com.chrisstroud.Dashboard-Fitness"
TEAM_ID="7QBDU88UW8"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TestFlight CI/CD Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ----------------------------------------------------------
# Step 0: Prerequisites
# ----------------------------------------------------------
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v xcodebuild &>/dev/null; then
  echo -e "${RED}Xcode not found. Install Xcode from the App Store first.${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Xcode installed${NC}"

if ! command -v gh &>/dev/null; then
  echo -e "${YELLOW}GitHub CLI (gh) not found. Installing via Homebrew...${NC}"
  if ! command -v brew &>/dev/null; then
    echo -e "${RED}Homebrew not found. Install it first:${NC}"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  fi
  brew install gh
fi
echo -e "${GREEN}✓ GitHub CLI installed${NC}"

if ! gh auth status &>/dev/null 2>&1; then
  echo -e "${YELLOW}Not logged in to GitHub CLI. Logging in...${NC}"
  gh auth login
fi
echo -e "${GREEN}✓ GitHub CLI authenticated${NC}"
echo ""

# ----------------------------------------------------------
# Step 1: Distribution Certificate
# ----------------------------------------------------------
echo -e "${BLUE}Step 1: Distribution Certificate${NC}"
echo ""

# Look for existing distribution identity
DIST_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | awk -F'"' '{print $2}')

if [ -z "$DIST_IDENTITY" ]; then
  DIST_IDENTITY=$(security find-identity -v -p codesigning | grep "iPhone Distribution" | head -1 | awk -F'"' '{print $2}')
fi

if [ -z "$DIST_IDENTITY" ]; then
  echo -e "${YELLOW}No distribution certificate found in your Keychain.${NC}"
  echo ""
  echo "You need to create one:"
  echo "  1. Open Xcode → Settings → Accounts"
  echo "  2. Select your Apple ID → your team"
  echo "  3. Click 'Manage Certificates'"
  echo "  4. Click '+' → 'Apple Distribution'"
  echo ""
  read -p "Press Enter after you've created it, or Ctrl+C to abort..."
  DIST_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | awk -F'"' '{print $2}')
  if [ -z "$DIST_IDENTITY" ]; then
    echo -e "${RED}Still no distribution certificate found. Aborting.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}✓ Found: ${DIST_IDENTITY}${NC}"
echo ""

# Export as .p12
CERT_P12="/tmp/df-dist-cert.p12"
echo "Exporting certificate as .p12..."
echo -e "${YELLOW}You'll be prompted for:${NC}"
echo "  1. A NEW password to protect the .p12 file (remember this!)"
echo "  2. Your Mac login password (to access Keychain)"
echo ""

CERT_SHA=$(security find-identity -v -p codesigning | grep "$DIST_IDENTITY" | awk '{print $2}')
security export -t identities -f pkcs12 -k ~/Library/Keychains/login.keychain-db -o "$CERT_P12" -P "" 2>/dev/null || \
  security export -t identities -f pkcs12 -o "$CERT_P12" 2>/dev/null

if [ ! -f "$CERT_P12" ]; then
  echo -e "${YELLOW}Automatic export failed. Exporting manually...${NC}"
  echo ""
  echo "Please export manually:"
  echo "  1. Open Keychain Access"
  echo "  2. Find your '${DIST_IDENTITY}' certificate"
  echo "  3. Right-click → Export → save as /tmp/df-dist-cert.p12"
  echo ""
  read -p "Press Enter after exporting..."
fi

if [ ! -f "$CERT_P12" ]; then
  echo -e "${RED}Certificate file not found at ${CERT_P12}. Aborting.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Certificate exported${NC}"
echo ""

# Ask for the password they used
read -sp "Enter the password you used for the .p12 (or press Enter if empty): " CERT_PASSWORD
echo ""

# ----------------------------------------------------------
# Step 2: Provisioning Profile
# ----------------------------------------------------------
echo ""
echo -e "${BLUE}Step 2: Provisioning Profile${NC}"
echo ""

# Look for existing App Store profile
PROFILE_PATH=""
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

if [ -d "$PROFILES_DIR" ]; then
  for profile in "$PROFILES_DIR"/*.mobileprovision; do
    if [ -f "$profile" ]; then
      PROFILE_BUNDLE=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)
      PROFILE_TYPE=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract ProvisionsAllDevices raw - 2>/dev/null)
      if echo "$PROFILE_BUNDLE" | grep -q "$BUNDLE_ID"; then
        # Check if it's an App Store profile (no device list = App Store)
        DEVICE_COUNT=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract ProvisionedDevices raw - 2>/dev/null | wc -l 2>/dev/null || echo "0")
        PROFILE_NAME=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Name raw - 2>/dev/null)
        echo "  Found profile: $PROFILE_NAME"
        PROFILE_PATH="$profile"
      fi
    fi
  done
fi

if [ -z "$PROFILE_PATH" ]; then
  echo -e "${YELLOW}No App Store provisioning profile found for ${BUNDLE_ID}.${NC}"
  echo ""
  echo "Create one:"
  echo "  1. Go to https://developer.apple.com/account/resources/profiles/add"
  echo "  2. Select 'App Store Connect' under Distribution"
  echo "  3. Select your app ID (${BUNDLE_ID})"
  echo "  4. Select your distribution certificate"
  echo "  5. Name it 'Dashboard Fitness App Store'"
  echo "  6. Download and double-click to install"
  echo ""
  read -p "Press Enter after installing the profile..."

  # Try to find it again
  for profile in "$PROFILES_DIR"/*.mobileprovision; do
    if [ -f "$profile" ]; then
      PROFILE_BUNDLE=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)
      if echo "$PROFILE_BUNDLE" | grep -q "$BUNDLE_ID"; then
        PROFILE_PATH="$profile"
        break
      fi
    fi
  done
fi

if [ -z "$PROFILE_PATH" ]; then
  echo -e "${RED}Provisioning profile not found. Aborting.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Provisioning profile found${NC}"
echo ""

# ----------------------------------------------------------
# Step 3: App Store Connect API Key
# ----------------------------------------------------------
echo ""
echo -e "${BLUE}Step 3: App Store Connect API Key${NC}"
echo ""
echo "You need an API key from App Store Connect."
echo ""
echo "  1. Go to https://appstoreconnect.apple.com/access/integrations/api"
echo "  2. Click '+' to create a new key"
echo "  3. Name: 'GitHub Actions'"
echo "  4. Access: 'App Manager'"
echo "  5. Download the .p8 file (you can only download it ONCE)"
echo ""

read -p "Enter the Key ID (e.g., ABC123DEFG): " ASC_KEY_ID
read -p "Enter the Issuer ID (shown at the top of the Keys page): " ASC_ISSUER_ID
read -p "Enter the path to the .p8 file (e.g., ~/Downloads/AuthKey_ABC123.p8): " ASC_KEY_PATH

# Expand tilde
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo -e "${RED}File not found: ${ASC_KEY_PATH}. Aborting.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ API key found${NC}"
echo ""

# ----------------------------------------------------------
# Step 4: Upload secrets to GitHub
# ----------------------------------------------------------
echo ""
echo -e "${BLUE}Step 4: Uploading secrets to GitHub${NC}"
echo ""

# Base64 encode everything
CERT_B64=$(base64 -i "$CERT_P12")
PROFILE_B64=$(base64 -i "$PROFILE_PATH")
KEY_B64=$(base64 -i "$ASC_KEY_PATH")

echo "Uploading CERTIFICATE_P12..."
echo "$CERT_B64" | gh secret set CERTIFICATE_P12 --repo "$REPO"
echo -e "${GREEN}✓${NC}"

echo "Uploading CERTIFICATE_PASSWORD..."
echo "$CERT_PASSWORD" | gh secret set CERTIFICATE_PASSWORD --repo "$REPO"
echo -e "${GREEN}✓${NC}"

echo "Uploading PROVISIONING_PROFILE..."
echo "$PROFILE_B64" | gh secret set PROVISIONING_PROFILE --repo "$REPO"
echo -e "${GREEN}✓${NC}"

echo "Uploading ASC_API_KEY_ID..."
echo "$ASC_KEY_ID" | gh secret set ASC_API_KEY_ID --repo "$REPO"
echo -e "${GREEN}✓${NC}"

echo "Uploading ASC_API_ISSUER_ID..."
echo "$ASC_ISSUER_ID" | gh secret set ASC_API_ISSUER_ID --repo "$REPO"
echo -e "${GREEN}✓${NC}"

echo "Uploading ASC_API_KEY..."
echo "$KEY_B64" | gh secret set ASC_API_KEY --repo "$REPO"
echo -e "${GREEN}✓${NC}"

# ----------------------------------------------------------
# Step 5: Cleanup
# ----------------------------------------------------------
echo ""
echo -e "${BLUE}Cleaning up temporary files...${NC}"
rm -f "$CERT_P12"
echo -e "${GREEN}✓ Done${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your TestFlight pipeline is ready. To trigger a build:"
echo "  • Push to main (any changes in ios/)"
echo "  • Or go to Actions → 'Build & Deploy to TestFlight' → Run workflow"
echo ""
echo "From your phone, just tell Claude Code to build a feature,"
echo "then /ship — it'll land on TestFlight automatically."
echo ""
