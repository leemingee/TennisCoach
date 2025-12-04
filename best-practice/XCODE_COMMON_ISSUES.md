# Xcode Common Issues & Fixes

> A troubleshooting guide for common Xcode build errors in the TennisCoach project.
> Pass this to AI assistants or interns when they encounter build issues.

---

## Table of Contents

1. [File Reference Issues](#1-file-reference-issues)
2. [Module Not Found Errors](#2-module-not-found-errors)
3. [String Parsing Errors](#3-string-parsing-errors)
4. [Target Membership Issues](#4-target-membership-issues)
5. [General Troubleshooting](#5-general-troubleshooting)

---

## 1. File Reference Issues

### Problem: Files exist on disk but Xcode doesn't see them

**Symptom:**
- Files show in Finder but not in Xcode Project Navigator
- Build errors saying file/type doesn't exist

**Why it happens:**
- Xcode maintains its own file registry in `.xcodeproj/project.pbxproj`
- Adding files via Finder/CLI doesn't update this registry
- Only Xcode GUI can reliably update project references

**Fix:**
1. In Xcode, right-click the target folder (e.g., `TennisCoach`)
2. Select **"Add Files to TennisCoach..."**
3. Navigate to the files/folders
4. **Important checkboxes:**
   - ☐ Copy items if needed: **UNCHECK** (files already in place)
   - ☑ Create groups: **CHECK**
   - ☑ Add to targets: Select appropriate target
5. Click **Add**

**Prevention:**
- Always add files through Xcode, not Finder/CLI
- If using CLI to create files, must still add references in Xcode

---

## 2. Module Not Found Errors

### Problem: "No such module 'XCTest'"

**Error message:**
```
No such module 'XCTest'
```

**Why it happens:**
- Test file (`*Tests.swift`) is in the **main app target** instead of **test target**
- XCTest framework is only available to test targets

**Example of wrong structure:**
```
TennisCoach/                    ← Main target
├── Models/
├── Services/
└── Tests/                      ← WRONG! Tests in main target
    └── RetryPolicyTests.swift  ← Will fail with "No such module 'XCTest'"
```

**Correct structure:**
```
TennisCoach/                    ← Main target
├── Models/
├── Services/
└── ...

TennisCoachTests/               ← Test target
├── RetryPolicyTests.swift      ← CORRECT! Tests in test target
├── GeminiServiceTests.swift
└── ...
```

**Fix:**
1. Move the file to correct folder:
   ```bash
   mv TennisCoach/Tests/SomeTests.swift TennisCoachTests/
   ```

2. In Xcode:
   - Find the file under wrong target → Right-click → **Delete** → **"Remove Reference"** (NOT "Move to Trash")
   - Right-click **TennisCoachTests** → **Add Files to TennisCoach...**
   - Select the moved file
   - Target: ☑ **TennisCoachTests** only
   - Click **Add**

3. Rebuild: `Cmd + B`

**Prevention:**
- All files with `import XCTest` must be in test target
- Test files should be named `*Tests.swift`
- Keep test files in `TennisCoachTests/` folder

---

## 3. String Parsing Errors

### Problem: "Expected ',' separator" in Chinese strings

**Error message:**
```
Expected ',' separator
Text("点击下方"录制"开始录制你的网球视频")
```

**Why it happens:**
- Chinese/CJK quotation marks `"` and `"` look similar to Swift string delimiters `"`
- Swift parser gets confused by nested quote-like characters

**Example of problematic code:**
```swift
// ❌ BAD - Chinese quotes inside string
Text("点击下方"录制"开始录制你的网球视频")

// Swift sees this as:
// Text("点击下方"  ← String ends here
// 录制             ← Unknown identifier
// "开始录制..."    ← New string starts
```

**Fix options:**

```swift
// ✅ Option 1: Use Chinese brackets (Recommended)
Text("点击下方「录制」开始录制你的网球视频")

// ✅ Option 2: Use angle brackets
Text("点击下方《录制》开始录制你的网球视频")

// ✅ Option 3: Use escaped quotes
Text("点击下方\"录制\"开始录制你的网球视频")

// ✅ Option 4: Use single quotes visually
Text("点击下方'录制'开始录制你的网球视频")
```

**Prevention:**
- Avoid using `"` `"` `'` `'` inside Swift strings
- Use `「」`、`『』`、`《》` for Chinese text emphasis
- Or escape with backslash: `\"`

---

## 4. Target Membership Issues

### Problem: File builds in wrong target or missing from target

**Symptoms:**
- "Use of undeclared type" for types that exist
- Test code compiling into main app
- App code not found in tests

**How to check target membership:**
1. Select the file in Project Navigator
2. Open File Inspector (`Cmd + Option + 1`)
3. Look at "Target Membership" section
4. Check which targets have ☑ checkmark

**Correct target membership:**

| File Type | TennisCoach (App) | TennisCoachTests | TennisCoachUITests |
|-----------|:-----------------:|:----------------:|:------------------:|
| Models/*.swift | ☑ | ☐ | ☐ |
| Services/*.swift | ☑ | ☐ | ☐ |
| Views/*.swift | ☑ | ☐ | ☐ |
| *Tests.swift | ☐ | ☑ | ☐ |
| *UITests.swift | ☐ | ☐ | ☑ |

**Fix:**
1. Select the file
2. Open File Inspector (`Cmd + Option + 1`)
3. In "Target Membership", check/uncheck appropriate targets

**Note:** Test targets can access main target code via `@testable import TennisCoach`

---

## 5. General Troubleshooting

### Step-by-step debugging process

```
1. Read the error message carefully
   ↓
2. Note the file path and line number
   ↓
3. Check: Is file in correct folder?
   ↓
4. Check: Is file in correct target? (File Inspector → Target Membership)
   ↓
5. Check: Does Xcode see the file? (visible in Project Navigator?)
   ↓
6. If not visible: Add file reference via Xcode GUI
   ↓
7. Clean build folder: Cmd + Shift + K
   ↓
8. Rebuild: Cmd + B
```

### Useful Xcode shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + B` | Build |
| `Cmd + Shift + K` | Clean Build Folder |
| `Cmd + Option + 1` | Show File Inspector |
| `Cmd + 1` | Show Project Navigator |
| `Cmd + Shift + O` | Open Quickly (find any file) |
| `Cmd + Shift + J` | Reveal current file in Navigator |

### Nuclear option: Clean everything

If nothing else works:

```bash
# Close Xcode first!

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/TennisCoach-*

# Remove build folder
rm -rf /Users/yoyo/src/TennisCoach/TennisCoach/build

# Reopen Xcode and rebuild
```

---

## CLI Limitations

### What CAN be done via CLI:
- ✅ Create/edit/delete source files
- ✅ Move files between folders
- ✅ Run builds: `xcodebuild`
- ✅ Run tests: `xcodebuild test`

### What CANNOT be reliably done via CLI:
- ❌ Add file references to Xcode project
- ❌ Remove file references from Xcode project
- ❌ Change target membership
- ❌ Modify project settings

**Why?** The `.xcodeproj/project.pbxproj` file uses a proprietary format with UUIDs. Manual editing risks corruption.

**Workaround tools** (use with caution):
- `xcodegen` - Generate project from YAML spec
- `xcodeproj` Ruby gem - Programmatic project editing
- `tuist` - Project generation tool

For simple projects, just use Xcode GUI for project management.

---

## Quick Reference Card

### Error → Likely Cause → Fix

| Error | Cause | Fix |
|-------|-------|-----|
| "No such module 'XCTest'" | Test file in app target | Move to test target, update references |
| "Expected ',' separator" (Chinese) | Chinese quotes in string | Use `「」` instead of `""` |
| "Use of undeclared type 'X'" | Missing target membership | Check File Inspector → Target Membership |
| "No such file or directory" | File not in project | Add via Xcode → Add Files |
| "Multiple commands produce" | Duplicate file references | Remove duplicate in Build Phases |

---

## For AI Assistants

When helping with Xcode build errors:

1. **Ask for the exact error message** - Copy/paste from Xcode
2. **Ask for file location** - Full path helps diagnose target issues
3. **Remember CLI limitations** - File reference changes need Xcode GUI
4. **Check target membership** - Most "not found" errors are target issues
5. **Chinese string issues** - Look for `""` `''` characters in strings

**Do not attempt to:**
- Manually edit `project.pbxproj`
- Use `sed`/`awk` on Xcode project files
- Promise CLI solutions for reference management

**Instead, provide:**
- Clear step-by-step Xcode GUI instructions
- Explanations of why the error occurred
- Prevention tips for the future

---

*Last updated: 2025-12-04*
*Project: TennisCoach iOS App*
