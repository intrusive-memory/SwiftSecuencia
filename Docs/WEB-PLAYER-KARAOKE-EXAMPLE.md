# Web Player Karaoke-Style Implementation Guide

## Overview

This guide demonstrates how to implement karaoke-style text highlighting using WebVTT files exported from SwiftSecuencia. The implementation uses the **TextTrack API** for precise, event-driven synchronization.

---

## Why WebVTT + TextTrack API?

### ✅ Optimal for Karaoke Highlighting

| Approach | Timing Method | Performance | Browser Support | Complexity |
|----------|--------------|-------------|-----------------|------------|
| **WebVTT + TextTrack** ⭐ | Event-driven (`cuechange`) | Excellent | Native | Low |
| JSON + `timeupdate` | Polling (250ms) | Good | Universal | Medium |
| JSON + `requestAnimationFrame` | Polling (60fps) | Moderate | Universal | High |

**TextTrack API advantages:**
1. **Event-driven** - `cuechange` fires exactly when cues activate/deactivate
2. **Browser-managed timing** - No polling overhead, perfect synchronization
3. **Native support** - All modern browsers (Chrome, Safari, Firefox, Edge)
4. **Efficient** - Lower CPU usage than polling approaches

---

## Implementation Pattern

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Web Player Flow                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Load screenplay.m4a + screenplay.vtt                     │
│                         │                                    │
│  2. Add <track> element to <audio>                           │
│                         │                                    │
│  3. Listen to TextTrack 'cuechange' events                   │
│                         │                                    │
│  4. On cuechange:                                            │
│     ├─► Get active cue                                       │
│     ├─► Extract character + text from <v> tag               │
│     ├─► Find matching DOM element                            │
│     └─► Apply highlight CSS class                            │
│                         │                                    │
│  5. Auto-scroll to keep highlighted text visible             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Complete HTML/JavaScript Example

### HTML Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Dao - Karaoke Reader</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f7;
        }

        .player {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }

        audio {
            width: 100%;
        }

        .transcript {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            max-height: 500px;
            overflow-y: auto;
            scroll-behavior: smooth;
        }

        .line {
            padding: 12px;
            margin: 8px 0;
            border-radius: 8px;
            transition: all 0.3s ease;
            cursor: pointer;
        }

        .line:hover {
            background: #f0f0f0;
        }

        /* Karaoke highlight */
        .line.active {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            transform: scale(1.02);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }

        .character {
            font-weight: 600;
            margin-right: 8px;
            opacity: 0.7;
        }

        .line.active .character {
            opacity: 1;
        }

        .text {
            line-height: 1.6;
        }

        /* Hide native subtitle track */
        video::cue {
            display: none;
        }
    </style>
</head>
<body>
    <div class="player">
        <h1>Daily Dao Audio Reader</h1>

        <!-- Audio player with WebVTT track -->
        <audio id="audioPlayer" controls>
            <source src="screenplay.m4a" type="audio/mp4">
            <!-- WebVTT track (hidden from subtitle display) -->
            <track
                id="timingTrack"
                kind="metadata"
                src="screenplay.vtt"
                default>
        </audio>
    </div>

    <div class="transcript" id="transcript">
        <!-- Transcript lines will be populated from WebVTT -->
    </div>

    <script src="karaoke-player.js"></script>
</body>
</html>
```

---

### JavaScript Implementation

```javascript
// karaoke-player.js

class KaraokePlayer {
    constructor(audioElementId, transcriptElementId) {
        this.audio = document.getElementById(audioElementId);
        this.transcript = document.getElementById(transcriptElementId);
        this.currentActiveLine = null;

        this.init();
    }

    async init() {
        // Wait for tracks to load
        await this.waitForTracksReady();

        // Get the timing track
        const track = this.audio.textTracks[0];
        track.mode = 'hidden'; // Hidden mode: events fire but no subtitle display

        // Build transcript from VTT cues
        this.buildTranscript(track);

        // Listen for cue changes
        track.addEventListener('cuechange', () => this.onCueChange(track));

        // Allow clicking lines to seek
        this.addClickToSeek();
    }

    waitForTracksReady() {
        return new Promise((resolve) => {
            const track = this.audio.textTracks[0];

            // Check if cues are already loaded
            if (track && track.cues && track.cues.length > 0) {
                resolve();
                return;
            }

            // Get the <track> element (not TextTrack object)
            const trackElement = this.audio.querySelector('track');

            if (!trackElement) {
                console.error('No <track> element found');
                resolve(); // Resolve anyway to prevent hanging
                return;
            }

            // Listen for the load event on the track element
            trackElement.addEventListener('load', () => {
                resolve();
            }, { once: true });

            // Fallback: if already loaded but event didn't fire
            if (trackElement.readyState === 2) { // LOADED = 2
                resolve();
            }
        });
    }

    buildTranscript(track) {
        const cues = Array.from(track.cues);

        cues.forEach((cue, index) => {
            const lineElement = this.createLineElement(cue, index);
            this.transcript.appendChild(lineElement);
        });
    }

    createLineElement(cue, index) {
        const line = document.createElement('div');
        line.className = 'line';
        line.dataset.cueId = cue.id;
        line.dataset.index = index;
        line.dataset.startTime = cue.startTime;

        // Parse character and text from VTT voice tag
        const { character, text } = this.parseVoiceTag(cue.text);

        // Build HTML
        if (character) {
            const characterSpan = document.createElement('span');
            characterSpan.className = 'character';
            characterSpan.textContent = character + ':';
            line.appendChild(characterSpan);
        }

        const textSpan = document.createElement('span');
        textSpan.className = 'text';
        textSpan.textContent = text;
        line.appendChild(textSpan);

        return line;
    }

    parseVoiceTag(vttText) {
        // Parse WebVTT voice tag: <v CHARACTER>Text</v>
        const voiceMatch = vttText.match(/<v\s+([^>]+)>([^<]+)<\/v>/);

        if (voiceMatch) {
            return {
                character: voiceMatch[1].trim(),
                text: voiceMatch[2].trim()
            };
        }

        // No voice tag, return plain text
        return {
            character: null,
            text: vttText.trim()
        };
    }

    onCueChange(track) {
        const activeCues = track.activeCues;

        // Remove previous highlight
        if (this.currentActiveLine) {
            this.currentActiveLine.classList.remove('active');
        }

        // Highlight current cue
        if (activeCues.length > 0) {
            const activeCue = activeCues[0];
            const lineElement = this.transcript.querySelector(
                `[data-cue-id="${activeCue.id}"]`
            );

            if (lineElement) {
                lineElement.classList.add('active');
                this.currentActiveLine = lineElement;

                // Auto-scroll to keep highlighted line visible
                this.scrollToLine(lineElement);
            }
        }
    }

    scrollToLine(lineElement) {
        const transcriptRect = this.transcript.getBoundingClientRect();
        const lineRect = lineElement.getBoundingClientRect();

        // Check if line is outside visible area
        const isAbove = lineRect.top < transcriptRect.top;
        const isBelow = lineRect.bottom > transcriptRect.bottom;

        if (isAbove || isBelow) {
            // Scroll to center the line
            const scrollTop = lineElement.offsetTop -
                (this.transcript.offsetHeight / 2) +
                (lineElement.offsetHeight / 2);

            this.transcript.scrollTo({
                top: scrollTop,
                behavior: 'smooth'
            });
        }
    }

    addClickToSeek() {
        this.transcript.addEventListener('click', (event) => {
            const lineElement = event.target.closest('.line');
            if (lineElement) {
                const startTime = parseFloat(lineElement.dataset.startTime);
                this.audio.currentTime = startTime;

                // Play if paused
                if (this.audio.paused) {
                    this.audio.play();
                }
            }
        });
    }
}

// Initialize player when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    const player = new KaraokePlayer('audioPlayer', 'transcript');
});
```

---

## Advanced Features

### 1. Progress Bar with Timestamps

```javascript
class KaraokePlayerWithProgress extends KaraokePlayer {
    init() {
        super.init();
        this.addProgressBar();
    }

    addProgressBar() {
        const progressContainer = document.createElement('div');
        progressContainer.className = 'progress-container';
        progressContainer.innerHTML = `
            <div class="progress-bar">
                <div class="progress-fill"></div>
            </div>
            <div class="time-display">
                <span class="current-time">0:00</span>
                <span class="total-time">0:00</span>
            </div>
        `;

        this.audio.parentElement.appendChild(progressContainer);

        // Update progress
        this.audio.addEventListener('timeupdate', () => {
            const percent = (this.audio.currentTime / this.audio.duration) * 100;
            document.querySelector('.progress-fill').style.width = percent + '%';
            document.querySelector('.current-time').textContent =
                this.formatTime(this.audio.currentTime);
        });

        // Set total time
        this.audio.addEventListener('loadedmetadata', () => {
            document.querySelector('.total-time').textContent =
                this.formatTime(this.audio.duration);
        });
    }

    formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }
}
```

### 2. Keyboard Shortcuts

```javascript
addKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
        switch(event.code) {
            case 'Space':
                event.preventDefault();
                this.audio.paused ? this.audio.play() : this.audio.pause();
                break;

            case 'ArrowLeft':
                event.preventDefault();
                this.skipBackward(5); // 5 seconds
                break;

            case 'ArrowRight':
                event.preventDefault();
                this.skipForward(5); // 5 seconds
                break;

            case 'ArrowUp':
                event.preventDefault();
                this.goToPreviousLine();
                break;

            case 'ArrowDown':
                event.preventDefault();
                this.goToNextLine();
                break;
        }
    });
}

goToPreviousLine() {
    if (this.currentActiveLine) {
        const previousLine = this.currentActiveLine.previousElementSibling;
        if (previousLine) {
            const startTime = parseFloat(previousLine.dataset.startTime);
            this.audio.currentTime = startTime;
        }
    }
}

goToNextLine() {
    if (this.currentActiveLine) {
        const nextLine = this.currentActiveLine.nextElementSibling;
        if (nextLine) {
            const startTime = parseFloat(nextLine.dataset.startTime);
            this.audio.currentTime = startTime;
        }
    }
}
```

### 3. Multi-Character Voice Highlighting

```css
/* Color code different characters */
[data-character="ALICE"] .character {
    color: #667eea;
}

[data-character="BOB"] .character {
    color: #f093fb;
}

[data-character="CHARLIE"] .character {
    color: #4facfe;
}
```

```javascript
createLineElement(cue, index) {
    const line = document.createElement('div');
    line.className = 'line';
    line.dataset.cueId = cue.id;
    line.dataset.index = index;
    line.dataset.startTime = cue.startTime;

    const { character, text } = this.parseVoiceTag(cue.text);

    // Add character data attribute for CSS styling
    if (character) {
        line.dataset.character = character;
    }

    // ... rest of line creation
}
```

---

## Testing the Implementation

### 1. Export from SwiftSecuencia

```swift
let exporter = ForegroundAudioExporter()
let result = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: URL(fileURLWithPath: "/path/screenplay.m4a"),
    timingDataFormat: .webvtt,  // Generate WebVTT
    progress: nil
)

// result.webvttURL = /path/screenplay.vtt
```

### 2. Test WebVTT Locally

```bash
# Serve files with simple HTTP server
cd /path/to/export
python3 -m http.server 8000
```

Open `http://localhost:8000/index.html` in browser

### 3. Verify Synchronization

- Play audio
- Confirm text highlights in sync
- Check transitions are smooth (no jumps)
- Test seeking (click on lines)
- Verify auto-scroll works

---

## Browser Compatibility

| Browser | TextTrack API | WebVTT | Notes |
|---------|--------------|--------|-------|
| Chrome 88+ | ✅ Full | ✅ Full | Excellent |
| Safari 14+ | ✅ Full | ✅ Full | Excellent |
| Firefox 85+ | ✅ Full | ✅ Full | Excellent |
| Edge 88+ | ✅ Full | ✅ Full | Excellent |

**Mobile Support:**
- iOS Safari 14+: ✅ Full support
- Chrome Android: ✅ Full support

---

## Performance Optimization

### 1. Large Transcripts (100+ lines)

Use virtual scrolling for better performance:

```javascript
// Only render visible lines + buffer
class VirtualizedTranscript {
    constructor(transcript, lineHeight = 60) {
        this.transcript = transcript;
        this.lineHeight = lineHeight;
        this.buffer = 10; // Lines above/below viewport
    }

    renderVisibleLines() {
        const scrollTop = this.transcript.scrollTop;
        const viewportHeight = this.transcript.offsetHeight;

        const startIndex = Math.max(0,
            Math.floor(scrollTop / this.lineHeight) - this.buffer
        );
        const endIndex = Math.min(this.totalLines,
            Math.ceil((scrollTop + viewportHeight) / this.lineHeight) + this.buffer
        );

        // Only render lines in range
        this.renderLines(startIndex, endIndex);
    }
}
```

### 2. Preload Audio

```html
<audio id="audioPlayer" controls preload="auto">
    <!-- Preload audio for instant playback -->
</audio>
```

### 3. Lazy Load VTT

```javascript
// Load VTT only when user starts playing
audio.addEventListener('play', async () => {
    if (!this.vttLoaded) {
        await this.loadVTT();
        this.vttLoaded = true;
    }
}, { once: true });
```

---

## Accessibility

### Screen Reader Support

```html
<!-- Add ARIA labels -->
<div class="line"
     role="button"
     tabindex="0"
     aria-label="ALICE: Hello, world! Click to play from this line"
     data-start-time="0">
    <span class="character">ALICE:</span>
    <span class="text">Hello, world!</span>
</div>
```

### Keyboard Navigation

```javascript
// Allow Tab navigation through lines
document.querySelectorAll('.line').forEach(line => {
    line.addEventListener('keypress', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            const startTime = parseFloat(line.dataset.startTime);
            this.audio.currentTime = startTime;
        }
    });
});
```

---

## Common Issues & Solutions

### Issue 1: Cues Not Loading (Race Condition)

**Problem**: Cues aren't ready when initializing, causing the player to fail

**Cause**: Using `setTimeout` with a fixed delay creates a race condition - cues may take longer to load on slow connections or with large VTT files

**Solution**: Listen for the `load` event on the `<track>` element

```javascript
waitForTracksReady() {
    return new Promise((resolve) => {
        const trackElement = this.audio.querySelector('track');

        // Listen for load event (no race condition)
        trackElement.addEventListener('load', () => {
            resolve();
        }, { once: true });

        // Fallback: check if already loaded
        if (trackElement.readyState === 2) { // LOADED = 2
            resolve();
        }
    });
}
```

**Why this works:**
- Event-driven: No arbitrary delays
- Reliable: Works regardless of file size or network speed
- Standard: Uses proper `HTMLTrackElement.readyState` API

### Issue 2: Cues Not Firing

**Problem**: `cuechange` events don't fire

**Solution**: Set track mode to `'hidden'` or `'showing'`

```javascript
track.mode = 'hidden'; // Required for events
```

### Issue 3: CORS Errors

**Problem**: VTT file not loading due to CORS

**Solution**: Serve VTT with correct CORS headers

```
Access-Control-Allow-Origin: *
Content-Type: text/vtt
```

### Issue 4: Voice Tags Not Parsing

**Problem**: Voice tags show as raw text

**Solution**: Use regex to parse `<v>` tags

```javascript
const voiceMatch = vttText.match(/<v\s+([^>]+)>([^<]+)<\/v>/);
```

---

## Summary

### ✅ WebVTT + TextTrack API is Perfect for Karaoke Highlighting

**Why:**
1. **Event-driven timing** - No polling, perfect sync
2. **Native browser support** - Works everywhere
3. **Low overhead** - Efficient, smooth performance
4. **Standard format** - W3C compliant

**Implementation Pattern:**
```
Export WebVTT → Load with <track> → Listen to cuechange → Highlight text
```

**Key Code:**
```javascript
track.addEventListener('cuechange', () => {
    const activeCue = track.activeCues[0];
    highlightLine(activeCue.id);
});
```

This approach is **production-ready** for Daily Dao's karaoke reader feature! 🎤
