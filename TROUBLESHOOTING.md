# TennisCoach Troubleshooting Guide

This guide helps you resolve common issues with the TennisCoach iOS app.

---

## Table of Contents

1. [Camera Issues](#camera-issues)
2. [Recording Problems](#recording-problems)
3. [Video Playback Issues](#video-playback-issues)
4. [AI Analysis Problems](#ai-analysis-problems)
5. [API Key Issues](#api-key-issues)
6. [Upload Failures](#upload-failures)
7. [Photos Library Issues](#photos-library-issues)
8. [Build & Development Issues](#build--development-issues)
9. [Performance Issues](#performance-issues)

---

## Camera Issues

### Black Screen on Recording Tab

**Symptoms:**
- Camera preview shows solid black screen
- No error message displayed
- Record button may be disabled

**Solutions:**

1. **Check Camera Permission**
   - Open iOS Settings → TennisCoach
   - Ensure "Camera" is set to "Allow"
   - Return to app and try again

2. **Wait for Initialization**
   - Look for "正在启动相机..." (Initializing camera) indicator
   - Wait up to 5 seconds for camera to initialize
   - If stuck, tap the Retry button

3. **Restart the App**
   - Force quit TennisCoach (swipe up from app switcher)
   - Reopen the app
   - Navigate to Recording tab

4. **Restart Device**
   - If issue persists, restart your iPhone
   - This clears any stuck camera sessions

**Technical Details:**
The camera uses AVFoundation's `AVCaptureSession`. On first launch, permission request and session configuration happen asynchronously. The app now shows a loading indicator during this process.

---

### Camera Frozen After Tab Switch

**Symptoms:**
- Camera preview shows last frame (frozen image)
- Switching to Videos tab and back doesn't help

**Solutions:**

1. **Wait for Auto-Resume**
   - The camera should automatically resume within 1-2 seconds
   - Look for the loading indicator

2. **Force Refresh**
   - Switch to another app briefly
   - Return to TennisCoach
   - Navigate to Recording tab

**Technical Details:**
Fixed in v1.1. The `RecordViewModel` now implements `resumeSession()` which is called on `onAppear`. If you still experience this issue, ensure you have the latest version.

---

### "相机不可用" (Camera Unavailable) Error

**Symptoms:**
- Error message appears instead of camera preview
- Retry button doesn't help

**Solutions:**

1. **Check for Other Apps Using Camera**
   - Close any app that might be using the camera (FaceTime, Zoom, etc.)
   - Return to TennisCoach

2. **Check Physical Camera**
   - Ensure nothing is blocking the camera lens
   - Try the native Camera app to verify hardware works

3. **Check Restrictions**
   - Settings → Screen Time → Content & Privacy Restrictions
   - Ensure Camera is not restricted

---

## Recording Problems

### Recording Stops Unexpectedly

**Symptoms:**
- Recording ends before you tap stop
- No video saved
- Error message may appear

**Solutions:**

1. **Check Storage Space**
   - Settings → General → iPhone Storage
   - Ensure at least 1GB free space
   - Videos at 60fps use ~100MB per minute

2. **Avoid Background Interruptions**
   - Don't switch apps during recording
   - Disable Do Not Disturb to avoid call interruptions
   - Keep screen on (disable auto-lock during recording)

3. **Temperature Issues**
   - Recording in direct sunlight can cause thermal throttling
   - If phone feels hot, wait for it to cool down

---

### "当前没有正在进行的录制" Error

**Symptoms:**
- Error appears when trying to record
- Usually on first launch

**Solutions:**

This issue was fixed in v1.1. The error occurred when trying to stop a recording that hadn't started due to camera initialization race condition.

1. **Update to Latest Version**
   - Pull latest code from GitHub
   - Rebuild and run

2. **Dismiss and Retry**
   - Tap "确定" to dismiss the error
   - Wait for camera to fully initialize (loading indicator disappears)
   - Try recording again

---

### No Audio in Recorded Videos

**Symptoms:**
- Video plays but has no sound
- Microphone permission was denied

**Solutions:**

1. **Check Microphone Permission**
   - Settings → TennisCoach → Microphone → Enable
   - Re-record the video

2. **Check Mute Switch**
   - Ensure the physical mute switch is not enabled
   - Volume should be audible

---

## Video Playback Issues

### Videos Won't Play

**Symptoms:**
- Tapping video shows black screen or loading forever
- Play button doesn't respond

**Solutions:**

1. **Check Video File Exists**
   - The video file may have been deleted from storage
   - Try recording a new video

2. **Force Quit and Reopen**
   - Close the app completely
   - Reopen and try playing again

3. **Check Storage Corruption**
   - If multiple videos fail, storage may be corrupted
   - Backup data and reinstall the app

---

### Thumbnail Not Showing

**Symptoms:**
- Video list shows gray placeholder instead of thumbnail
- Video plays correctly

**Solutions:**

This is usually a one-time generation issue:

1. **Wait for Generation**
   - Thumbnails generate asynchronously after recording
   - May take a few seconds for long videos

2. **Scroll Away and Back**
   - Thumbnail may load lazily
   - Scroll the video out of view and back

---

## AI Analysis Problems

### "分析失败" (Analysis Failed) Error

**Symptoms:**
- Error appears after video uploads
- No AI response received

**Solutions:**

1. **Check Internet Connection**
   - Ensure stable WiFi or cellular connection
   - Try loading a webpage to verify connectivity

2. **Video Too Long**
   - Gemini has processing limits
   - Try with a shorter video (under 2 minutes)

3. **API Rate Limiting**
   - Free tier has limited requests per minute
   - Wait 1-2 minutes and try again

4. **Check API Key**
   - Verify key is valid in Settings
   - Tap "Test Connection"

---

### Streaming Response Stops Mid-Way

**Symptoms:**
- AI starts responding but stops before finishing
- Cursor keeps blinking but no new text

**Solutions:**

1. **Wait Patiently**
   - Long responses may have pauses
   - Wait up to 30 seconds before assuming failure

2. **Check Network Stability**
   - Streaming requires stable connection
   - Switch from cellular to WiFi if available

3. **Send a Follow-Up**
   - If response seems complete but stopped abruptly
   - Ask "请继续" (please continue) to prompt more

---

### Wrong Language Response

**Symptoms:**
- AI responds in English instead of Chinese
- Or vice versa

**Solutions:**

The app is configured for Chinese responses. If you get English:

1. **Check Prompts.swift**
   - System prompts are in Chinese
   - Ensure file wasn't modified

2. **Be Explicit in Questions**
   - Start your question with "请用中文回答：" (Please answer in Chinese:)

---

## API Key Issues

### "API Key 未设置或无效" Error

**Symptoms:**
- Error appears when starting analysis
- Settings shows "Not Set" for API key

**Solutions:**

1. **Enter API Key**
   - Go to Settings tab
   - Tap "Gemini API Key"
   - Enter your key from [Google AI Studio](https://aistudio.google.com/apikey)

2. **Verify Key Format**
   - Key should start with "AI"
   - Should be approximately 39 characters
   - No spaces or special characters

3. **Test the Connection**
   - After entering, tap "Test Connection"
   - Should show success message

---

### API Key Not Saving

**Symptoms:**
- Enter key, but it's gone after restarting app
- Settings always shows "Not Set"

**Solutions:**

1. **Keychain Access Issue**
   - Ensure app has Keychain entitlements
   - Check Xcode signing & capabilities

2. **Reinstall App**
   - Delete TennisCoach
   - Reinstall from Xcode
   - Re-enter API key

---

### "Test Connection" Fails

**Symptoms:**
- Key entered but test fails
- Network error or 401 error

**Solutions:**

1. **Verify Key at Google AI Studio**
   - Visit [https://aistudio.google.com/apikey](https://aistudio.google.com/apikey)
   - Ensure key is active and not revoked

2. **Check API Quota**
   - Free tier has limited requests
   - Check usage in Google Cloud Console

3. **Regenerate Key**
   - Create a new key at AI Studio
   - Delete old key
   - Enter new key in app

---

## Upload Failures

### "视频上传失败" (Video Upload Failed)

**Symptoms:**
- Progress bar starts but fails
- Error message after upload attempt

**Solutions:**

1. **Check File Size**
   - Videos over 100MB may fail
   - Record shorter clips (under 2 minutes)

2. **Check Network**
   - Uploads need stable connection
   - WiFi recommended over cellular

3. **Retry Automatically**
   - App has built-in retry logic
   - Wait for automatic retry (up to 5 attempts)

4. **Manual Retry**
   - If all retries fail, go back and tap video again
   - Analysis will re-attempt upload

---

### Upload Progress Stuck at 0%

**Symptoms:**
- Progress indicator shows but never moves
- Eventually times out

**Solutions:**

1. **Check Network Connectivity**
   - Ensure internet access
   - Try switching networks

2. **Video File Corrupted**
   - The video file may be corrupted
   - Try recording a new video

3. **Restart App**
   - Force quit and reopen
   - Try upload again

---

## Photos Library Issues

### "Save to Photos" Button Not Working

**Symptoms:**
- Tap button but nothing happens
- No permission prompt appears

**Solutions:**

1. **Check Permission**
   - Settings → TennisCoach → Photos
   - Set to "Add Photos Only" or "Full Access"

2. **Check Photos App**
   - Video may have saved but not visible immediately
   - Open Photos app and check "Recents"

---

### "请在设置中允许访问相册" Error

**Symptoms:**
- Error when trying to save to Photos
- Permission was previously denied

**Solutions:**

1. **Grant Permission**
   - Settings → TennisCoach → Photos → Add Photos Only
   - Return to app and try again

2. **Reset Permission**
   - If stuck, reset all permissions:
   - Settings → General → Transfer or Reset → Reset → Reset Location & Privacy
   - Re-grant permissions when prompted

---

## Build & Development Issues

### "No such module 'AVFoundation'" Error

**Symptoms:**
- Build fails with missing module error
- Red error in Xcode

**Solutions:**

1. **Clean Build Folder**
   - Xcode → Product → Clean Build Folder (Cmd + Shift + K)
   - Rebuild (Cmd + B)

2. **Check Target Settings**
   - Ensure building for iOS, not macOS
   - Check deployment target is iOS 17.0+

---

### Simulator Camera Not Working

**Symptoms:**
- Camera features don't work in Simulator
- Black screen or errors

**Solutions:**

**Expected Behavior:** iOS Simulator doesn't have a camera. Use a physical device:

1. Connect iPhone via USB
2. Select your device in Xcode
3. Build and run

For testing without camera:
- Use mock data in tests
- Check `VideoRecorderTests.swift` for patterns

---

### SwiftData Migration Errors

**Symptoms:**
- App crashes on launch after model changes
- "Failed to create persistent ModelContainer"

**Solutions:**

1. **Delete App Data (Development)**
   - Delete app from Simulator/device
   - Reinstall fresh

2. **Add Migration (Production)**
   - Create a `VersionedSchema` for the model
   - Add migration plan

---

## Performance Issues

### App Freezes During Recording

**Symptoms:**
- UI becomes unresponsive
- Recording may still work in background

**Solutions:**

1. **Close Other Apps**
   - Free up system resources
   - Close memory-intensive apps

2. **Restart Device**
   - Clears system caches
   - Frees up memory

3. **Check Storage**
   - Low storage can cause slowdowns
   - Free up at least 2GB

---

### Slow Video List Loading

**Symptoms:**
- Video list takes long to appear
- Thumbnails load slowly

**Solutions:**

1. **Reduce Video Count**
   - Delete old videos you don't need
   - Large libraries take longer to load

2. **Wait for Thumbnail Cache**
   - First load is slowest
   - Subsequent loads use cache

---

### High Battery Usage

**Symptoms:**
- Battery drains quickly during use
- Phone gets warm

**Solutions:**

1. **Reduce Recording Quality**
   - 60fps uses more power than 30fps
   - Consider shorter recordings

2. **Close When Not Using**
   - Don't leave app running in background
   - Camera session consumes power

---

## Getting More Help

If none of the above solutions work:

1. **Check GitHub Issues**
   - [TennisCoach Issues](https://github.com/leemingee/TennisCoach/issues)
   - Search for similar problems

2. **File a Bug Report**
   - Include iOS version
   - Include app version
   - Describe steps to reproduce
   - Attach crash logs if available

3. **Contact Developer**
   - Email: leemingee1995@gmail.com
   - Include device model and iOS version

---

*Last Updated: 2025-12-04*
