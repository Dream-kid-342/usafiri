#!/bin/bash

# Target APK Path
TARGET_APK_PATH="C:/Users/Public/pm_pro_build/app/outputs/apk/debug/app-debug.apk"

echo "----------------------------------------"
echo "Checking if APK exists at target location..."
echo "----------------------------------------"

if [ ! -f "$TARGET_APK_PATH" ]; then
    echo "APK not found at target. Building locally..."
    echo "----------------------------------------"
    flutter build apk --debug
    
    echo "----------------------------------------"
    echo "Copying APK to target location..."
    echo "----------------------------------------"
    
    mkdir -p $(dirname "$TARGET_APK_PATH")
    cp build/app/outputs/flutter-apk/app-debug.apk "$TARGET_APK_PATH"
else
    echo "APK found at target location."
fi

echo "----------------------------------------"
echo "Launching app from: $TARGET_APK_PATH"
echo "----------------------------------------"

flutter run --use-application-binary="$TARGET_APK_PATH" -d LRVWEQ8XJZ89WK4H
