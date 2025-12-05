# TennisCoach Product Vision

## Executive Summary

TennisCoach is an AI-powered tennis coaching app that helps amateur players improve their technique through video analysis and personalized feedback. This document synthesizes research findings and outlines the product roadmap.

## Target Market

### Primary Users: Intermediate Improvers (45% of market)
- Playing 2-5 years, 2-3x per week
- Taking occasional lessons but want more feedback
- Willing to pay for improvement tools
- **Pain Point:** Plateau in improvement, expensive coach time

### Secondary Users
- **Beginners (40%):** Need more guidance, simpler explanations
- **Advanced (15%):** Need deeper analysis, biomechanical metrics

## Core Value Proposition

*"AI-powered analysis that approximates a professional coach's feedback at a fraction of the cost."*

### Competitive Advantages
1. **Conversational AI** - Natural language explanations with follow-up questions
2. **Multimodal Analysis** - Gemini analyzes full context (footwork, positioning, stroke)
3. **Chinese Language Support** - Underserved market opportunity
4. **Accessible Pricing** - Target $49/year vs $150/year competitors

---

## Feature Roadmap

### Phase 1: Foundation (Current + Next 3 Months)

#### Completed (v1.0-1.2)
- [x] 60fps video recording with lens switching (0.5x, 1x, 2x)
- [x] Tap-to-focus functionality
- [x] Recording time limits (30s@60fps for 100MB Gemini limit)
- [x] Auto-stop with 10-second warning
- [x] Gemini AI integration with streaming responses
- [x] Collapsible video preview in chat
- [x] Secure API key storage (Keychain)
- [x] Auto-save to Photos Library

#### P0 - Critical (Next Release)
1. **Enhanced Playback Controls**
   - Variable speed (0.25x, 0.5x, 0.75x, 1x, 2x)
   - Frame-by-frame stepping
   - A-B loop for segments
   - Jump to timestamp from chat

2. **Drawing/Annotation Tools**
   - Freehand drawing with colors
   - Lines, arrows, circles
   - Save annotated frames
   - Angle measurement tool

3. **Quick Record Mode**
   - Single tap start/stop
   - 30-second auto-timeout
   - Minimal UI for between-points use
   - Large touch targets (44pt+)

### Phase 2: Differentiation (3-6 Months)

1. **Progress Tracking Dashboard**
   - Score trends over time (chart)
   - Stroke-specific breakdown
   - Session history with calendar
   - AI-generated improvement insights

2. **Guided Recording Setup**
   - Shot-type selection (serve, forehand, etc.)
   - Angle guidance with diagrams
   - Alignment grid overlay
   - Saved angle presets

3. **Two-Tier Feedback**
   - Quick summary after recording
   - Optional deep-dive full analysis
   - Respects post-workout cognitive state

4. **Pose Estimation (Apple Vision)**
   - Skeleton overlay on key frames
   - Joint angle measurements
   - Visual "wow factor" for marketing

### Phase 3: Scale (6-12 Months)

1. **Drill Recommendation System**
   - 100+ drill database
   - AI-matched to identified issues
   - Progress tracking per drill

2. **Video Splitting for Long Sessions**
   - Split recordings at segment boundaries
   - Analyze each segment separately
   - Combine insights across segments

3. **HEVC Encoding**
   - 40-50% smaller files
   - Longer recording times
   - Faster uploads

4. **Ball Tracking (MVP)**
   - Serve speed measurement
   - Shot placement heatmaps
   - Requires 120fps upgrade

### Phase 4: Future (12+ Months)

- Multi-camera support (2+ angles)
- Side-by-side video comparison
- Coach marketplace (remote lessons)
- Social features (share, challenge friends)
- Wearable integration (Apple Watch)
- Real-time coaching mode

---

## Technical Architecture

### Current Stack
- **UI:** SwiftUI + SwiftData
- **AI:** Google Gemini (multimodal)
- **Video:** AVFoundation (60fps H.264)
- **Storage:** Local Documents + Photos Library
- **Security:** Keychain for API keys

### Planned Enhancements
- 120fps recording for detailed analysis
- HEVC encoding for compression
- Apple Vision framework for pose estimation
- SwiftUI Charts for progress visualization
- On-device ML for simple classifications

### API Cost Optimization
- Cache analysis results (already doing)
- Key frame sampling vs full video
- Tier analysis depth by subscription level
- On-device ML for preprocessing

---

## UX Priorities

### Environmental Challenges
Tennis courts are outdoor, high-brightness environments with time pressure.

1. **Sunlight Readability**
   - High-contrast outdoor mode
   - Solid colors (no transparency)
   - Larger text (18pt minimum)

2. **Sweaty Hands**
   - 44x44pt minimum touch targets
   - Forgiving tap zones
   - Confirmation for destructive actions

3. **Time Pressure**
   - Quick Record mode (single tap)
   - 15-30 seconds between points
   - Minimal cognitive load

### Key UX Metrics
- Time to first recording: <60 seconds
- Task completion rate: >90%
- 7-day retention: >50%
- 30-day retention: >25%

---

## Competitive Landscape

| App | Price | Strengths | Weaknesses |
|-----|-------|-----------|------------|
| SwingVision | $150/yr | Ball tracking, real-time stats | Complex, expensive |
| OnForm | $100/yr | Voice-over, multi-angle | Requires human coach |
| Tennis AI | TBD | Pose comparison to pros | Serve/groundstroke only |
| **TennisCoach** | $49/yr | Conversational AI, Chinese | Needs playback controls |

### Market Gap
The $49-79/year tier is largely empty. Most apps target competitive players ($150+) or are free with limited features.

---

## Success Metrics

### Engagement
- Weekly recordings per user: 3+
- Analysis read rate: >70%
- Follow-up questions per video: 2+

### Retention
- 7-day retention: >50%
- 30-day retention: >25%
- 90-day retention: >15%

### Revenue (Future)
- Free tier: 5 videos/month
- Pro tier: $49/year unlimited
- Coach tier: $99/year (marketplace access)

---

## Next Steps

1. **Immediate:** Add playback controls and annotation tools
2. **This Month:** Implement Quick Record mode for court usability
3. **Next Month:** Progress tracking dashboard
4. **Q1 2025:** Guided setup flow and pose estimation

---

*Document Version: 1.0*
*Last Updated: December 2025*
*Based on research from competitive analysis, UX research, and first-principles analysis*
