#!/bin/bash

# Target APK Path
TARGET_APK_PATH="C:/Users/Public/pm_pro_build/app/outputs/apk/debug/app-debug.apk"
# Local Build Path
LOCAL_APK_PATH="android/app/build/outputs/apk/debug/app-debug.apk"

echo "----------------------------------------"
echo "Building APK..."
echo "----------------------------------------"

# Use cmd.exe /c for gradlew on Windows for better compatibility
cd android || exit 1
cmd.exe /c "gradlew.bat assembleDebug"

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

cd ..

echo "----------------------------------------"
echo "Refreshed APK. Copying to target location..."
echo "----------------------------------------"

# Ensure target directory exists (using Power Shell for safety on Windows paths)
powershell.exe -Command "New-Item -ItemType Directory -Force -Path (Split-Path '$TARGET_APK_PATH')"

# Copy the fresh build to the target path
cp "$LOCAL_APK_PATH" "$TARGET_APK_PATH"

if [ $? -ne 0 ]; then
    echo "Failed to copy APK to $TARGET_APK_PATH"
    echo "Using local built APK instead..."
    FINAL_PATH="$LOCAL_APK_PATH"
else
    echo "APK copied successfully."
    FINAL_PATH="$TARGET_APK_PATH"
fi

echo "----------------------------------------"
echo "Launching app from: $FINAL_PATH"
echo "----------------------------------------"

flutter run --use-application-binary="$FINAL_PATH" -d LRVWEQ8XJZ89WK4H
