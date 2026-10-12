#!/usr/bin/env bash
# Type-checks the plugin's Kotlin against the Android 14 framework and runs the
# RuleEngine parity checks (must match lib/app_rules.dart). Needs: kotlinc, and
# android-all from Maven Central:
#   curl -o android-all.jar https://repo1.maven.org/maven2/org/robolectric/android-all/14-robolectric-10818077/android-all-14-robolectric-10818077.jar
set -euo pipefail
cd "$(dirname "$0")"
ANDROID_ALL=${ANDROID_ALL:-android-all.jar}
OUT=$(mktemp -d)
kotlinc -jvm-target 17 -cp "$ANDROID_ALL" -d "$OUT/main" stubs/*.kt ../android/src/main/kotlin/lk/rakawala/app_control/*.kt
kotlinc -jvm-target 17 -cp "$ANDROID_ALL:$OUT/main" -d "$OUT/check" ParityCheck.kt
kotlin -cp "$ANDROID_ALL:$OUT/main:$OUT/check" ParityCheckKt | tee "$OUT/result.txt"
grep -q "ALL PARITY CHECKS PASSED" "$OUT/result.txt"
