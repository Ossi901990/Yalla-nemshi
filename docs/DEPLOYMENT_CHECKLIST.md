# Deployment Checklist

## Step-by-Step Release Process

This document provides a detailed checklist for releasing new versions to production.

---

## 📋 Pre-Deployment (1 week before release)

### **Planning Phase**
- [ ] Define release scope (features, bug fixes, refactoring)
- [ ] Assign tasks to team members
- [ ] Set target release date
- [ ] Create GitHub milestone for version (e.g., v1.2.0)
- [ ] Plan testing schedule

### **Code Preparation**
- [ ] All features implemented in feature branches
- [ ] Code reviewed and approved by team lead
- [ ] All PRs merged to `develop` branch
- [ ] `develop` branch is stable and tested

### **Documentation**
- [ ] Update [CHANGELOG.md](../CHANGELOG.md) with all changes
- [ ] Update README.md if features affect users
- [ ] Prepare release notes for stores
- [ ] Document any breaking changes

---

## 🧪 Testing Phase (3-5 days before release)

### **Automated Testing**
```bash
# Run all tests
flutter test
# ✅ All tests must pass

# Check for lint issues
flutter analyze
# ✅ No warnings or errors

# Check code coverage
flutter test --coverage
# ✅ Coverage > 80% on changed files
```

### **Manual Testing - Android**
- [ ] Install on Android 7 emulator - features work ✅
- [ ] Install on Android 11 emulator - features work ✅
- [ ] Install on real Android device - features work ✅
- [ ] Test permissions request - works ✅
- [ ] Test offline behavior - graceful degradation ✅
- [ ] Test location services - works ✅
- [ ] Test notifications - received and tapped ✅
- [ ] Test image upload - works ✅
- [ ] Battery/memory usage - acceptable ✅
- [ ] Performance - no janky frames ✅

### **Manual Testing - iOS**
- [ ] Install on iOS 14 simulator - features work ✅
- [ ] Install on iOS 17 simulator - features work ✅
- [ ] Install on real iOS device - features work ✅
- [ ] Test permissions request - works ✅
- [ ] Test offline behavior - graceful degradation ✅
- [ ] Test location services - works ✅
- [ ] Test notifications - received and tapped ✅
- [ ] Test image upload - works ✅
- [ ] Battery/memory usage - acceptable ✅
- [ ] Performance - no janky frames ✅

### **Manual Testing - Web**
- [ ] Test in Chrome - features work ✅
- [ ] Test in Firefox - features work ✅
- [ ] Test in Safari - features work ✅
- [ ] Test on mobile browser - responsive ✅
- [ ] Offline behavior - graceful degradation ✅
- [ ] Performance acceptable ✅

### **Cloud Functions Testing**
- [ ] Deploy to staging: `firebase deploy --only functions --project staging`
- [ ] Test onWalkJoined trigger ✅
- [ ] Test onWalkCancelled trigger ✅
- [ ] Test onWalkUpdated trigger ✅
- [ ] Test onChatMessage trigger ✅
- [ ] Check function logs for errors ✅
- [ ] Verify notifications are sent ✅

### **Firebase Configuration Testing**
- [ ] Firestore rules allow all operations ✅
- [ ] FCM tokens storing correctly ✅
- [ ] Authentication working ✅
- [ ] No permission errors in logs ✅

---

## 🔧 Pre-Release Preparation (2-3 days before)

### **Version Bumping**

**Update pubspec.yaml:**
```yaml
version: 1.2.0+5  # major.minor.patch+buildNumber

# For releases: increment build number
# Format: 1.2.0+5 means:
#   - Public version: 1.2.0
#   - Build number: 5
```

```bash
# Verify version
cat pubspec.yaml | grep version
# Should output: version: 1.2.0+5
```

### **Update CHANGELOG**

```markdown
# [1.2.0] - 2026-01-15

## Added
- Feature 1: Description
- Feature 2: Description

## Changed
- Improvement 1: Description

## Fixed
- Bug fix 1: Description
- Bug fix 2: Description

## Security
- Security fix: Description

## Known Issues
- Issue 1 (will be fixed in 1.2.1)
```

### **Create Release Branch**

```bash
git checkout develop
git pull origin develop

# Create release branch
git checkout -b release/v1.2.0

# Bump versions
# Edit pubspec.yaml, CHANGELOG.md

# Commit
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): prepare v1.2.0"

# Push
git push -u origin release/v1.2.0

# Create PR to main
# On GitHub: Create PR from release/v1.2.0 to main
# Title: "Release v1.2.0"
```

### **Android Build Preparation**

```bash
# Build APK for testing
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Verify signing
# jarsigner -verify -verbose build/app/outputs/bundle/release/app-release.aab
```

**Files Generated:**
```
build/app/outputs/
├── flutter-apk/
│   ├── app-release.apk            ← For direct distribution
│   ├── app-armeabi-v7a-release.apk
│   ├── app-arm64-v8a-release.apk
│   └── app-x86_64-release.apk
└── bundle/release/
    └── app-release.aab            ← For Play Store
```

### **iOS Build Preparation**

```bash
# Build iOS release
flutter build ios --release

# Then in Xcode:
open ios/Runner.xcworkspace

# Select "Any iOS Device (arm64)"
# Product → Archive
# This creates .xcarchive file

# After archive:
# Window → Organizer
# Select archive → Distribute App
# Choose TestFlight or App Store
```

---

## 🚀 Release Day (Day 0)

### **Morning Checklist**
- [ ] All PRs merged to main and develop
- [ ] Version numbers updated and committed
- [ ] CHANGELOG updated with release notes
- [ ] Release branch created and tested
- [ ] Team lead reviews release branch
- [ ] Backup Firebase Firestore (manual export)

### **Deploy Cloud Functions (if changed)**

```bash
# Verify functions compile
cd functions
npm run lint
npm run build
cd ..

# Deploy to production
firebase deploy --only functions --project yallanemshiapp

# Verify deployment
firebase functions:log --tail

# Check all 4 functions are running
# ✅ onWalkJoined
# ✅ onWalkCancelled
# ✅ onWalkUpdated
# ✅ onChatMessage
```

### **Merge Release Branch**

```bash
# Ensure release branch is up to date
git checkout release/v1.2.0
git pull origin release/v1.2.0

# Merge to main (creates PR if on GitHub)
git checkout main
git pull origin main
git merge --no-ff release/v1.2.0

# Push to main
git push origin main

# Also merge back to develop
git checkout develop
git pull origin develop
git merge --no-ff main

# Push to develop
git push origin develop

# Tag the release
git checkout main
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# Delete release branch
git push origin --delete release/v1.2.0
git branch -d release/v1.2.0
```

### **Android Release (Play Store)**

```bash
# Prerequisites:
# - Signing certificate configured
# - app-release.aab built
# - Play Store account has permissions

# Option 1: Direct Upload (if you have Play Store access)
# 1. Go to Google Play Console
# 2. Select app → Release → Production
# 3. Click "Create new release"
# 4. Upload app-release.aab
# 5. Add release notes from CHANGELOG
# 6. Set rollout percentage (usually 100% for full release)
# 7. Review and confirm

# Option 2: Send to Partner for Upload
# 1. Generate signed APK:
#    flutter build apk --release
# 2. Send to partner with release notes
# 3. Partner uploads to Play Store
```

**Play Store Release Process:**
```
1. Create Release in Play Store Console
   ├─ Upload app-release.aab
   ├─ Add release notes (from CHANGELOG.md)
   ├─ Set rollout: 100% (full immediate rollout)
   └─ Review and confirm

2. Review takes 2-4 hours typically

3. After approval:
   ├─ Version live on Play Store
   ├─ Users see "Update available"
   └─ Can be mandatory after 72 hours
```

### **iOS Release (App Store)**

```bash
# Prerequisites:
# - Provisioning profile valid
# - Certificate not expired
# - Version number matches (unique for each build)

# 1. In Xcode:
open ios/Runner.xcworkspace
# Select Runner → General → Version and Build number match pubspec.yaml

# 2. Archive:
# Select "Any iOS Device (arm64)"
# Product → Archive

# 3. Distribute:
# Window → Organizer
# Select archive → Distribute App
# Choose "App Store Connect"
# Sign with certificate
# Upload

# 4. In App Store Connect:
# - Add release notes from CHANGELOG
# - Set version release date (immediate or scheduled)
# - Submit for review
```

**App Store Review Process:**
```
1. Submit archive in App Store Connect
   ├─ Add release notes (from CHANGELOG.md)
   ├─ Set release date (Immediate or Scheduled)
   └─ Submit for review

2. Review takes 24-48 hours typically

3. After approval:
   ├─ Version awaits release (if scheduled)
   ├─ Release on scheduled date
   ├─ Users see "Update available"
   └─ Force update after 30 days possible
```

### **Web Release (Firebase Hosting)**

```bash
# Build web version
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting --project yallanemshiapp

# Verify deployment
# Go to https://yallanemshiapp.web.app
# Check that new version is live

# Check version deployed
# Browser DevTools → Console → run:
# console.log(navigator.userAgent)  // Should show new version
```

### **Notify Users**

```
Create release announcement:
- Post on social media (if applicable)
- Send email to users (if mailing list)
- Update website/landing page
- Post in community (Discord, etc.)

Announcement Template:
"Yalla Nemshi v1.2.0 is now available!

What's new:
- Feature 1: Description
- Feature 2: Description
- Bug fixes and improvements

Update now to get the latest features!"
```

---

## ✅ Post-Release Monitoring (Day 1-7)

### **Hour 1-6 (Immediate Monitoring)**
- [ ] Check Firebase Crashlytics for crashes ⬇️ (should stay zero)
- [ ] Check Cloud Function logs for errors ⬇️ (should be clean)
- [ ] Monitor Firestore usage (should be normal)
- [ ] Check user reviews in stores (watch for issues)
- [ ] Have team on standby for quick hotfixes

### **Day 1 (Full Day Monitoring)**
- [ ] Crashlytics errors: 0-1 expected (if more, investigate)
- [ ] Function errors: 0-2 expected (monitor for patterns)
- [ ] User feedback: Positive or issues?
- [ ] Performance metrics: Normal?
- [ ] Prepare rollback plan if needed

### **Day 2-7 (Normal Monitoring)**
- [ ] Check Crashlytics daily
- [ ] Check function logs daily
- [ ] Review user reviews/ratings
- [ ] Collect issues for next patch
- [ ] Plan next sprint

### **Emergency Response Plan**

**If Critical Bug Found:**
```
1. Immediately investigate in Crashlytics
   - Get stack trace
   - Identify affected versions
   - Count affected users

2. Severity Assessment:
   - Critical (> 1000 users affected): Hotfix immediately
   - High (100-1000 users): Hotfix within 24 hours
   - Medium (10-100 users): Plan for next version
   - Low (< 10 users): Monitor, fix when convenient

3. For Critical Issues:
   git checkout main
   git pull origin main
   git checkout -b hotfix/issue-description
   # Fix the issue
   git add .
   git commit -m "fix: critical issue description"
   git push -u origin hotfix/issue-description
   # Create PR to main (fast track review)
   # Merge → Deploy immediately

4. Communicate:
   - Notify partner immediately
   - Update users via app notification (if applicable)
   - Post status update
```

### **Performance Check**

```
Review metrics:
- Firestore read/write operations (should be proportional to users)
- Cloud Function invocation rate (should be proportional to app actions)
- Storage usage (should only grow with user uploads)
- Network egress (should be reasonable)

If metrics spike unexpectedly:
1. Check for infinite loops in code
2. Check for unoptimized queries
3. Check Cloud Function logs for timeouts
4. Review user count increase (normal growth vs unusual spike)
5. Check for bot activity or abuse
```

---

## 🔄 Post-Release Follow-up (Week 1-2)

### **Collect Feedback**
- [ ] Review app store ratings/reviews
- [ ] Check user feedback channels
- [ ] Compile bug reports
- [ ] Note feature requests

### **Release Retrospective**
- [ ] Team meeting to discuss release
- [ ] What went well?
- [ ] What could be improved?
- [ ] Update release process documentation

### **Plan Next Release**
- [ ] Create issues for bugs found
- [ ] Prioritize features for next version
- [ ] Estimate effort for next release
- [ ] Schedule next release (e.g., 2-4 weeks out)

---

## 📊 Release Metrics to Track

### **Before Release**
| Metric | Target |
|--------|--------|
| Unit test coverage | > 80% |
| Lint issues | 0 |
| Code review approval | ≥ 1 |
| Devices tested | Android, iOS, Web |
| Function tests | All 4 passed |

### **After Release (Week 1)**
| Metric | Target |
|--------|--------|
| Crash rate | < 0.1% (< 1 crash per 1000 users) |
| Firestore errors | < 5% of operations |
| FCM delivery rate | > 95% |
| User satisfaction (stars) | ≥ 4.0 |
| Performance (load time) | < 3 seconds |

---

## 🎯 Release Checklist Summary

```
WEEK 1 BEFORE:
  [ ] Scope defined
  [ ] Tests passing
  [ ] Code reviewed
  [ ] CHANGELOG updated

2-3 DAYS BEFORE:
  [ ] Version bumped
  [ ] Functions tested
  [ ] Builds successful
  [ ] Release branch created

RELEASE DAY:
  [ ] Cloud Functions deployed
  [ ] Release branch merged
  [ ] Android uploaded to Play Store
  [ ] iOS submitted to App Store
  [ ] Web deployed to Firebase Hosting
  [ ] Users notified

AFTER RELEASE:
  [ ] Monitor Crashlytics
  [ ] Monitor function logs
  [ ] Collect user feedback
  [ ] Plan next release
```

---

## 📞 Release Team Responsibilities

### **Product Lead**
- Defines features and scope
- Prepares release notes
- Communicates with users

### **Engineering Lead**
- Reviews release branch
- Approves deployment
- Monitors for critical issues
- Makes rollback decision if needed

### **Mobile Developer**
- Builds and uploads to stores
- Runs tests
- Monitors immediate post-release

### **Backend/DevOps** (if applicable)
- Deploys Cloud Functions
- Monitors server-side metrics
- Ensures database integrity

---

## 📚 Related Documentation

- [Git Workflow](./GIT_WORKFLOW.md) - Branch management
- [Testing Strategy](./TESTING_STRATEGY.md) - Testing approach
- [Mobile Specific](./MOBILE_SPECIFIC.md) - Platform deployment details
- [Monitoring & Troubleshooting](./MONITORING_TROUBLESHOOTING.md) - Debugging

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team  
**Average Release Cycle:** 2-4 weeks  
**Supported Platforms:** Android, iOS, Web
