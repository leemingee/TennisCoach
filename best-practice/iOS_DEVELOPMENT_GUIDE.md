# iOS Development Best Practices Guide
## TennisCoach Project

> A comprehensive guide for developers who are not iOS experts, covering project setup, development workflow, code quality, testing, and debugging for the TennisCoach app.

---

## Table of Contents

1. [Xcode Project Setup](#1-xcode-project-setup)
2. [Development Workflow](#2-development-workflow)
3. [Code Quality Standards](#3-code-quality-standards)
4. [Build & Compile Best Practices](#4-build--compile-best-practices)
5. [Unit Testing Standards](#5-unit-testing-standards)
6. [Code Review Checklist](#6-code-review-checklist)
7. [Debugging Tips](#7-debugging-tips)
8. [Common Pitfalls & Solutions](#8-common-pitfalls--solutions)

---

## 1. Xcode Project Setup

### 1.1 Creating the Xcode Project from Scratch

If you need to create a new Xcode project for TennisCoach:

#### Step 1: Create New Project

1. Open Xcode (version 15.0+)
2. Select **File > New > Project** (or press `Cmd + Shift + N`)
3. Choose **iOS** tab, then select **App** template
4. Click **Next**

#### Step 2: Configure Project Settings

Fill in the following details:

| Field | Value | Notes |
|-------|-------|-------|
| Product Name | `TennisCoach` | This will be your app's display name |
| Team | Select your Apple Developer Team | Required for device testing |
| Organization Identifier | `com.yourname` or `com.yourcompany` | Reverse domain notation |
| Bundle Identifier | Auto-generated: `com.yourname.TennisCoach` | Must be unique |
| Interface | **SwiftUI** | Modern declarative UI framework |
| Language | **Swift** | Latest Swift version |
| Storage | **SwiftData** | Apple's modern persistence framework |
| Include Tests | **Checked** | Always include test targets |

5. Click **Next**
6. Choose a location (recommended: `/Users/yoyo/src/TennisCoach`)
7. Ensure **Create Git repository** is checked (recommended)
8. Click **Create**

### 1.2 Adding Existing Source Files

If you already have source code files:

#### Method 1: Drag and Drop (Recommended)

1. In Xcode, open the Project Navigator (`Cmd + 1`)
2. Right-click on the `TennisCoach` group (blue folder icon)
3. Select **Add Files to "TennisCoach"...**
4. Navigate to your source files
5. **Important**: Check these options:
   - **Copy items if needed**: CHECKED (creates a copy in your project)
   - **Create groups**: SELECTED (organizes files in folders)
   - **Add to targets**: Check **TennisCoach** (main target)
6. Click **Add**

#### Method 2: File System Organization (Recommended Structure)

Organize your files to match this structure:

```
TennisCoach/
├── TennisCoachApp.swift          # App entry point
├── ContentView.swift             # Main TabView
├── Models/
│   ├── Video.swift
│   ├── Conversation.swift
│   └── Message.swift
├── Services/
│   ├── GeminiService.swift
│   ├── VideoRecorder.swift
│   ├── VideoCompressor.swift
│   └── Prompts.swift
├── Views/
│   ├── Recording/
│   │   ├── RecordView.swift
│   │   └── RecordViewModel.swift
│   ├── VideoList/
│   │   └── VideoListView.swift
│   └── Chat/
│       ├── ChatView.swift
│       └── ChatViewModel.swift
├── Utilities/
│   ├── Constants.swift
│   ├── SecureKeyManager.swift
│   ├── APIKeyValidator.swift
│   ├── AppLogger.swift
│   └── RetryPolicy.swift
├── Resources/
│   └── Assets.xcassets
└── PrivacyInfo.xcprivacy         # Privacy manifest
```

**To create groups in Xcode:**
1. Right-click on `TennisCoach` folder
2. Select **New Group**
3. Name it (e.g., "Models", "Services", "Views")
4. Drag files into the appropriate groups

### 1.3 Configuring Signing & Capabilities

#### Automatic Signing (Recommended for Beginners)

1. Select the **TennisCoach** project in Project Navigator
2. Select the **TennisCoach** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown
6. Xcode will automatically generate a provisioning profile

#### Manual Signing (Advanced)

Only use if you have specific provisioning profile requirements:
1. Uncheck **Automatically manage signing**
2. Select **Provisioning Profile** manually
3. Ensure **Certificate** is valid in Keychain Access

#### Common Signing Issues

**Problem**: "Failed to register bundle identifier"
- **Solution**: Change the bundle identifier to make it unique
- Go to **Build Settings** > search "Product Bundle Identifier"
- Modify to something like `com.yourname.TennisCoach.unique`

**Problem**: "No signing certificate found"
- **Solution**: Add your Apple ID in Xcode Preferences
- Go to **Xcode > Settings > Accounts**
- Click `+` to add your Apple ID
- Download certificates

### 1.4 Adding Required Capabilities

TennisCoach requires these capabilities:

1. Select **TennisCoach** target
2. Go to **Signing & Capabilities** tab
3. Click `+ Capability` button
4. Add the following if needed:
   - **Background Modes** (if implementing background upload)
     - Audio, AirPlay, and Picture in Picture (for video recording)

### 1.5 Configuring Info.plist for Privacy Permissions

iOS requires explicit permission descriptions for sensitive features.

#### Method 1: Using Xcode UI (Easier)

1. Select **TennisCoach** project
2. Select **TennisCoach** target
3. Go to **Info** tab
4. Hover over any key and click `+` button
5. Add these keys:

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Camera Usage Description` | String | `We need camera access to record your tennis practice videos` |
| `Privacy - Microphone Usage Description` | String | `We need microphone access to record audio with your videos` |
| `Privacy - Photo Library Usage Description` | String | `We need photo library access to save your tennis videos` |

#### Method 2: Editing Info.plist Source (Advanced)

1. Right-click on `Info.plist`
2. Select **Open As > Source Code**
3. Add these entries:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to record your tennis practice videos</string>

<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to record audio with your videos</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to save your tennis videos</string>
```

**Important**: Without these descriptions, your app will crash when requesting permissions.

### 1.6 Adding PrivacyInfo.xcprivacy File

Apple requires a privacy manifest for apps that access certain APIs.

#### Step 1: Create the Privacy Manifest

1. Right-click on `TennisCoach` folder in Project Navigator
2. Select **New File...**
3. Search for "Privacy" or scroll to find **App Privacy**
4. Select **App Privacy** template
5. Name it: `PrivacyInfo.xcprivacy`
6. Ensure target is **TennisCoach**
7. Click **Create**

#### Step 2: Configure Privacy Manifest

Open `PrivacyInfo.xcprivacy` and ensure it contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- No tracking -->
    <key>NSPrivacyTracking</key>
    <false/>

    <!-- No tracking domains -->
    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <!-- Data collected (videos for app functionality) -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeVideoOrMovies</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <!-- APIs accessed -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>E174.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Reason Codes Explained:**
- **C617.1**: File timestamp access for displaying video creation dates
- **E174.1**: Disk space check to ensure sufficient storage for video recording

### 1.7 Environment Variable Setup for API Key

TennisCoach uses Google Gemini API, which requires an API key.

#### Option 1: Xcode Scheme Environment Variable (Recommended for Development)

1. In Xcode, go to **Product > Scheme > Edit Scheme...** (or press `Cmd + <`)
2. Select **Run** in the left sidebar
3. Go to **Arguments** tab
4. Under **Environment Variables** section:
   - Click `+` button
   - Name: `GEMINI_API_KEY`
   - Value: `your-actual-api-key-here`
   - Check the **Active** checkbox
5. Click **Close**

**Advantages:**
- Secure (not committed to version control)
- Easy to change per scheme (Debug/Release)
- Automatically saved to Keychain on first run

**Disadvantages:**
- Need to set up on each machine
- Other team members need to configure separately

#### Option 2: Keychain (Recommended for Production)

The app automatically saves the API key to Keychain if provided via environment variable.

To manually set:

```swift
// One-time setup (e.g., in a setup screen)
try? SecureKeyManager.shared.saveGeminiAPIKey("your-api-key")
```

**Advantages:**
- Most secure
- Persists across app launches
- User can enter key in the app

**Disadvantages:**
- Requires UI for key input
- Harder to debug

#### Option 3: Hardcoding (NOT RECOMMENDED - Development Only)

Only for quick testing, never commit:

Edit `TennisCoach/Utilities/Constants.swift`:

```swift
static var apiKey: String {
    return "your-api-key-here" // TEMPORARY - DO NOT COMMIT
}
```

**Warning**: Never commit hardcoded keys to version control!

#### Getting Your Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Copy the key
5. Set it using one of the methods above

### 1.8 Build Settings Configuration

Recommended build settings for TennisCoach:

1. Select **TennisCoach** project
2. Select **TennisCoach** target
3. Go to **Build Settings** tab
4. Search for each setting:

| Setting | Debug | Release | Notes |
|---------|-------|---------|-------|
| Swift Language Version | Swift 5 | Swift 5 | Latest stable |
| iOS Deployment Target | iOS 17.0 | iOS 17.0 | Matches project requirement |
| Enable Bitcode | No | No | Deprecated by Apple |
| Swift Optimization Level | -Onone | -O | Fast debug builds |
| Compilation Mode | Incremental | Whole Module | Faster dev builds |

### 1.9 Verifying Project Setup

Before starting development, verify:

**Checklist:**
- [ ] Project builds without errors (`Cmd + B`)
- [ ] Target deployment is iOS 17.0+
- [ ] Signing is configured (no red errors in Signing & Capabilities)
- [ ] Info.plist contains camera/microphone descriptions
- [ ] PrivacyInfo.xcprivacy is added to project
- [ ] GEMINI_API_KEY environment variable is set
- [ ] Test target builds (`Cmd + Shift + U`)

**Quick verification commands:**

```bash
# From project directory
cd /Users/yoyo/src/TennisCoach

# Check if project file exists
ls -la *.xcodeproj

# Verify source files
find TennisCoach -name "*.swift" | wc -l
# Should show ~25+ files

# Check for privacy manifest
find . -name "PrivacyInfo.xcprivacy"
```

---

## 2. Development Workflow

### 2.1 Recommended Development Sequence

Follow this sequence for efficient iOS development:

```
1. Plan → 2. Code → 3. Build → 4. Test → 5. Review → 6. Commit
   ↑                                                        ↓
   └────────────────── Iterate ──────────────────────────┘
```

#### Phase 1: Plan (5-10 minutes)

Before writing code:
- [ ] Understand the feature requirement
- [ ] Review DESIGN.md for architecture patterns
- [ ] Identify which files need changes
- [ ] Check if new tests are needed
- [ ] Estimate time required

**Example Planning Session:**
```
Feature: Add video deletion
Files to modify:
  - VideoListView.swift (add delete button)
  - Video.swift (add deletion logic)
  - VideoListViewModel.swift (handle deletion)
Tests to add:
  - VideoModelTests (test deletion)
  - VideoListViewModelTests (test ViewModel deletion)
Time estimate: 1-2 hours
```

#### Phase 2: Code (Bulk of time)

Write code following [Code Quality Standards](#3-code-quality-standards):

**Best Practices:**
1. Start with the model/data layer
2. Then service/business logic
3. Finally UI/presentation layer
4. Write tests as you go (not after)

**Small, Focused Commits:**
- Commit after each logical change
- Don't wait until everything is done
- Use descriptive commit messages

**Example Workflow:**
```bash
# 1. Create a feature branch (recommended)
git checkout -b feature/video-deletion

# 2. Make changes in Xcode
# ... code ...

# 3. Build frequently (Cmd + B)

# 4. Commit incrementally
git add TennisCoach/Models/Video.swift
git commit -m "Add deletion method to Video model"

git add TennisCoach/Views/VideoList/VideoListView.swift
git commit -m "Add delete button to VideoListView"
```

#### Phase 3: Build (Continuous)

Build frequently to catch errors early.

**When to Build:**

| Scenario | Build Type | Shortcut |
|----------|------------|----------|
| After every significant code change | Regular Build | `Cmd + B` |
| Syntax/type errors | Regular Build | `Cmd + B` |
| Changed project settings | Clean Build | `Cmd + Shift + K` then `Cmd + B` |
| After merging branches | Clean Build | `Cmd + Shift + K` then `Cmd + B` |
| Mysterious errors | Clean Build Folder | Hold `Option`, `Product > Clean Build Folder` |
| Before committing | Regular Build | `Cmd + B` |

**Incremental vs Clean Builds:**

- **Incremental Build** (`Cmd + B`): Only rebuilds changed files (fast, 5-30 seconds)
- **Clean Build** (`Cmd + Shift + K` then `Cmd + B`): Rebuilds everything (slow, 1-3 minutes)
- **Clean Build Folder** (Option key + Product menu): Nuclear option, deletes all intermediate files

**When to Clean Build:**
- Build succeeds but app crashes at runtime
- Xcode shows stale errors that don't exist
- After updating Xcode
- After changing build settings
- Swift compiler behaving strangely

#### Phase 4: Test (Before every commit)

Run tests to ensure nothing broke.

**Testing Sequence:**

```bash
# 1. Run all tests
Cmd + U

# 2. Run specific test file
# Right-click on test file > Run "TestFileName"

# 3. Run single test method
# Click diamond icon next to test method

# 4. Check code coverage (optional)
# Product > Test > Show Code Coverage
```

**What to Test:**
- [ ] All existing tests pass
- [ ] New functionality has tests
- [ ] Edge cases are covered
- [ ] Error handling works

#### Phase 5: Review (Self-review before PR)

Before creating a pull request or committing:

**Self-Review Checklist:**
- [ ] Code follows Swift style guide
- [ ] No commented-out code
- [ ] No TODO comments (create issues instead)
- [ ] No debug print statements
- [ ] Documentation is updated
- [ ] Tests are included
- [ ] Build succeeds with no warnings
- [ ] App runs on simulator and device

**Use Xcode's Comparison Tool:**
```
1. Select files in Project Navigator
2. Right-click > Source Control > Show Changes
3. Review every change
4. Ask: "Would I approve this in a PR?"
```

#### Phase 6: Commit (Atomic commits)

Create clean, atomic commits:

**Good Commit Messages:**
```bash
# Format: <type>: <subject>

# Examples:
git commit -m "feat: Add video deletion functionality"
git commit -m "fix: Resolve camera permission crash on iOS 17"
git commit -m "refactor: Extract video compression to separate service"
git commit -m "test: Add tests for GeminiService upload retry"
git commit -m "docs: Update README with API key setup instructions"
git commit -m "style: Format code per Swift style guide"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `test`: Adding tests
- `docs`: Documentation
- `style`: Formatting, no logic change
- `chore`: Build process, dependencies

### 2.2 Using Xcode Efficiently

#### Essential Keyboard Shortcuts

**Building & Running:**
| Action | Shortcut | Use Case |
|--------|----------|----------|
| Build | `Cmd + B` | Compile without running |
| Run | `Cmd + R` | Build and launch app |
| Stop | `Cmd + .` | Stop running app |
| Test | `Cmd + U` | Run all tests |
| Profile | `Cmd + I` | Launch Instruments |

**Navigation:**
| Action | Shortcut | Use Case |
|--------|----------|----------|
| Quick Open | `Cmd + Shift + O` | Jump to any file/symbol |
| Jump to Definition | `Cmd + Click` | Go to definition |
| Jump Back | `Cmd + Ctrl + ←` | Return to previous location |
| Jump Forward | `Cmd + Ctrl + →` | Go forward in history |
| Show Related Items | `Ctrl + 1` | See callers, callees, etc. |
| Open Quickly | `Cmd + Shift + O` | Type to find files/symbols |

**Editing:**
| Action | Shortcut | Use Case |
|--------|----------|----------|
| Comment/Uncomment | `Cmd + /` | Toggle comments |
| Indent | `Cmd + ]` | Increase indentation |
| Outdent | `Cmd + [` | Decrease indentation |
| Re-Indent | `Ctrl + I` | Auto-format selection |
| Show Completions | `Esc` | Trigger autocomplete |
| Fix All Issues | `Cmd + Ctrl + F` | Apply all Fix-Its |

**Debugging:**
| Action | Shortcut | Use Case |
|--------|----------|----------|
| Toggle Breakpoint | `Cmd + \` | Add/remove breakpoint |
| Step Over | `F6` | Execute current line |
| Step Into | `F7` | Enter function |
| Step Out | `F8` | Exit current function |
| Continue | `Ctrl + Cmd + Y` | Resume execution |
| View Debug Area | `Cmd + Shift + Y` | Show console |

**Interface:**
| Action | Shortcut | Use Case |
|--------|----------|----------|
| Show/Hide Navigator | `Cmd + 0` | Toggle left sidebar |
| Show/Hide Inspector | `Cmd + Option + 0` | Toggle right sidebar |
| Show/Hide Debug Area | `Cmd + Shift + Y` | Toggle bottom console |
| Project Navigator | `Cmd + 1` | File browser |
| Find Navigator | `Cmd + 3` | Search results |
| Issue Navigator | `Cmd + 4` | Build errors/warnings |
| Test Navigator | `Cmd + 5` | Test explorer |

#### Pro Tips

**1. Quick Open is Your Best Friend**
```
Cmd + Shift + O, then type:
- "GeminiServ" → jumps to GeminiService.swift
- "upload" → shows all methods named upload
- "ChatVM" → finds ChatViewModel
```

**2. Multiple Cursors**
```
1. Hold Option + Shift
2. Drag mouse vertically
3. Type to edit multiple lines simultaneously
```

**3. Refactoring**
```
1. Right-click on symbol
2. Select "Refactor" > "Rename"
3. Type new name
4. Press Enter (updates everywhere)
```

**4. Code Snippets**
```
Type abbreviation + Tab:
- "mark" → // MARK: -
- "print" → print(<#message#>)
- "guard" → guard <#condition#> else { <#code#> }
```

**5. Split Editors**
```
Option + Click on file → opens in split view
Cmd + Shift + O, then Option + Enter → open in split
```

### 2.3 Simulator vs Device Testing

#### When to Use Simulator

**Advantages:**
- Fast iteration
- No need for physical device
- Easy to test different screen sizes
- Can simulate different iOS versions

**Use simulator for:**
- UI layout testing
- Basic functionality testing
- Quick iterations during development
- Testing on different device sizes

**Simulator Shortcuts:**
```
Cmd + K         → Toggle keyboard
Cmd + 1/2/3     → Scale to 100%/75%/50%
Cmd + →         → Rotate right
Cmd + ←         → Rotate left
Cmd + Shift + H → Home button
```

**Selecting Simulators:**
```
1. Click on device selector (next to Run button)
2. Choose from:
   - iPhone 15 Pro (iOS 17.0) → Primary test device
   - iPhone SE (3rd gen) → Small screen testing
   - iPad Pro (12.9-inch) → Tablet testing
```

#### When to Use Physical Device

**Advantages:**
- Real camera and sensors
- Actual performance
- True memory constraints
- Real-world testing

**Must use device for:**
- Camera/video recording (simulator can't access camera)
- Performance testing (real CPU/GPU)
- Memory profiling (real constraints)
- ARKit features
- Biometric authentication
- Push notifications (production)

**Setting Up Device Testing:**
```
1. Connect iPhone/iPad via USB
2. Unlock device and trust computer
3. Select device in Xcode device selector
4. Press Cmd + R
5. First time: Device will ask to trust developer
```

**TennisCoach Specific:**
- **Camera recording**: MUST test on device
- **Video compression**: Test on device (performance)
- **Gemini API calls**: Can test on simulator
- **SwiftData**: Can test on simulator

#### Device Testing Best Practices

**Before Device Testing:**
```bash
# 1. Clean build for device
Cmd + Shift + K
Cmd + B

# 2. Check device is selected (not simulator)
# 3. Ensure device is unlocked
# 4. Check for sufficient storage
```

**Testing Checklist:**
- [ ] App launches without crash
- [ ] Camera permission prompt appears
- [ ] Video records smoothly
- [ ] Video saves to device
- [ ] Gemini analysis completes
- [ ] App doesn't overheat device
- [ ] Battery usage is reasonable

### 2.4 Version Control Best Practices

#### Branch Strategy

```bash
# Main branch (stable, production-ready)
main

# Development branch (integration)
develop

# Feature branches (short-lived)
feature/video-deletion
feature/chat-improvements

# Bug fix branches
fix/camera-crash-ios17
fix/upload-retry-logic

# Release branches
release/1.0.0
```

**Workflow:**
```bash
# 1. Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature

# 2. Make changes and commit
git add .
git commit -m "feat: implement my new feature"

# 3. Push to remote
git push origin feature/my-new-feature

# 4. Create pull request on GitHub/GitLab
# 5. After review, merge to develop
# 6. Delete feature branch
git branch -d feature/my-new-feature
```

#### What to Commit

**Always Commit:**
- Source code (.swift files)
- Project file (.xcodeproj)
- README.md, DESIGN.md
- Test files
- Assets (images, icons)
- PrivacyInfo.xcprivacy
- Configuration files

**Never Commit:**
- Build artifacts (DerivedData/)
- User-specific settings (.xcuserdata/)
- API keys or secrets
- Large binary files (test videos)
- Temporary files

**Create `.gitignore`:**
```bash
# Xcode
build/
DerivedData/
*.xcuserdata
*.xcworkspace/xcuserdata/

# Swift Package Manager
.swiftpm/
Packages/
.build/

# CocoaPods (if used)
Pods/

# API Keys
*.env
secrets.plist

# macOS
.DS_Store

# Test videos
*.mp4
*.mov
TestVideos/
```

#### Commit Message Guidelines

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Example:**
```
feat(recording): Add 60fps video capture support

Implements high frame rate capture using AVCaptureSession.
Adds user setting to toggle between 30fps and 60fps.
Includes compression optimization for 60fps files.

Closes #123
```

**Types:**
- feat: New feature
- fix: Bug fix
- refactor: Code change without feature/fix
- test: Adding tests
- docs: Documentation only
- style: Code formatting
- perf: Performance improvement
- chore: Build/tooling changes

---

## 3. Code Quality Standards

### 3.1 Swift Style Guide Essentials

TennisCoach follows [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and [Ray Wenderlich Swift Style Guide](https://github.com/raywenderlich/swift-style-guide).

#### Naming Conventions

**1. Use Clear, Descriptive Names**

```swift
// ❌ Bad
func proc(v: Video) { }
let d = Date()
var x = 10

// ✅ Good
func processVideo(_ video: Video) { }
let currentDate = Date()
var recordingDuration = 10
```

**2. Types: PascalCase**

```swift
// Classes, Structs, Enums, Protocols
class VideoRecorder { }
struct VideoMetadata { }
enum RecordingState { }
protocol GeminiServicing { }
```

**3. Variables and Functions: camelCase**

```swift
// Variables, constants, functions
var isRecording = false
let maxDuration: TimeInterval = 300
func startRecording() { }
```

**4. Constants: camelCase (not SCREAMING_CASE)**

```swift
// ❌ Bad
let MAX_DURATION = 300
let API_KEY = "..."

// ✅ Good
let maxDuration = 300
let apiKey = "..."
```

**5. Enums: lowercase first word**

```swift
enum RecordingState {
    case idle
    case recording
    case processing
    case completed
}

// Usage
let state = RecordingState.recording
```

**6. Boolean Properties: is/has/should prefix**

```swift
var isRecording: Bool
var hasAPIKey: Bool
var shouldCompress: Bool
var canUpload: Bool
```

**7. Functions: Verb + Object**

```swift
// ❌ Bad
func video() { }
func data() { }

// ✅ Good
func recordVideo() { }
func fetchData() { }
func uploadVideo() { }
func analyzeVideo() { }
```

#### Code Organization

**1. MARK Comments**

Use MARK to organize code sections:

```swift
class GeminiService {

    // MARK: - Properties

    private let apiKey: String
    private let session: URLSession

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    // MARK: - Public Methods

    func uploadVideo(_ url: URL) async throws -> String {
        // ...
    }

    // MARK: - Private Methods

    private func buildRequest() -> URLRequest {
        // ...
    }

    // MARK: - Helper Methods

    private func handleError(_ error: Error) {
        // ...
    }
}
```

**2. File Structure Order**

```swift
// 1. Imports
import SwiftUI
import AVFoundation

// 2. Protocol definitions
protocol VideoRecording { }

// 3. Main type
class VideoRecorder: VideoRecording {

    // 3.1. Type aliases
    typealias CompletionHandler = (Result<URL, Error>) -> Void

    // 3.2. Properties (static, then instance)
    static let shared = VideoRecorder()
    private let captureSession = AVCaptureSession()

    // 3.3. Initialization
    init() { }

    // 3.4. Public methods
    func startRecording() { }

    // 3.5. Private methods
    private func configureSession() { }
}

// 4. Extensions
extension VideoRecorder {
    // Conformance to protocols
}
```

**3. Access Control**

Use the most restrictive access level possible:

```swift
// ❌ Bad (everything public by default)
class VideoRecorder {
    var captureSession: AVCaptureSession // Internal by default
    var output: AVCaptureMovieFileOutput

    func configureSession() { }
}

// ✅ Good (explicit access control)
class VideoRecorder {
    private let captureSession: AVCaptureSession
    private let output: AVCaptureMovieFileOutput

    // Only public API
    public func startRecording() { }
    public func stopRecording() { }

    // Implementation details private
    private func configureSession() { }
}
```

**Access Levels:**
- `private`: Only within current declaration
- `fileprivate`: Only within current file
- `internal`: Default, within module
- `public`: Accessible outside module
- `open`: Subclassable outside module

#### Formatting

**1. Indentation: 4 spaces (not tabs)**

Xcode default is correct. Never mix tabs and spaces.

**2. Line Length: 120 characters max**

```swift
// ❌ Too long
func analyzeVideoWithGeminiAPIAndReturnStreamingResponseForUserInteraction(videoURL: URL, prompt: String) async throws -> AsyncThrowingStream<String, Error>

// ✅ Break into multiple lines
func analyzeVideo(
    videoURL: URL,
    prompt: String
) async throws -> AsyncThrowingStream<String, Error>
```

**3. Spacing**

```swift
// ✅ Good spacing
if isRecording {
    stopRecording()
}

let result = try await uploadVideo(url)

// No extra spaces around operators
let sum = a + b

// Space after commas
func process(a: Int, b: Int, c: Int)
```

**4. Braces: Same Line**

```swift
// ✅ Opening brace on same line
func startRecording() {
    captureSession.startRunning()
}

if isRecording {
    print("Recording")
} else {
    print("Not recording")
}
```

**5. Empty Lines**

```swift
// One empty line between methods
func method1() {
    // ...
}
                          // ← One empty line
func method2() {
    // ...
}

// Two empty lines between sections
// MARK: - Properties

private let session: URLSession
                          // ← Two empty lines

// MARK: - Methods

func upload() { }
```

#### SwiftUI Specific

**1. View Composition**

```swift
// ❌ Bad (too much in one view)
struct ContentView: View {
    var body: some View {
        VStack {
            // 100+ lines of UI code
        }
    }
}

// ✅ Good (extracted subviews)
struct ContentView: View {
    var body: some View {
        VStack {
            HeaderView()
            VideoListView()
            FooterView()
        }
    }
}
```

**2. State Management**

```swift
// ✅ Proper state declarations
struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @State private var isShowingAlert = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // ...
    }
}
```

**3. View Modifiers Order**

Consistent order improves readability:

```swift
Text("Hello")
    .font(.headline)           // 1. Text styling
    .foregroundColor(.blue)
    .padding()                 // 2. Layout
    .background(Color.gray)    // 3. Background
    .cornerRadius(10)          // 4. Shape
    .shadow(radius: 5)         // 5. Effects
    .onTapGesture { }          // 6. Gestures
```

### 3.2 SwiftLint Setup (Optional but Recommended)

SwiftLint automatically enforces style rules.

#### Installation

**Method 1: Homebrew (Recommended)**

```bash
brew install swiftlint
```

**Method 2: CocoaPods**

Add to `Podfile`:
```ruby
pod 'SwiftLint'
```

#### Xcode Integration

1. Select **TennisCoach** target
2. Go to **Build Phases**
3. Click `+` → **New Run Script Phase**
4. Name it "SwiftLint"
5. Add script:

```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

6. Drag "SwiftLint" phase above "Compile Sources"

#### Configuration

Create `.swiftlint.yml` in project root:

```yaml
# TennisCoach SwiftLint Configuration

disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - empty_count
  - empty_string
  - explicit_init

excluded:
  - Pods
  - DerivedData
  - .build

line_length:
  warning: 120
  error: 150

file_length:
  warning: 500
  error: 1000

type_body_length:
  warning: 300
  error: 500

function_body_length:
  warning: 40
  error: 60

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 40
    error: 50
  excluded:
    - id
    - i
    - j
    - x
    - y
```

#### Running SwiftLint

**Automatic**: Runs on every build
**Manual**:

```bash
cd /Users/yoyo/src/TennisCoach
swiftlint lint
swiftlint lint --fix  # Auto-fix issues
```

### 3.3 Documentation Requirements

**1. Document Public APIs**

```swift
/// Records video from the device camera.
///
/// Configures AVCaptureSession with optimal settings for tennis video
/// analysis, including 60fps capture and proper exposure settings.
///
/// - Parameters:
///   - duration: Maximum recording duration in seconds
///   - completion: Called when recording stops with the video URL or error
/// - Throws: `RecordingError` if camera is unavailable or permission denied
/// - Returns: URL of the recorded video file
func recordVideo(
    duration: TimeInterval,
    completion: @escaping (Result<URL, Error>) -> Void
) throws -> URL {
    // Implementation
}
```

**2. Use Proper Documentation Comments**

```swift
// ❌ Bad (regular comment)
// This uploads a video
func uploadVideo() { }

// ✅ Good (documentation comment)
/// Uploads video to Gemini File API.
func uploadVideo() { }

// ✅ Also good (multi-line)
/**
 Uploads video to Gemini File API.

 Uses resumable upload protocol for large files.
 Retries automatically on network failure.
 */
func uploadVideo() { }
```

**3. Document Complex Logic**

```swift
func processVideo(_ video: Video) {
    // Extract frames at 2fps for thumbnail generation
    let frameInterval = CMTime(seconds: 0.5, preferredTimescale: 600)

    // Use medium quality to balance file size and analysis accuracy
    let compressionQuality = AVAssetExportPresetMediumQuality

    // ...
}
```

**4. TODO Comments**

```swift
// TODO: Add error recovery for network timeout
// FIXME: Memory leak in video compression
// MARK: - Temporary workaround, remove when iOS 17.1 fixes bug
```

**Pro Tip**: Use Xcode's structured TODO:
```
Product > Build Settings > Search "TODO"
Enable "Show warnings for TODO/FIXME"
```

### 3.4 Error Handling

**1. Use Proper Error Types**

```swift
// ✅ Good: Custom error enum
enum VideoRecorderError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case insufficientStorage
    case recordingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission was denied"
        case .insufficientStorage:
            return "Not enough storage space to record video"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        }
    }
}
```

**2. Use Result Type for Async Callbacks**

```swift
// ❌ Bad
func uploadVideo(completion: (String?, Error?) -> Void)

// ✅ Good
func uploadVideo(completion: (Result<String, Error>) -> Void)

// ✅ Better (modern async/await)
func uploadVideo() async throws -> String
```

**3. Handle Errors Properly**

```swift
// ❌ Bad (swallowing errors)
do {
    try uploadVideo()
} catch {
    print("Error")
}

// ✅ Good (proper error handling)
do {
    let fileUri = try await uploadVideo()
    self.videoUri = fileUri
} catch let error as GeminiServiceError {
    // Handle specific error
    self.errorMessage = error.errorDescription
    AppLogger.error("Upload failed", error: error)
} catch {
    // Handle unexpected error
    self.errorMessage = "An unexpected error occurred"
    AppLogger.error("Unexpected upload error", error: error)
}
```

**4. Use guard for Early Returns**

```swift
// ❌ Bad (nested ifs)
func startRecording() {
    if hasPermission {
        if hasSufficientStorage {
            if !isRecording {
                // Start recording
            }
        }
    }
}

// ✅ Good (guard statements)
func startRecording() {
    guard hasPermission else {
        handleError(.permissionDenied)
        return
    }

    guard hasSufficientStorage else {
        handleError(.insufficientStorage)
        return
    }

    guard !isRecording else {
        return // Already recording
    }

    // Start recording
}
```

### 3.5 Performance Best Practices

**1. Lazy Loading**

```swift
// ✅ Lazy initialization
class VideoListViewModel {
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
```

**2. Avoid Expensive Operations in Views**

```swift
// ❌ Bad (expensive calculation in body)
struct VideoListView: View {
    var body: some View {
        List {
            ForEach(videos) { video in
                // Don't do this - recalculates on every render
                let thumbnail = generateThumbnail(for: video)
                Image(uiImage: thumbnail)
            }
        }
    }
}

// ✅ Good (pre-calculated in ViewModel)
struct VideoListView: View {
    @StateObject var viewModel = VideoListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.videosWithThumbnails) { item in
                Image(uiImage: item.thumbnail)
            }
        }
    }
}
```

**3. Use @MainActor for UI Updates**

```swift
// ✅ Mark UI-updating code with @MainActor
class RecordViewModel: ObservableObject {
    @Published var isRecording = false

    @MainActor
    func updateRecordingState(_ isRecording: Bool) {
        self.isRecording = isRecording
    }
}
```

**4. Profile Before Optimizing**

Don't optimize prematurely. Use Instruments:
```
Cmd + I → Choose instrument → Time Profiler
```

---

## 4. Build & Compile Best Practices

### 4.1 Understanding Build Configurations

Xcode has two default build configurations:

#### Debug Configuration

**Purpose**: Development and testing
**Characteristics:**
- No optimization (-Onone)
- Debug symbols included
- Faster compile times
- Larger binary size
- Assertions enabled

**When to use:**
- Daily development
- Simulator testing
- Device debugging

**Performance:**
- Build time: ~15-30 seconds (incremental)
- App performance: Slower (no optimizations)

#### Release Configuration

**Purpose**: Production deployment
**Characteristics:**
- Full optimization (-O)
- Debug symbols optional
- Slower compile times
- Smaller binary size
- Assertions disabled

**When to use:**
- App Store submission
- TestFlight distribution
- Performance testing

**Performance:**
- Build time: ~1-3 minutes (full)
- App performance: Fast (fully optimized)

#### Switching Configurations

```
1. Product > Scheme > Edit Scheme
2. Select "Run" in sidebar
3. Change "Build Configuration" dropdown
4. Choose Debug or Release
```

**For TennisCoach:**
- Use **Debug** during development
- Use **Release** for performance testing video compression
- Use **Release** for TestFlight builds

### 4.2 Common Build Errors and Fixes

#### Error 1: "No such module 'SwiftData'"

**Cause**: Target iOS version too low or wrong SDK

**Fix:**
```
1. Select TennisCoach project
2. Select TennisCoach target
3. General tab > Deployment Info
4. Set "Minimum Deployments" to iOS 17.0+
```

#### Error 2: "Command SwiftCompile failed"

**Symptoms**: Random Swift compiler crashes

**Fix:**
```bash
# 1. Clean build folder
Cmd + Shift + K

# 2. Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# 3. Restart Xcode

# 4. Rebuild
Cmd + B
```

#### Error 3: "Undefined symbol" or "Linker command failed"

**Cause**: Missing file or framework

**Fix:**
```
1. Check Issue Navigator (Cmd + 4)
2. Find missing symbol name
3. Either:
   a. Add missing .swift file to target
   b. Import missing framework
   c. Remove reference to deleted file
```

**Example:**
```
Undefined symbol: _$s11TennisCoach13VideoRecorderC...

Fix: VideoRecorder.swift is not included in target
1. Select VideoRecorder.swift
2. Show File Inspector (Cmd + Option + 1)
3. Check "TennisCoach" under Target Membership
```

#### Error 4: "Type 'X' does not conform to protocol 'Y'"

**Cause**: Missing protocol implementation

**Fix:**
```swift
// Error: Type 'VideoRecorder' does not conform to protocol 'VideoRecording'

// Check protocol requirements
protocol VideoRecording {
    func startRecording() throws
    func stopRecording() async throws -> URL
}

// Ensure all methods are implemented
class VideoRecorder: VideoRecording {
    func startRecording() throws {
        // Implementation
    }

    func stopRecording() async throws -> URL {
        // Implementation
    }
}
```

#### Error 5: "Cannot find 'X' in scope"

**Cause**: Missing import or typo

**Fix:**
```swift
// Error: Cannot find 'AVCaptureSession' in scope

// Add missing import
import AVFoundation

// Now AVCaptureSession is available
let session = AVCaptureSession()
```

#### Error 6: "Value of type 'X' has no member 'Y'"

**Cause**: Wrong type or API not available in iOS version

**Fix:**
```swift
// Error: Value of type 'Video' has no member 'thumbnailImage'

// Check model definition
@Model
class Video {
    var thumbnailData: Data?  // ← It's thumbnailData, not thumbnailImage
}

// Correct usage
if let data = video.thumbnailData {
    let image = UIImage(data: data)
}
```

### 4.3 Reading Build Logs

When build fails, Xcode shows errors in the Issue Navigator.

#### Accessing Detailed Logs

```
1. Build fails
2. Click on error in Issue Navigator (Cmd + 4)
3. Click "Show Full Log" button (on right side)
4. Or: View > Navigators > Show Report Navigator (Cmd + 9)
```

#### Understanding Error Format

```
/Users/yoyo/src/TennisCoach/TennisCoach/Services/GeminiService.swift:45:17: error: cannot find 'URLSession' in scope
        let session = URLSession.shared
                      ^~~~~~~~~~
```

**Breaking down the error:**
- `/Users/yoyo/src/.../GeminiService.swift` - File with error
- `:45:17` - Line 45, column 17
- `error:` - Severity (error, warning, note)
- `cannot find 'URLSession' in scope` - Error message
- `^~~~~~~~~~` - Points to exact location

**Fix this error:**
```swift
// Add missing import at top of file
import Foundation
```

#### Warning vs Error

**Error**: Must fix before app can build
**Warning**: Should fix but app can still build

```swift
// Warning: Immutable value 'duration' was never used
let duration = video.duration

// Fix: Either use it or remove it
print("Duration: \(duration)")
// Or
// Remove unused variable
```

**Configure warning behavior:**
```
Build Settings > "Treat Warnings as Errors" > Yes (recommended for production)
```

### 4.4 Compilation Modes

#### Incremental Compilation (Default)

**How it works:**
- Only recompiles changed files
- Fast for daily development
- Sometimes causes stale errors

**When to use:**
- Regular development
- Making small changes

#### Whole Module Compilation

**How it works:**
- Compiles entire module at once
- Slower but more optimization
- Better for Release builds

**Configure:**
```
Build Settings > "Compilation Mode"
- Debug: Incremental
- Release: Whole Module
```

### 4.5 Build Time Optimization

**Slow builds?** Try these:

#### 1. Check Build Time

```
1. Xcode > Settings > General
2. Enable "Show build time in toolbar"
3. Now you see build time: "Build Succeeded (28.3s)"
```

#### 2. Find Slow Files

Add to `Other Swift Flags` in Build Settings:
```
-Xfrontend -warn-long-function-bodies=100
-Xfrontend -warn-long-expression-type-checking=100
```

Xcode will warn about functions that take >100ms to compile.

#### 3. Use Precompiled Headers (for large projects)

```
Build Settings > "Precompile Prefix Header" > Yes
```

#### 4. Parallelize Builds

```
Xcode > Settings > Locations > Derived Data > Advanced
Enable "Build System" > Legacy Build System (only if issues)
```

**For TennisCoach:**
Current build time should be: ~20-40 seconds (incremental), ~2-3 minutes (clean)

If slower:
- Check for complex SwiftUI views
- Profile with `-warn-long-function-bodies`
- Break up large files

### 4.6 Simulator vs Device Builds

#### Simulator Build

**Target Architecture**: x86_64 or arm64 (M1/M2 Macs)
**Build time**: Faster (native architecture)
**Use for**: Quick testing, UI iteration

#### Device Build

**Target Architecture**: arm64 (iPhone/iPad)
**Build time**: Slower (cross-compilation)
**Use for**: Camera testing, performance testing

**Switching:**
```
Device selector (next to Run button) > Choose:
- Any iOS Simulator → Builds for simulator
- Your iPhone/iPad → Builds for device
```

---

## 5. Unit Testing Standards

### 5.1 Test Naming Conventions

Use descriptive, readable test names that explain what is being tested.

#### Format

```swift
func test_<methodUnderTest>_<scenario>_<expectedBehavior>()
```

#### Examples

```swift
// ✅ Good test names
func test_uploadVideo_withValidURL_returnsFileURI()
func test_uploadVideo_withInvalidURL_throwsError()
func test_startRecording_whenAlreadyRecording_throwsError()
func test_videoModel_whenDeleted_cascadesConversations()

// ❌ Bad test names
func testUpload()
func test1()
func testRecording()
func testItWorks()
```

#### Alternative Format (Given-When-Then)

```swift
func test_givenValidVideo_whenUploading_thenReturnsURI()
func test_givenNoAPIKey_whenAnalyzing_thenThrowsError()
```

### 5.2 What to Test vs What Not to Test

#### DO Test (High Value)

**Business Logic:**
```swift
// ✅ Test: Video model relationships
func test_video_whenDeleted_deletesConversations() {
    let video = Video(...)
    let conversation = Conversation(video: video)
    modelContext.delete(video)

    // Verify cascade deletion
    XCTAssertTrue(conversation.isDeleted)
}
```

**Data Transformations:**
```swift
// ✅ Test: Data parsing
func test_geminiResponse_parsesCorrectly() {
    let json = """
    {"candidates": [{"content": {"parts": [{"text": "Analysis"}]}}]}
    """
    let response = try GeminiResponse(json: json)
    XCTAssertEqual(response.text, "Analysis")
}
```

**Edge Cases:**
```swift
// ✅ Test: Empty input handling
func test_analyzeVideo_withEmptyPrompt_usesDefaultPrompt() {
    let result = try await service.analyze(prompt: "")
    XCTAssertFalse(result.isEmpty)
}
```

**Error Handling:**
```swift
// ✅ Test: Network errors
func test_uploadVideo_whenNetworkFails_throwsError() {
    await XCTAssertThrowsError(
        try await service.uploadVideo(url: mockURL)
    )
}
```

**ViewModels:**
```swift
// ✅ Test: State changes
func test_startRecording_updatesState() {
    viewModel.startRecording()
    XCTAssertTrue(viewModel.isRecording)
}
```

#### DON'T Test (Low Value)

**Framework/Library Code:**
```swift
// ❌ Don't test: SwiftData persistence (Apple's responsibility)
func test_modelContext_savesData() {
    modelContext.insert(video)
    try modelContext.save() // Don't test Apple's code
}
```

**UI Layout:**
```swift
// ❌ Don't test: SwiftUI rendering
func test_buttonIsBlue() {
    let button = Button("Test") { }
    // Don't test SwiftUI layout engine
}
```

**Simple Getters/Setters:**
```swift
// ❌ Don't test: Trivial properties
func test_video_setsDuration() {
    video.duration = 60.0
    XCTAssertEqual(video.duration, 60.0) // Pointless
}
```

**Private Implementation Details:**
```swift
// ❌ Don't test: Private methods (test public API instead)
func test_privateHelperMethod() {
    // If it's private, test it through public methods
}
```

### 5.3 Test Coverage Expectations

#### Coverage Goals

| Code Type | Target Coverage | Priority |
|-----------|----------------|----------|
| Models | 80-90% | High |
| ViewModels | 70-80% | High |
| Services | 80-90% | High |
| Views | 30-50% | Low |
| Utilities | 90%+ | High |

#### For TennisCoach Specifically

**High Priority (Must Test):**
- `GeminiService` - API integration critical
- `VideoRecorder` - Core functionality
- `Video`, `Conversation`, `Message` models - Data integrity
- `ChatViewModel` - Complex state management

**Medium Priority (Should Test):**
- `VideoCompressor` - Performance critical
- `RetryPolicy` - Reliability critical
- `SecureKeyManager` - Security critical

**Low Priority (Optional):**
- Views - Mostly UI, covered by manual testing
- Constants - Simple values
- Extensions - Trivial helpers

#### Viewing Code Coverage

1. Enable code coverage:
```
Product > Scheme > Edit Scheme > Test
Check "Gather coverage data"
```

2. Run tests: `Cmd + U`

3. View coverage:
```
Show Report Navigator (Cmd + 9)
Select latest test run
Click "Coverage" tab
```

4. See coverage per file:
- Green: Good coverage
- Yellow: Partial coverage
- Red: No coverage

**Aim for:**
- Overall project: 60-70%
- Critical services: 80%+

### 5.4 Test Structure (Arrange-Act-Assert)

Use AAA pattern for clear, maintainable tests:

```swift
func test_analyzeVideo_withValidURL_returnsAnalysis() {
    // Arrange (Given) - Set up test data
    let mockService = MockGeminiService()
    let videoURL = URL(string: "file:///test.mp4")!
    let expectedAnalysis = "Good forehand technique"
    mockService.mockAnalysis = expectedAnalysis

    // Act (When) - Execute the method under test
    let result = try await mockService.analyzeVideo(url: videoURL)

    // Assert (Then) - Verify the result
    XCTAssertEqual(result, expectedAnalysis)
    XCTAssertTrue(mockService.analyzeWasCalled)
}
```

#### More Examples

**Testing State Changes:**
```swift
func test_startRecording_whenIdle_transitionsToRecording() async {
    // Arrange
    let viewModel = RecordViewModel()
    XCTAssertEqual(viewModel.state, .idle)

    // Act
    await viewModel.startRecording()

    // Assert
    XCTAssertEqual(viewModel.state, .recording)
}
```

**Testing Error Handling:**
```swift
func test_uploadVideo_whenAPIKeyMissing_throwsError() async {
    // Arrange
    let service = GeminiService(apiKey: "")
    let videoURL = URL(fileURLWithPath: "/test.mp4")

    // Act & Assert
    await XCTAssertThrowsError(
        try await service.uploadVideo(url: videoURL)
    ) { error in
        // Verify correct error type
        XCTAssertTrue(error is GeminiServiceError)
    }
}
```

**Testing Async Code:**
```swift
func test_analyzeVideo_streamsResponse() async throws {
    // Arrange
    let service = MockGeminiService()
    let expectedChunks = ["Good", " forehand", " technique"]
    service.mockStreamChunks = expectedChunks

    // Act
    var receivedChunks: [String] = []
    for try await chunk in service.analyzeVideo(url: mockURL) {
        receivedChunks.append(chunk)
    }

    // Assert
    XCTAssertEqual(receivedChunks, expectedChunks)
}
```

### 5.5 Mocking and Test Doubles

Use protocols to enable mocking:

#### Creating Mockable Services

```swift
// 1. Define protocol
protocol GeminiServicing {
    func uploadVideo(url: URL) async throws -> String
    func analyzeVideo(fileUri: String) async throws -> AsyncThrowingStream<String, Error>
}

// 2. Real implementation
class GeminiService: GeminiServicing {
    func uploadVideo(url: URL) async throws -> String {
        // Real API call
    }
}

// 3. Mock for testing
class MockGeminiService: GeminiServicing {
    var uploadWasCalled = false
    var mockFileUri = "mock-uri"
    var shouldThrowError = false

    func uploadVideo(url: URL) async throws -> String {
        uploadWasCalled = true

        if shouldThrowError {
            throw GeminiServiceError.uploadFailed
        }

        return mockFileUri
    }

    func analyzeVideo(fileUri: String) async throws -> AsyncThrowingStream<String, Error> {
        // Return mock stream
    }
}
```

#### Using Mocks in Tests

```swift
func test_chatViewModel_uploadsVideoBeforeAnalysis() async throws {
    // Arrange
    let mockService = MockGeminiService()
    let viewModel = ChatViewModel(geminiService: mockService)

    // Act
    await viewModel.analyzeVideo(url: mockURL)

    // Assert
    XCTAssertTrue(mockService.uploadWasCalled)
}
```

### 5.6 Running Tests

#### Run All Tests

```bash
# Xcode
Cmd + U

# Command line
cd /Users/yoyo/src/TennisCoach
xcodebuild test -scheme TennisCoach -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### Run Specific Test File

```
1. Open test file (e.g., GeminiServiceTests.swift)
2. Click diamond icon next to class name
3. Or: Right-click on file > Run "GeminiServiceTests"
```

#### Run Single Test Method

```
1. Click diamond icon next to test method
2. Or: Place cursor in method > Ctrl + Option + Cmd + U
```

#### Command Line Testing

```bash
# Run all tests
xcodebuild test \
  -scheme TennisCoach \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath TestResults

# Run specific test
xcodebuild test \
  -scheme TennisCoach \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:TennisCoachTests/GeminiServiceTests/test_uploadVideo_withValidURL_returnsFileURI

# Parallel testing (faster)
xcodebuild test \
  -scheme TennisCoach \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -parallel-testing-enabled YES
```

### 5.7 Test Organization

#### File Structure

```
TennisCoachTests/
├── ModelTests/
│   ├── VideoTests.swift
│   ├── ConversationTests.swift
│   └── MessageTests.swift
├── ServiceTests/
│   ├── GeminiServiceTests.swift
│   ├── VideoRecorderTests.swift
│   └── VideoCompressorTests.swift
├── ViewModelTests/
│   ├── ChatViewModelTests.swift
│   ├── RecordViewModelTests.swift
│   └── VideoListViewModelTests.swift
├── UtilityTests/
│   ├── RetryPolicyTests.swift
│   └── SecureKeyManagerTests.swift
└── Mocks/
    ├── MockGeminiService.swift
    └── MockVideoRecorder.swift
```

#### Test File Template

```swift
import XCTest
@testable import TennisCoach

final class GeminiServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: GeminiService! // System Under Test
    var mockSession: URLSession!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Set up before each test
        sut = GeminiService(apiKey: "test-key")
    }

    override func tearDown() {
        // Clean up after each test
        sut = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_init_setsAPIKey() {
        XCTAssertEqual(sut.apiKey, "test-key")
    }

    // More tests...
}
```

### 5.8 Continuous Integration (CI) Basics

For team projects, automate testing:

#### GitHub Actions Example

Create `.github/workflows/ios-tests.yml`:

```yaml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app

    - name: Build and Test
      run: |
        xcodebuild test \
          -scheme TennisCoach \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
          -enableCodeCoverage YES

    - name: Upload Coverage
      uses: codecov/codecov-action@v3
```

#### Benefits
- Tests run automatically on every commit
- Catches issues before merging
- Enforces code quality standards

---

## 6. Code Review Checklist

### 6.1 Pre-Commit Checklist

Before committing code, verify:

#### Functionality
- [ ] Code compiles without errors
- [ ] Code compiles without warnings
- [ ] All tests pass (`Cmd + U`)
- [ ] App runs on simulator
- [ ] App runs on device (if hardware-dependent)
- [ ] Feature works as expected

#### Code Quality
- [ ] Follows Swift style guide
- [ ] No commented-out code
- [ ] No debug print statements
- [ ] No hardcoded values (use Constants)
- [ ] No TODO comments (create issues instead)
- [ ] Proper error handling
- [ ] Meaningful variable names

#### Documentation
- [ ] Public APIs documented
- [ ] Complex logic explained
- [ ] README updated (if needed)
- [ ] DESIGN.md updated (if architecture changed)

#### Testing
- [ ] New code has tests
- [ ] Tests are meaningful
- [ ] Test coverage maintained/improved
- [ ] Edge cases tested

#### Security
- [ ] No API keys in code
- [ ] No sensitive data logged
- [ ] User data properly protected
- [ ] Permissions properly requested

#### Performance
- [ ] No obvious performance issues
- [ ] Large operations on background threads
- [ ] UI updates on main thread
- [ ] Memory leaks checked (Instruments)

### 6.2 Self-Review Process

Before creating a PR, review your own code:

#### Step 1: Use Xcode's Comparison Tool

```
1. Select file in Project Navigator
2. Right-click > Source Control > Show Changes
3. Review every changed line
4. Ask: "Would I approve this in a PR?"
```

#### Step 2: Check Diff

```bash
# View unstaged changes
git diff

# View staged changes
git diff --cached

# View changes in specific file
git diff TennisCoach/Services/GeminiService.swift
```

#### Step 3: Look for Red Flags

**Common issues:**
- Leftover debug code
- Commented code
- Inconsistent formatting
- Missing documentation
- Unclear variable names
- Complex nested logic
- Missing error handling

**Example:**
```swift
// ❌ Red flags in this code
func uploadVideo(url: URL) {
    print("DEBUG: Uploading \(url)") // Debug print

    // let oldMethod = uploadOld(url) // Commented code

    let x = url.absoluteString // Unclear name

    // No error handling
    try! session.upload(data, to: endpoint)
}

// ✅ Fixed version
func uploadVideo(url: URL) async throws -> String {
    let videoData = try Data(contentsOf: url)

    do {
        return try await session.upload(videoData, to: endpoint)
    } catch {
        AppLogger.error("Failed to upload video", error: error)
        throw GeminiServiceError.uploadFailed(underlying: error)
    }
}
```

### 6.3 Pull Request Guidelines

#### PR Title Format

```
<type>: <short description>

Examples:
feat: Add video deletion functionality
fix: Resolve camera crash on iOS 17
refactor: Extract compression logic to separate service
test: Add tests for retry policy
docs: Update setup instructions in README
```

#### PR Description Template

```markdown
## Summary
Brief description of what this PR does.

## Changes
- Bullet point list of changes
- Each change on its own line
- Group related changes

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] Tested on simulator
- [ ] Tested on device (if applicable)

## Screenshots (if UI changes)
Before: [screenshot]
After: [screenshot]

## Notes
Any additional context, concerns, or decisions.

## Checklist
- [ ] Code follows style guide
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No warnings
- [ ] Self-reviewed
```

#### Example PR

```markdown
## Summary
Implements video deletion feature with cascade deletion of conversations.

## Changes
- Added `deleteVideo()` method to Video model
- Added delete button to VideoListView with swipe gesture
- Updated VideoListViewModel to handle deletion
- Added tests for cascade deletion
- Updated DESIGN.md with deletion flow

## Testing
- [x] Unit tests added for Video.deleteVideo()
- [x] Tested swipe-to-delete on simulator
- [x] Verified conversations are deleted with video
- [x] Tested on iPhone 15 Pro device

## Screenshots
[Screenshot of swipe-to-delete gesture]

## Notes
Used SwiftData's cascade deletion rule. No manual cleanup needed.
```

### 6.4 Reviewing Others' Code

When reviewing a teammate's PR:

#### What to Look For

**1. Functionality**
- Does the code do what it claims?
- Are there edge cases not handled?
- Could this break existing features?

**2. Code Quality**
- Is it readable?
- Are names clear?
- Is it well-organized?
- Follows style guide?

**3. Performance**
- Any expensive operations on main thread?
- Potential memory leaks?
- Unnecessary computation?

**4. Security**
- Any security vulnerabilities?
- Data properly protected?
- API keys secure?

**5. Testing**
- Are tests thorough?
- Do they test the right things?
- Are they maintainable?

#### How to Give Feedback

**Use these labels:**

```
✅ LGTM (Looks Good To Me): Approve without changes
💬 Comment: Non-blocking suggestion
⚠️ Warning: Potential issue, not critical
🚨 Blocker: Must fix before merge
❓ Question: Need clarification
💡 Suggestion: Alternative approach
📚 Knowledge share: Educational comment
🎉 Praise: Good work!
```

**Examples:**

```
✅ LGTM - Clean implementation of retry logic!

💬 Consider extracting this into a separate method for better readability.

⚠️ This might cause a memory leak - the closure captures `self` strongly.

🚨 Blocker: This will crash if the URL is nil. Add guard statement.

❓ Why did you choose to use a Timer instead of Task.sleep() here?

💡 Suggestion: You could use SwiftUI's .task modifier instead of onAppear.

📚 FYI: SwiftData handles cascade deletion automatically with the @Relationship attribute.

🎉 Excellent error handling throughout!
```

**Be constructive:**
```
❌ Bad: "This code is terrible"
✅ Good: "Consider refactoring this method - it's doing too much.
          Suggest splitting into smaller functions for better testability."

❌ Bad: "Wrong"
✅ Good: "This approach could cause a race condition.
          Consider using an actor to synchronize access."
```

### 6.5 Common Code Smells in iOS

Watch for these anti-patterns:

#### 1. Massive View Controllers (SwiftUI: Massive Views)

```swift
// ❌ Bad: 500 lines in one view
struct ChatView: View {
    var body: some View {
        VStack {
            // 500 lines of UI code
        }
    }
}

// ✅ Good: Extract subviews
struct ChatView: View {
    var body: some View {
        VStack {
            ChatHeaderView()
            MessageListView()
            ChatInputView()
        }
    }
}
```

#### 2. God Objects

```swift
// ❌ Bad: One service does everything
class AppService {
    func recordVideo() { }
    func uploadVideo() { }
    func analyzeVideo() { }
    func saveToDatabase() { }
    func sendNotification() { }
    func compress() { }
}

// ✅ Good: Separate responsibilities
class VideoRecorder { }
class GeminiService { }
class DatabaseManager { }
class NotificationService { }
class VideoCompressor { }
```

#### 3. Force Unwrapping

```swift
// ❌ Bad: Force unwrapping
let image = UIImage(data: video.thumbnailData!)! // Crashes if nil

// ✅ Good: Safe unwrapping
guard let data = video.thumbnailData,
      let image = UIImage(data: data) else {
    return
}
```

#### 4. Retain Cycles

```swift
// ❌ Bad: Strong reference cycle
service.fetchData { data in
    self.data = data // Captures self strongly
}

// ✅ Good: Weak self
service.fetchData { [weak self] data in
    self?.data = data
}
```

#### 5. Magic Numbers

```swift
// ❌ Bad: Magic numbers
if duration > 300 {
    showError()
}

// ✅ Good: Named constants
if duration > Constants.Video.maxDuration {
    showError()
}
```

---

## 7. Debugging Tips

### 7.1 Using Breakpoints Effectively

Breakpoints are your most powerful debugging tool.

#### Basic Breakpoint

**Add breakpoint:**
```
1. Click on line number in gutter (left side of editor)
2. Or: Place cursor on line, press Cmd + \
3. Blue indicator appears
```

**Remove breakpoint:**
```
1. Click on blue indicator
2. Or: Cmd + \ to toggle
```

**Disable temporarily:**
```
1. Right-click on breakpoint
2. Select "Disable Breakpoint"
3. Indicator turns gray
```

#### Conditional Breakpoints

Only stops when condition is true:

```
1. Right-click on breakpoint
2. Select "Edit Breakpoint"
3. Add condition: video.duration > 60
4. Now only breaks if condition is true
```

**Use cases:**
```swift
// Only break when specific video is processed
video.id == UUID(uuidString: "...")

// Only break on error
error != nil

// Only break after 10 iterations
index > 10
```

#### Action Breakpoints

Run actions without stopping:

```
1. Right-click on breakpoint
2. Edit Breakpoint
3. Add Action > Debugger Command
4. Enter: po video
5. Check "Automatically continue"
6. Now prints value without stopping
```

**Useful for logging:**
```
po self.isRecording
expr print("Duration: \(video.duration)")
```

#### Symbolic Breakpoints

Break on any call to a method/function:

```
1. Debug > Breakpoints > Create Symbolic Breakpoint
2. Symbol: AVCaptureSession.startRunning
3. Now breaks whenever ANY code calls startRunning()
```

**Use cases:**
- Break on all exceptions: `objc_exception_throw`
- Break on UIViewController creation: `UIViewController.viewDidLoad`
- Break on memory warnings: `UIApplication.didReceiveMemoryWarning`

#### Exception Breakpoints

Break whenever an exception is thrown:

```
1. Breakpoint Navigator (Cmd + 8)
2. Click + button (bottom left)
3. Exception Breakpoint
4. Exception: All
5. Now Xcode pauses on any crash/exception
```

**Recommended**: Always have this enabled!

### 7.2 LLDB Basics

LLDB is the debugger console. Use it when paused at a breakpoint.

#### Opening LLDB Console

```
View > Debug Area > Show Debug Area (Cmd + Shift + Y)
```

#### Essential LLDB Commands

**Print Value:**
```lldb
(lldb) po video
▿ Video
  - id: UUID(...)
  - duration: 45.3
  - localPath: "/path/to/video.mp4"

(lldb) p video.duration
(Double) $0 = 45.3
```

**Difference between `po` and `p`:**
- `po` (print object): Uses `description` property, more readable
- `p` (print): Raw value, good for primitives

**Evaluate Expression:**
```lldb
(lldb) expr video.duration = 60.0
(lldb) po video.duration
60.0
```

**Call Methods:**
```lldb
(lldb) expr viewModel.startRecording()
(lldb) po isRecording
true
```

**View Memory Address:**
```lldb
(lldb) p video
(Video) $0 = 0x000060000123abc0 {...}
```

**Continue Execution:**
```lldb
(lldb) continue  (or just 'c')
```

**Step Through Code:**
```lldb
(lldb) next      # Step over (F6)
(lldb) step      # Step into (F7)
(lldb) finish    # Step out (F8)
```

**Inspect Variables:**
```lldb
(lldb) frame variable
(Video) video = 0x000060000123abc0
(Bool) isRecording = true
(TimeInterval) duration = 45.3
```

#### Advanced LLDB

**Print All Properties:**
```lldb
(lldb) po object_getClass(video)
```

**View Type Info:**
```lldb
(lldb) type lookup Video
```

**Breakpoint Commands:**
```lldb
(lldb) breakpoint set -n uploadVideo
(lldb) breakpoint list
(lldb) breakpoint delete 1
(lldb) breakpoint disable 2
```

**Conditional Breakpoint via LLDB:**
```lldb
(lldb) breakpoint set -n startRecording -c 'isRecording == false'
```

### 7.3 Memory Debugging

Find memory leaks and excessive memory usage.

#### Instruments - Leaks

**Run Leaks Instrument:**
```
1. Product > Profile (Cmd + I)
2. Select "Leaks" template
3. Click Record (red button)
4. Use your app
5. Watch for red bars (leaks detected)
```

**Common Leak: Retain Cycle**
```swift
// ❌ Leak
class VideoRecorder {
    var completionHandler: (() -> Void)?

    func record() {
        completionHandler = {
            self.stopRecording() // Strong reference to self
        }
    }
}

// ✅ Fixed
class VideoRecorder {
    var completionHandler: (() -> Void)?

    func record() {
        completionHandler = { [weak self] in
            self?.stopRecording() // Weak reference
        }
    }
}
```

#### Memory Graph Debugger

**Visualize object relationships:**
```
1. Run app (Cmd + R)
2. Click Memory Graph button in debug bar (icon with circles)
3. See all objects in memory
4. Find retain cycles (circular references)
```

**Interpreting the graph:**
- Each node = an object
- Arrows = references
- Cycle = potential leak

#### Debug Memory Graph

**Find specific leaks:**
```
1. In Memory Graph, select object
2. Show Memgraph to find what's retaining it
3. Look for unexpected strong references
```

**For TennisCoach:**
Common leak sources:
- Video recorder completion handlers
- Gemini service callbacks
- SwiftUI `@ObservedObject` instead of `@StateObject`

### 7.4 Network Debugging

Debug API calls to Gemini service.

#### Network Link Conditioner

Simulate slow/unreliable networks:

```
1. Download "Additional Tools for Xcode" from Apple
2. Install Network Link Conditioner
3. System Settings > Network Link Conditioner
4. Enable and select profile:
   - 3G (slow connection)
   - Very Bad Network (packet loss)
   - 100% Loss (offline)
```

Test TennisCoach:
- Does video upload handle slow networks?
- Does retry logic work?
- Are loading indicators shown?

#### Charles Proxy

Intercept and inspect HTTP traffic:

```
1. Install Charles Proxy
2. Configure iOS device proxy (Settings > Wi-Fi > HTTP Proxy)
3. See all API requests/responses
```

**Use for:**
- Verify request format
- Check response structure
- Debug authentication issues
- Test error handling

#### URLSession Debugging

Enable detailed logging:

```swift
// In GeminiService.swift
private let session: URLSession = {
    let configuration = URLSessionConfiguration.default

    #if DEBUG
    // Log all requests
    configuration.urlCache = nil
    #endif

    return URLSession(configuration: configuration)
}()
```

**Add logging middleware:**
```swift
extension URLRequest {
    func debug() {
        print("🌐 \(httpMethod ?? "GET") \(url?.absoluteString ?? "")")
        if let headers = allHTTPHeaderFields {
            print("Headers: \(headers)")
        }
        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
    }
}

// Usage
request.debug()
let (data, response) = try await session.data(for: request)
```

### 7.5 View Debugging

Debug SwiftUI view hierarchy and layout.

#### View Hierarchy Debugger

**3D visualization of views:**
```
1. Run app (Cmd + R)
2. Debug > View Debugging > Capture View Hierarchy
3. Rotate 3D view to see layers
4. Click on view to see properties
```

**Use for:**
- Finding hidden views
- Checking view overlap
- Debugging layout constraints
- Inspecting view properties

#### SwiftUI Inspector

**Inspect view at runtime:**
```swift
// Add to any view
.onAppear {
    print(Mirror(reflecting: self).children)
}
```

#### Print View Tree

```swift
extension View {
    func debug() -> Self {
        print(Mirror(reflecting: self).subjectType)
        return self
    }
}

// Usage
VStack {
    Text("Hello")
}.debug()
```

### 7.6 Debugging Best Practices

#### 1. Use Descriptive Print Statements

```swift
// ❌ Bad
print(video)

// ✅ Good
print("📹 Recording started: duration=\(video.duration)s, path=\(video.localPath)")
```

**Use emojis for visual scanning:**
```swift
print("✅ Upload successful")
print("❌ Upload failed: \(error)")
print("🔄 Retrying upload...")
print("⚠️ Low memory warning")
```

#### 2. Create Debug Helpers

```swift
extension Video {
    var debugDescription: String {
        """
        Video {
          id: \(id)
          duration: \(duration)s
          path: \(localPath)
          geminiURI: \(geminiFileUri ?? "nil")
          conversations: \(conversations.count)
        }
        """
    }
}

// Usage
print(video.debugDescription)
```

#### 3. Use Assertions

```swift
// Crash in debug builds if assumption is wrong
func uploadVideo(_ url: URL) {
    assert(Constants.API.hasAPIKey, "API key must be configured")
    assert(url.isFileURL, "URL must be a file URL")

    // Continue...
}
```

#### 4. Add Debug Menu (Development Only)

```swift
#if DEBUG
struct DebugMenuView: View {
    var body: some View {
        List {
            Button("Clear All Videos") {
                // Clear database
            }

            Button("Test API Connection") {
                // Test Gemini API
            }

            Button("Simulate Low Memory") {
                // Trigger low memory
            }
        }
    }
}
#endif
```

#### 5. Log to File (For Device Testing)

```swift
class AppLogger {
    static func log(_ message: String) {
        #if DEBUG
        print(message)

        // Also write to file for device debugging
        let logURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("debug.log")

        let timestamp = Date().ISO8601Format()
        let logMessage = "[\(timestamp)] \(message)\n"

        try? logMessage.write(to: logURL, atomically: false, encoding: .utf8)
        #endif
    }
}
```

---

## 8. Common Pitfalls & Solutions

### 8.1 SwiftData Pitfalls

#### Pitfall 1: Accessing @Model objects off main thread

```swift
// ❌ Crash
Task {
    let duration = video.duration // Crash if video is @Model
}

// ✅ Solution: Use @MainActor
@MainActor
func getDuration() -> TimeInterval {
    return video.duration
}
```

#### Pitfall 2: Deleting related objects

```swift
// ❌ Orphaned conversations
modelContext.delete(video)
// Conversations still exist!

// ✅ Solution: Use cascade delete rule
@Model
class Video {
    @Relationship(deleteRule: .cascade)
    var conversations: [Conversation]
}
```

### 8.2 Async/Await Pitfalls

#### Pitfall 1: Calling async from sync

```swift
// ❌ Can't call async function from sync context
func startRecording() {
    uploadVideo() // Error: async not allowed here
}

// ✅ Solution: Use Task
func startRecording() {
    Task {
        await uploadVideo()
    }
}
```

#### Pitfall 2: Not handling cancellation

```swift
// ❌ Task continues even if view disappears
.onAppear {
    Task {
        await longRunningTask()
    }
}

// ✅ Solution: Store task and cancel
@State private var uploadTask: Task<Void, Never>?

.onAppear {
    uploadTask = Task {
        await longRunningTask()
    }
}
.onDisappear {
    uploadTask?.cancel()
}
```

### 8.3 SwiftUI State Pitfalls

#### Pitfall 1: @ObservedObject vs @StateObject

```swift
// ❌ ViewModel gets recreated on every render
struct ChatView: View {
    @ObservedObject var viewModel = ChatViewModel()
}

// ✅ ViewModel persists across renders
struct ChatView: View {
    @StateObject var viewModel = ChatViewModel()
}
```

#### Pitfall 2: Mutating state in body

```swift
// ❌ Infinite loop
struct CounterView: View {
    @State var count = 0

    var body: some View {
        Text("\(count)")
            .onAppear {
                count += 1 // Triggers re-render → triggers onAppear → ...
            }
    }
}

// ✅ Use proper lifecycle
struct CounterView: View {
    @State var count = 0

    var body: some View {
        Text("\(count)")
            .task {
                count += 1 // Runs once
            }
    }
}
```

### 8.4 Memory Management Pitfalls

#### Pitfall 1: Capturing self strongly

```swift
// ❌ Retain cycle
class VideoRecorder {
    func record(completion: @escaping () -> Void) {
        output.finishRecording { [self] in
            self.cleanup() // Strong reference
            completion()
        }
    }
}

// ✅ Weak self
class VideoRecorder {
    func record(completion: @escaping () -> Void) {
        output.finishRecording { [weak self] in
            self?.cleanup() // Weak reference
            completion()
        }
    }
}
```

### 8.5 Performance Pitfalls

#### Pitfall 1: Blocking main thread

```swift
// ❌ UI freezes
func processVideo() {
    let data = try! Data(contentsOf: videoURL) // Blocks for seconds
    // ...
}

// ✅ Background processing
func processVideo() async {
    let data = try await Task.detached {
        try Data(contentsOf: videoURL)
    }.value
    // ...
}
```

#### Pitfall 2: Not reusing expensive objects

```swift
// ❌ Creates new formatter for every date
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter() // Expensive!
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

// ✅ Reuse formatter
class DateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

func formatDate(_ date: Date) -> String {
    DateFormatter.shared.string(from: date)
}
```

---

## Additional Resources

### Official Documentation
- [Swift.org - Documentation](https://swift.org/documentation/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

### Style Guides
- [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Ray Wenderlich Swift Style Guide](https://github.com/raywenderlich/swift-style-guide)
- [Google Swift Style Guide](https://google.github.io/swift/)

### Communities
- [Swift Forums](https://forums.swift.org/)
- [r/iOSProgramming](https://reddit.com/r/iOSProgramming)
- [Hacking with Swift](https://www.hackingwithswift.com/)
- [SwiftUI Lab](https://swiftui-lab.com/)

### Tools
- [SwiftLint](https://github.com/realm/SwiftLint) - Linting tool
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icon library
- [Charles Proxy](https://www.charlesproxy.com/) - Network debugging

---

## Quick Reference Card

### Essential Shortcuts
| Action | Shortcut |
|--------|----------|
| Build | `Cmd + B` |
| Run | `Cmd + R` |
| Test | `Cmd + U` |
| Clean | `Cmd + Shift + K` |
| Quick Open | `Cmd + Shift + O` |
| Toggle Breakpoint | `Cmd + \` |
| Show Debug Area | `Cmd + Shift + Y` |

### Build Troubleshooting
1. Clean build: `Cmd + Shift + K`
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Restart Xcode
4. Rebuild: `Cmd + B`

### Test Naming
```
test_<method>_<scenario>_<expectedBehavior>
```

### Commit Message Format
```
<type>: <subject>

Types: feat, fix, refactor, test, docs, style, chore
```

---

**Version**: 1.0
**Last Updated**: 2025-12-04
**Project**: TennisCoach iOS App
**Maintainer**: Development Team
