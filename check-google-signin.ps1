# Quick SHA-1 Verification Script
# Run this to check if your SHA-1 is properly configured

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🔐 Google Sign-In Configuration Check" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check 1: google-services.json exists
$googleServicesPath = "android\app\google-services.json"
if (Test-Path $googleServicesPath) {
    Write-Host "✅ google-services.json found" -ForegroundColor Green
    
    # Extract SHA-1 from google-services.json
    $content = Get-Content $googleServicesPath -Raw | ConvertFrom-Json
    $certHash = $content.client[0].oauth_client[0].android_info.certificate_hash
    
    if ($certHash) {
        Write-Host "   SHA-1 registered: $certHash" -ForegroundColor Yellow
    } else {
        Write-Host "   ⚠️  No SHA-1 found in google-services.json" -ForegroundColor Red
    }
} else {
    Write-Host "❌ google-services.json NOT found" -ForegroundColor Red
}

Write-Host ""

# Check 2: Package name consistency
Write-Host "📦 Package Name Check:" -ForegroundColor Cyan
$buildGradle = Get-Content "android\app\build.gradle.kts" -Raw
if ($buildGradle -match 'applicationId\s*=\s*"([^"]+)"') {
    $appId = $matches[1]
    Write-Host "   build.gradle.kts: $appId" -ForegroundColor Yellow
}

if (Test-Path $googleServicesPath) {
    $gsContent = Get-Content $googleServicesPath -Raw | ConvertFrom-Json
    $packageName = $gsContent.client[0].client_info.android_client_info.package_name
    Write-Host "   google-services.json: $packageName" -ForegroundColor Yellow
    
    if ($appId -eq $packageName) {
        Write-Host "   ✅ Package names match!" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Package names DO NOT match!" -ForegroundColor Red
    }
}

Write-Host ""

# Check 3: Dependencies
Write-Host "📚 Dependencies Check:" -ForegroundColor Cyan
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "google_sign_in:\s*\^?([\d.]+)") {
    Write-Host "   ✅ google_sign_in: ^$($matches[1])" -ForegroundColor Green
} else {
    Write-Host "   ❌ google_sign_in not found in pubspec.yaml" -ForegroundColor Red
}

if ($pubspec -match "firebase_auth:\s*\^?([\d.]+)") {
    Write-Host "   ✅ firebase_auth: ^$($matches[1])" -ForegroundColor Green
} else {
    Write-Host "   ❌ firebase_auth not found in pubspec.yaml" -ForegroundColor Red
}

Write-Host ""

# Check 4: Try to find debug keystore SHA-1
Write-Host "🔑 Attempting to get your Debug SHA-1:" -ForegroundColor Cyan
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $keystorePath) {
    Write-Host "   ✅ Debug keystore found at: $keystorePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "   To get SHA-1, run this command:" -ForegroundColor Yellow
    Write-Host "   (You need Java installed with keytool in PATH)" -ForegroundColor Gray
    Write-Host ""
    Write-Host '   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA1' -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "   ⚠️  Debug keystore not found" -ForegroundColor Yellow
    Write-Host "   Run 'flutter run' once to generate it" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📋 NEXT STEPS:" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Get your SHA-1 fingerprint (see command above)" -ForegroundColor White
Write-Host "2. Add it to Firebase Console:" -ForegroundColor White
Write-Host "   → https://console.firebase.google.com" -ForegroundColor Cyan
Write-Host "   → yalla-nemshi-app → Project Settings" -ForegroundColor Cyan
Write-Host "   → Android app → Add SHA-1 fingerprint" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Download NEW google-services.json" -ForegroundColor White
Write-Host "   → Replace android\app\google-services.json" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Clean and rebuild:" -ForegroundColor White
Write-Host "   flutter clean && flutter pub get && flutter run" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Test Google Sign-In on your physical device!" -ForegroundColor White
Write-Host ""
Write-Host "📖 Full guide: GOOGLE_SIGNIN_MOBILE_SETUP.md" -ForegroundColor Yellow
Write-Host ""
