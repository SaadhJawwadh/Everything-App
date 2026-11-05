#!/bin/bash
# Release Automation Script (CI/CD Trigger)
# Usage: ./deploy.sh <version>
#
# The CI pipeline auto-computes versionCode from the tag:
#   versionCode = major * 10000 + minor * 100 + patch
# e.g. v1.16.0 → versionCode 11600

NEW_VERSION=$1

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: ./deploy.sh <version>"
  echo "Example: ./deploy.sh 1.16.0"
  exit 1
fi

# 2. Verify CHANGELOG.md update
if ! grep -q "## $NEW_VERSION" CHANGELOG.md; then
  echo "❌ Error: Version $NEW_VERSION not found in CHANGELOG.md. Please document this release first."
  exit 1
fi

# 2b. Verify PLAY_STORE_NOTES.md update
if [ ! -f PLAY_STORE_NOTES.md ] || ! grep -q "<en-US>" PLAY_STORE_NOTES.md || ! grep -q "<ta-IN>" PLAY_STORE_NOTES.md; then
  echo "❌ Error: PLAY_STORE_NOTES.md is missing or does not contain <en-US> and <ta-IN> tags."
  echo "Please update PLAY_STORE_NOTES.md with current bilingual release notes before deploying."
  exit 1
fi

# 3. Quality Gate: Run static analysis
echo "🔍 Running static analysis..."
if ! flutter analyze; then
  echo "❌ Error: static analysis failed. Fix all warnings and errors before deploying."
  exit 1
fi

# 4. Quality Gate: Run unit tests
echo "🧪 Running unit tests..."
if ! flutter test; then
  echo "❌ Error: Unit tests failed. Release aborted."
  exit 1
fi

# Compute versionCode locally for pubspec update
IFS='.' read -r MAJOR MINOR PATCH <<< "$NEW_VERSION"
BUILD_NUMBER=$(( ${MAJOR:-0} * 10000 + ${MINOR:-0} * 100 + ${PATCH:-0} ))

echo "Preparing Release $NEW_VERSION+$BUILD_NUMBER..."

# 5. Extract release notes from CHANGELOG.md to RELEASE_NOTES.md
echo "Extracting release notes from CHANGELOG.md..."
awk "/## \[?$NEW_VERSION\]?/{flag=1;next} /## \[?[0-9]+\.[0-9]+\.[0-9]+\]?/{flag=0} flag" CHANGELOG.md > RELEASE_NOTES.md

# 6. Update pubspec.yaml
echo "Updating version in pubspec.yaml..."
sed -i '' "s/version: .*/version: $NEW_VERSION+$BUILD_NUMBER/" pubspec.yaml

# 7. Stage and Commit version bump
echo "Staging changes..."
git add -A
git commit -m "chore(release): prepare release v$NEW_VERSION" || echo "No changes to commit, proceeding..."

# 8. Tag (Force update to ensure it points to latest)
TAG="v$NEW_VERSION"
echo "Tagging version $TAG..."
git tag -d "$TAG" 2>/dev/null # Delete local tag if exists
git push origin :refs/tags/"$TAG" 2>/dev/null # Delete remote tag if exists
git tag -a "$TAG" -m "Release $TAG"

# 9. Push
echo "Pushing to GitHub..."
git push origin HEAD:main
git push origin "$TAG"

echo "DONE! GitHub Action has been triggered for $TAG."
echo "Check progress at: https://github.com/SaadhJawwadh/Note-taking/actions"
