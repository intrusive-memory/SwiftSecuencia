# SwiftSecuencia Code Flow Diagram

This diagram shows the complete path through SwiftSecuencia from timeline creation to FCPXML bundle export.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SWIFTSECUENCIA CODE PATH                         │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: CREATE TIMELINE DATA
═══════════════════════════════════════════════════════════════════════

┌──────────────────────┐
│ User/AppIntent/Test  │  Creates timeline programmatically
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Timeline.init()                        (Timeline.swift:195)          │
│ ─────────────────────────────────────────────────────────────────────│
│ • name: String                                                       │
│ • videoFormat: VideoFormat (e.g., 1080p @ 23.98fps)                 │
│ • audioLayout: AudioLayout (stereo, mono, 5.1)                      │
│ • audioRate: AudioRate (48kHz, 44.1kHz)                             │
└──────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ TimelineClip.init()                 (TimelineClip.swift:191)         │
│ ─────────────────────────────────────────────────────────────────────│
│ • assetStorageId: UUID (reference to TypedDataStorage)              │
│ • offset: Timecode (when clip starts on timeline)                   │
│ • duration: Timecode (how long clip plays)                          │
│ • sourceStart: Timecode (where in media to start)                   │
│ • lane: Int (0=primary, >0=B-roll, <0=audio)                        │
└──────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ timeline.appendClip(clip)           (Timeline.swift:226)             │
│            OR                                                         │
│ timeline.insertClip(clip, at:, lane:) (Timeline.swift:250)          │
│            OR                                                         │
│ timeline.insertClipWithRipple(...)   (Timeline.swift:364)           │
└──────────────────────────────────────────────────────────────────────┘
           │
           │ Timeline now has clips with proper timing
           ▼


STEP 2: EXPORT TO FCPXML BUNDLE
═══════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────┐
│ FCPXMLBundleExporter.exportBundle()  (FCPXMLBundleExporter.swift:121)│
│ ─────────────────────────────────────────────────────────────────────│
│ Inputs:                                                              │
│ • timeline: Timeline                                                 │
│ • modelContext: SwiftData.ModelContext                              │
│ • directory: URL (where to save)                                    │
│ • bundleName: String (e.g., "MyProject")                            │
│ • progress: Progress? (optional progress tracking)                  │
└──────────────────────────────────────────────────────────────────────┘
           │
           ├──────────────────────────────────────────────────┐
           │                                                  │
           ▼                                                  ▼
┌─────────────────────────┐                    ┌────────────────────────┐
│ Step 2.1: Create Bundle │  (5%)              │ Progress Reporting     │
│ Structure               │                    │ ──────────────────────│
│ (line 140)              │                    │ • 5%: Bundle created  │
│ ─────────────────────────│                    │ • 75%: Media exported │
│ MyProject.fcpxmld/      │                    │ • 90%: FCPXML done    │
│ ├── Media/              │                    │ • 95%: XML written    │
│ ├── Info.fcpxml         │                    │ • 100%: Plist done    │
│ └── Info.plist          │                    └────────────────────────┘
└─────────┬───────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Step 2.2: exportMedia()              (line 240)          70%         │
│ ─────────────────────────────────────────────────────────────────────│
│ For each asset in timeline:                                         │
│   1. Fetch TypedDataStorage from modelContext                       │
│   2. Get binary data (asset.binaryValue)                            │
│   3. If audio → convertAudioToM4A() (line 492)                      │
│      ├─ Detect silence at start/end                                 │
│      ├─ Convert to M4A format                                       │
│      └─ Measure actual duration                                     │
│   4. If video/image → write directly to Media/                      │
│   5. Build assetURLMap: [UUID: "Media/filename"]                    │
│   6. Track measuredDurations: [UUID: Double]                        │
│   7. Track audioTiming: [UUID: AudioTiming]                         │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Step 2.3: generateFCPXML()           (line 564)          15%         │
│ ─────────────────────────────────────────────────────────────────────│
│ Generate XML structure:                                              │
│   <fcpxml version="1.13">                                           │
│     <resources>                                                      │
│       <format id="r1" .../>        ← generateFormatElement()        │
│       <asset id="r2" .../>         ← generateAssetElement()         │
│     </resources>                                                     │
│     <library>                                                        │
│       <event name="...">                                            │
│         <project name="...">                                        │
│           <sequence format="r1">   ← generateSequenceElement()      │
│             <spine>                ← generateSpineElement()          │
│               <asset-clip ref="r2" ← generateAssetClipElement()     │
│                 offset="0s"                                          │
│                 duration="30s"                                       │
│                 start="0.5s"/>   ← adjusted for silence trim        │
│             </spine>                                                 │
│           </sequence>                                                │
│         </project>                                                   │
│       </event>                                                       │
│     </library>                                                       │
│   </fcpxml>                                                          │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Step 2.4: Write Info.fcpxml          (line 195)          5%          │
│ Write XML string to bundle                                          │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Step 2.5: generateInfoPlist()        (line 888)          5%          │
│ ─────────────────────────────────────────────────────────────────────│
│ Create Info.plist with:                                             │
│ • CFBundleName                                                      │
│ • CFBundlePackageType: "FCPB"                                       │
│ • CFBundleVersion: "1.0"                                            │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ RESULT: MyProject.fcpxmld bundle ready for Final Cut Pro!           │
└──────────────────────────────────────────────────────────────────────┘


EXAMPLE USE CASE: APP INTENT FLOW
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│ GenerateFCPXMLBundleIntent.perform()  (GenerateFCPXMLBundle....:100)│
│ ─────────────────────────────────────────────────────────────────────│
│ Input: ScreenplayElementsReference (from SwiftCompartido)           │
└─────────┬───────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│ createTimeline()                     (line 139)                      │
│ ─────────────────────────────────────────────────────────────────────│
│ For each dialogue element:                                          │
│   1. findAudio(for: element) → TypedDataStorage                     │
│   2. Create TimelineClip with:                                      │
│      • name: "Character: dialogue text..."                          │
│      • assetStorageId: audio.id                                     │
│      • duration: from audio.durationSeconds                         │
│   3. timeline.insertClip(clip, at: currentOffset)                   │
│   4. currentOffset += clip.duration                                 │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ FCPXMLBundleExporter.exportBundle()  (see Step 2 above)              │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Return IntentFile → User can open in Final Cut Pro                  │
└──────────────────────────────────────────────────────────────────────┘


KEY DATA STRUCTURES
═══════════════════════════════════════════════════════════════════════

Timeline (SwiftData @Model)
├─ name: String
├─ videoFormat: VideoFormat
├─ clips: [TimelineClip]
└─ duration: Timecode (computed)

TimelineClip (SwiftData @Model)
├─ assetStorageId: UUID → TypedDataStorage
├─ offset: Timecode (timeline position)
├─ duration: Timecode (playback length)
├─ sourceStart: Timecode (media in-point)
└─ lane: Int (track number)

TypedDataStorage (from SwiftCompartido)
├─ id: UUID
├─ binaryValue: Data (actual media file)
├─ mimeType: String
├─ durationSeconds: Double?
└─ prompt: String

ResourceMap (internal)
├─ formatID: String ("r1")
├─ assetIDs: [UUID: String] (UUID → "r2", "r3", ...)
└─ audioTiming: [UUID: AudioTiming] (silence trim info)
```

## Summary

The path through SwiftSecuencia follows these main steps:

1. **Create Timeline**: Initialize a `Timeline` object with format settings
2. **Add Clips**: Create `TimelineClip` objects that reference media in `TypedDataStorage`
3. **Position Clips**: Use `appendClip()`, `insertClip()`, or `insertClipWithRipple()` to place clips on the timeline
4. **Export Bundle**: Use `FCPXMLBundleExporter.exportBundle()` to create an `.fcpxmld` bundle:
   - Create bundle directory structure
   - Export media files to `Media/` folder (with audio conversion)
   - Generate FCPXML document with proper resource references
   - Write Info.plist metadata
5. **Import to FCP**: The resulting bundle can be opened directly in Final Cut Pro

## File References

- **Timeline**: `Sources/SwiftSecuencia/Timeline/Timeline.swift`
- **TimelineClip**: `Sources/SwiftSecuencia/Timeline/TimelineClip.swift`
- **FCPXMLBundleExporter**: `Sources/SwiftSecuencia/Export/FCPXMLBundleExporter.swift`
- **FCPXMLExporter**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`
- **GenerateFCPXMLBundleIntent**: `Sources/SwiftSecuencia/AppIntents/GenerateFCPXMLBundleIntent.swift`
