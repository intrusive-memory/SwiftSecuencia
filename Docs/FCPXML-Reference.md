# FCPXML Reference Documentation

## Overview

FCPXML (Final Cut Pro XML) is Apple's XML interchange format for Final Cut Pro X. It allows third-party applications to create, read, and manipulate Final Cut Pro projects, timelines, and media references.

**Current Version:** 1.14 (as of Final Cut Pro 12.0+)
**Supported Versions:** 1.8 through 1.14

### Version History

| FCPXML Version | Final Cut Pro Version | Release Date | Key Features |
|----------------|----------------------|--------------|--------------|
| 1.14 | FCP 12.0+ | March 2025 | AI search (`isRelatedTo`), transcript/visual scope, `match-analysis-type` |
| 1.13 | FCP 11.0+ | November 2024 | Spatial video (`heroEye`, `adjust-stereo-3D`), `hidden-clip-marker`, high frame rates (90/100/119.88/120 fps) |
| 1.12 | FCP 10.8+ | March 2024 | Filter `nameOverride`, `optical-flow-frc` frame sampling |
| 1.11 | FCP 10.7+ | November 2023 | Caption improvements, enhanced metadata |

## Document Structure

An FCPXML document follows this basic hierarchy:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.14">
    <resources>
        <!-- Formats, Assets, Effects, Media definitions -->
    </resources>
    <library location="file:///path/to/library.fcpbundle">
        <event name="Event Name">
            <project name="Project Name">
                <sequence>
                    <spine>
                        <!-- Clips, Gaps, Transitions -->
                    </spine>
                </sequence>
            </project>
        </event>
    </library>
</fcpxml>
```

## Time Format

FCPXML uses rational numbers to represent time values with 64-bit numerators and 32-bit denominators:

| Format | Example | Description |
|--------|---------|-------------|
| Rational | `1001/30000s` | NTSC 29.97 fps (1 frame) |
| Rational | `100/2500s` | 25 fps (1 frame) |
| Rational | `100/2400s` | 24 fps (1 frame) |
| Integer | `5s` | 5 seconds |
| Fraction | `1/30s` | 1/30th of a second |

### Common Frame Rates

| Frame Rate | Frame Duration |
|------------|---------------|
| 23.98 fps | `1001/24000s` |
| 24 fps | `100/2400s` |
| 25 fps | `100/2500s` |
| 29.97 fps | `1001/30000s` |
| 30 fps | `100/3000s` |
| 50 fps | `100/5000s` |
| 59.94 fps | `1001/60000s` |
| 60 fps | `100/6000s` |

## Required Naming Conventions

FCPXML has strict naming requirements for several elements. Violating them causes FCP to reject the file or silently misinterpret it.

### Resource IDs — `r`-prefix + incrementing integer

All resource elements (`<format>`, `<asset>`, `<effect>`, `<media>`) require a unique `id` attribute. The **required convention** is:

```
r1, r2, r3, r4, ...
```

- **Always starts at `r1`** — the format resource is conventionally assigned `r1`.
- **Each subsequent resource increments the counter**: `r2`, `r3`, etc.
- IDs must be unique within the document — using duplicate IDs causes FCP import to fail.
- SwiftSecuencia assigns IDs automatically in this scheme; you do not set them in the JSON input.

### Format Element `name` — Apple `FFVideoFormat` Naming Scheme

The `<format>` element's `name` attribute must match Apple's internal format registry for FCP to recognize the video format correctly. The pattern is:

```
FFVideoFormat{resolution}{field}{fps}
```

Where:
- `{resolution}` — frame dimensions using shorthand for standard resolutions or full WxH for non-standard:
  - Standard HD/UHD: `720`, `1080`, `2160` (shorthand for 1280×720, 1920×1080, 3840×2160)
  - DCI/non-standard: `4096x2160`, `1440x1080`, etc. (full width×height)
- `{field}` — `p` for progressive, `i` for interlaced
- `{fps}` — frame rate suffix:
  - NTSC fractional rates: 4 digits (`2398` for 23.98, `2997` for 29.97, `5994` for 59.94)
  - Whole-number rates: 2 digits (`24`, `25`, `30`, `50`, `60`, `90`, `100`, `120`)

**Examples:**

| Resolution | Frame Rate | Format Name |
|------------|------------|-------------|
| 3840×2160 (UHD) | 23.98 fps | `FFVideoFormat2160p2398` |
| 3840×2160 (UHD) | 24 fps | `FFVideoFormat2160p24` |
| 3840×2160 (UHD) | 25 fps | `FFVideoFormat2160p25` |
| 3840×2160 (UHD) | 29.97 fps | `FFVideoFormat2160p2997` |
| 4096×2160 (DCI 4K) | 23.98 fps | `FFVideoFormat4096x2160p2398` |
| 1920×1080 (HD) | 23.98 fps | `FFVideoFormat1080p2398` |
| 1920×1080 (HD) | 25 fps | `FFVideoFormat1080p25` |
| 1920×1080 (HD) | 29.97 fps | `FFVideoFormat1080p2997` |
| 1920×1080 (HD) | 59.94 fps (interlaced) | `FFVideoFormat1080i5994` |
| 1280×720 (HD) | 29.97 fps | `FFVideoFormat720p2997` |

SwiftSecuencia derives this name from the `format.width`, `format.height`, and `format.frameRate` fields in your JSON and sets it automatically in the generated FCPXML.

### Asset `name` Attribute

The `<asset>` element's `name` attribute appears in FCP's browser as the clip's display name. It is not required to be unique, but should be human-readable. SwiftSecuencia derives it from the clip's `name` field in the JSON.

### Chapter Markers

Chapter markers in FCPXML are `<chapter-marker>` elements nested **inside** an `<asset-clip>` element (not top-level). The `value` attribute is the chapter title:

```xml
<asset-clip ref="r2" offset="0s" duration="30s" name="Act 1" start="0s" tcFormat="NDF">
    <chapter-marker start="0s" duration="0s" value="Introduction"/>
</asset-clip>
```

**Note:** The JSON `marker` clip type (with `markerType: "chapter"`) is accepted and validated by `secuencia validate`, but the current FCPXML exporter does not yet emit `<chapter-marker>` elements in its output. If chapter markers are needed, post-process the generated FCPXML to insert `<chapter-marker>` nodes into the appropriate `<asset-clip>` elements.

---

## Core Elements

### Root Element

```xml
<!ELEMENT fcpxml (import-options?, resources?, (library | event* | (%event_item;)*))>
<!ATTLIST fcpxml version CDATA #FIXED "1.14">
```

### Resources

The `<resources>` section defines reusable components:

#### Format

Defines video format specifications:

```xml
<format id="r1"
        name="FFVideoFormat1080p25"
        frameDuration="100/2500s"
        width="1920"
        height="1080"
        colorSpace="1-1-1 (Rec. 709)"/>
```

**Attributes:**
- `id` (required): Unique identifier within the document
- `name`: Human-readable format name
- `frameDuration`: Frame duration as rational time
- `width`, `height`: Frame dimensions in pixels
- `colorSpace`: Color space specification
- `fieldOrder`: Interlacing (progressive, upper first, lower first)
- `paspH`, `paspV`: Pixel aspect ratio
- `projection` (v1.13+): Spherical projection type for 360° video
- `stereoscopic` (v1.13+): Stereoscopic video flag (0 or 1)
- `heroEye` (v1.13+): Hero eye for spatial video (`left`, `right`)

#### Asset

Defines media file references. Since FCPXML v1.9, the `src` attribute has been moved from `<asset>` to the `<media-rep>` child element.

```xml
<asset id="r2"
       name="Interview_A"
       start="0s"
       duration="3600s"
       hasVideo="1"
       hasAudio="1"
       format="r1"
       audioSources="1"
       audioChannels="2"
       audioRate="48000">
    <media-rep kind="original-media"
               sig="1234567890ABCDEF"
               src="file:///path/to/media.mov"
               suggestedFilename="Interview_A.mov"/>
</asset>
```

**Attributes:**
- `id` (required): Unique identifier
- `name`: Display name
- `start`: Media start time
- `duration`: Media duration
- `hasVideo`, `hasAudio`: Media type flags (0 or 1)
- `format`: Reference to format ID
- `audioRate`: Sample rate (32000, 44100, 48000, 96000)
- `audioChannels`: Number of audio channels
- `videoSources` (v1.13+): Number of video sources
- `colorSpaceOverride` (v1.13+): Override color space for this asset
- `projectionOverride` (v1.13+): Override projection type for 360° video
- `stereoscopicOverride` (v1.13+): Override stereoscopic flag
- `heroEyeOverride` (v1.13+): Override hero eye for spatial video
- `auxVideoFlags` (v1.13+): Auxiliary video flags for spatial/360° content

**Media-Rep Child Element (v1.9+):**
- `kind` (required): Type of media representation (`original-media`, `proxy-media`, `optimized-media`)
- `sig`: File signature for media matching
- `src` (required): File URL to media
- `suggestedFilename`: Suggested filename when exporting

#### Effect

Defines effects, transitions, and generators:

```xml
<effect id="r3"
        name="Cross Dissolve"
        uid="FxPlug:4731E73A-8DAC-4113-9A30-5765E7E8B4F3"/>
```

**Attributes:**
- `id` (required): Unique identifier
- `name`: Display name
- `uid` (required): Effect unique identifier
- `src`: Path to effect bundle

#### Media

Defines compound clips, multicam clips, and sequences:

```xml
<media id="r4" name="Compound Clip">
    <sequence duration="600s" format="r1" tcStart="0s" tcFormat="NDF">
        <spine>
            <!-- Clips -->
        </spine>
    </sequence>
</media>
```

### Library

Container for events and projects:

```xml
<library location="file:///path/to/library.fcpbundle"
         colorProcessing="wide">
    <event name="My Event" uid="ABC123">
        <!-- Projects, clips, collections -->
    </event>
</library>
```

**Attributes:**
- `location`: File URL to library bundle
- `colorProcessing`: Color processing mode (standard, wide, wide-hdr)

### Event

Groups related clips and projects:

```xml
<event name="Event Name" uid="unique-id">
    <project name="Project 1">...</project>
    <clip>...</clip>
    <keyword-collection name="Interview"/>
    <smart-collection name="Favorites" match="all">...</smart-collection>
</event>
```

### Project

Contains a single sequence (timeline):

```xml
<project name="My Project" uid="project-uid" modDate="2024-01-15 10:30:00 -0800">
    <sequence format="r1"
              duration="3600s"
              tcStart="0s"
              tcFormat="NDF"
              audioLayout="stereo"
              audioRate="48k">
        <spine>
            <!-- Timeline content -->
        </spine>
    </sequence>
</project>
```

### Sequence

Represents a timeline:

```xml
<sequence format="r1"
          duration="3600s"
          tcStart="3600s"
          tcFormat="NDF"
          audioLayout="stereo"
          audioRate="48k"
          renderFormat="FFRenderFormatProRes422">
    <note>Sequence notes here</note>
    <spine>
        <!-- Primary storyline -->
    </spine>
    <metadata>...</metadata>
</sequence>
```

**Attributes:**
- `format` (required): Reference to format ID
- `duration`: Sequence duration
- `tcStart`: Starting timecode
- `tcFormat`: Timecode format (DF = drop frame, NDF = non-drop frame)
- `audioLayout`: Audio channel layout (mono, stereo, surround)
- `audioRate`: Sample rate (32k, 44.1k, 48k, 88.2k, 96k, 176.4k, 192k)

### Spine

The primary storyline container:

```xml
<spine>
    <asset-clip ref="r2" offset="0s" duration="300s"/>
    <transition duration="30/30s"/>
    <asset-clip ref="r3" offset="270s" duration="300s"/>
    <gap duration="100s"/>
</spine>
```

**Attributes:**
- `lane`: Vertical track position (0 = primary, positive = above, negative = below)
- `offset`: Position in parent timeline
- `name`: Display name
- `format`: Reference to format ID

## Clip Types

### Asset Clip

Direct reference to a media asset:

```xml
<asset-clip ref="r2"
            name="Interview A"
            offset="0s"
            start="100s"
            duration="300s"
            enabled="1"
            audioRole="dialogue"
            videoRole="video.video-1">
    <audio-channel-source srcCh="1, 2" outCh="L, R" role="dialogue"/>
</asset-clip>
```

**Key Attributes:**
- `ref` (required): Reference to asset ID
- `offset`: Position in parent timeline
- `start`: Start point within source media
- `duration`: Length of clip
- `enabled`: Active state (0 or 1)
- `srcEnable`: Media to use (all, audio, video)
- `audioRole`, `videoRole`: Role assignments

### Clip (Container)

A clip container that can hold nested content:

```xml
<clip name="Compound" offset="0s" duration="600s" format="r1">
    <spine>
        <asset-clip ref="r2" duration="300s"/>
        <asset-clip ref="r3" duration="300s"/>
    </spine>
</clip>
```

### Ref Clip

Reference to a media resource (compound clip, multicam):

```xml
<ref-clip ref="r4"
          offset="0s"
          duration="600s"
          srcEnable="all"
          useAudioSubroles="1"/>
```

### Sync Clip

Synchronized clip container:

```xml
<sync-clip offset="0s" duration="300s" format="r1">
    <spine>
        <asset-clip ref="r2" duration="300s"/>
    </spine>
    <asset-clip ref="r3" lane="1" duration="300s"/>
    <sync-source sourceID="storyline">
        <audio-role-source role="dialogue"/>
    </sync-source>
</sync-clip>
```

### Multicam Clip

Multi-angle clip:

```xml
<mc-clip ref="r5" offset="0s" duration="300s">
    <mc-source angleID="angle1" srcEnable="video"/>
    <mc-source angleID="angle2" srcEnable="audio"/>
</mc-clip>
```

### Gap

Empty space on the timeline:

```xml
<gap offset="0s" duration="100s" name="Gap">
    <!-- Connected clips can be attached -->
    <asset-clip ref="r2" lane="1" offset="50s" duration="100s"/>
</gap>
```

### Audition

Alternative clips container:

```xml
<audition offset="0s">
    <asset-clip ref="r2" duration="300s"/>  <!-- Active pick -->
    <asset-clip ref="r3" duration="300s"/>  <!-- Alternative -->
    <asset-clip ref="r4" duration="300s"/>  <!-- Alternative -->
</audition>
```

## Audio/Video Elements

### Video

```xml
<video ref="r2"
       offset="0s"
       duration="300s"
       role="video.video-1"
       srcID="1">
    <param name="amount" key="1" value="50"/>
</video>
```

### Audio

```xml
<audio ref="r2"
       offset="0s"
       duration="300s"
       role="dialogue"
       srcCh="1, 2"
       outCh="L, R">
    <adjust-volume amount="-6dB"/>
</audio>
```

## Titles and Text

```xml
<title ref="r6"
       name="Basic Title"
       offset="0s"
       duration="300s"
       role="titles.titles">
    <param name="Text" value="Hello World"/>
    <text>
        <text-style ref="ts1" font="Helvetica" fontSize="72">
            Hello World
        </text-style>
    </text>
    <text-style-def id="ts1">
        <text-style font="Helvetica"
                    fontSize="72"
                    fontColor="1 1 1 1"
                    bold="0"
                    italic="0"
                    alignment="center"/>
    </text-style-def>
</title>
```

## Captions

Captions (subtitles/closed captions) were introduced in FCPXML v1.10. They can be embedded in iTT (iTunes Timed Text) format or referenced externally.

### Caption Element

```xml
<caption name="English"
         start="100s"
         duration="10s"
         enabled="1"
         lane="1"
         offset="0s"
         role="captions.iTT?captionFormat=ITT">
    <text>
        <text-style ref="ts1">Hello, world!</text-style>
    </text>
    <text-style-def id="ts1">
        <text-style font="Helvetica"
                    fontSize="24"
                    fontColor="1 1 1 1"
                    backgroundColor="0 0 0 0.8"
                    alignment="center"/>
    </text-style-def>
    <note>Speaker identification</note>
</caption>
```

**Attributes:**
- `name`: Display name for the caption
- `start`: Start time in timeline
- `duration`: Duration of caption display
- `enabled`: Active state (0 or 1)
- `lane`: Vertical track position
- `offset`: Position in parent timeline
- `role`: Caption role (typically `captions.iTT?captionFormat=ITT`)

**Child Elements:**
- `<text>`: Caption text content with styling
- `<text-style-def>`: Text style definitions
- `<note>`: Optional notes or speaker identification

### iTT Caption Example

```xml
<caption name="English Captions"
         start="0s"
         duration="3600s"
         role="captions.iTT?captionFormat=ITT">
    <text>
        <text-style ref="ts1">Welcome to the presentation.</text-style>
    </text>
    <text-style-def id="ts1">
        <text-style font="Helvetica"
                    fontSize="24"
                    fontColor="1 1 1 1"
                    backgroundColor="0 0 0 0.8"/>
    </text-style-def>
</caption>
```

## Transitions

```xml
<transition name="Cross Dissolve"
            offset="270s"
            duration="30/30s">
    <filter-video ref="r3" name="Cross Dissolve"/>
</transition>
```

## Adjustments

### Transform

```xml
<adjust-transform enabled="1"
                  position="100 50"
                  scale="1.5 1.5"
                  rotation="45"
                  anchor="0 0"/>
```

### Crop

```xml
<adjust-crop mode="trim" enabled="1">
    <trim-rect left="100" top="50" right="100" bottom="50"/>
</adjust-crop>
```

### Volume

```xml
<adjust-volume amount="-6dB">
    <param name="amount" value="-6">
        <keyframeAnimation>
            <keyframe time="0s" value="-12" interp="linear"/>
            <keyframe time="5s" value="-6" interp="ease"/>
        </keyframeAnimation>
    </param>
</adjust-volume>
```

### Blend

```xml
<adjust-blend amount="0.5" mode="multiply"/>
```

## Effects and Filters

### Video Filter

```xml
<filter-video ref="r7" name="Gaussian Blur" enabled="1">
    <param name="Amount" key="1" value="10"/>
</filter-video>
```

### Audio Filter

```xml
<filter-audio ref="r8" name="Compressor" enabled="1">
    <param name="Threshold" value="-12"/>
    <param name="Ratio" value="4"/>
</filter-audio>
```

## Markers and Keywords

### Marker

```xml
<marker start="100s" duration="1s" value="Review this section" note="Needs color correction"/>
```

### Chapter Marker

```xml
<chapter-marker start="0s" value="Introduction" posterOffset="5s"/>
```

### Rating

```xml
<rating start="0s" duration="300s" value="favorite" note="Best take"/>
```

### Keyword

```xml
<keyword start="0s" duration="300s" value="Interview"/>
```

## Metadata

```xml
<metadata>
    <md key="com.apple.proapps.studio.reel" value="A001"/>
    <md key="com.apple.proapps.studio.scene" value="1"/>
    <md key="com.apple.proapps.studio.take" value="3"/>
    <md key="com.apple.proapps.spotlight.kMDItemDescription" value="Interview with subject"/>
</metadata>
```

## Smart Collections

```xml
<smart-collection name="Interviews" match="all">
    <match-text enabled="1" rule="includes" value="Interview"/>
    <match-ratings enabled="1" value="favorites"/>
    <match-media enabled="1" rule="is" type="videoWithAudio"/>
</smart-collection>
```

## Complete Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.14">
    <resources>
        <format id="r1"
                name="FFVideoFormat1080p2398"
                frameDuration="1001/24000s"
                width="1920"
                height="1080"
                colorSpace="1-1-1 (Rec. 709)"/>

        <asset id="r2"
               name="A001_C001"
               start="0s"
               duration="600s"
               hasVideo="1"
               hasAudio="1"
               format="r1"
               audioChannels="2"
               audioRate="48000">
            <media-rep kind="original-media" src="file:///Volumes/Media/A001_C001.mov"/>
        </asset>

        <asset id="r3"
               name="A001_C002"
               start="0s"
               duration="450s"
               hasVideo="1"
               hasAudio="1"
               format="r1"
               audioChannels="2"
               audioRate="48000">
            <media-rep kind="original-media" src="file:///Volumes/Media/A001_C002.mov"/>
        </asset>

        <effect id="r4"
                name="Cross Dissolve"
                uid="FxPlug:4731E73A-8DAC-4113-9A30-5765E7E8B4F3"/>
    </resources>

    <library location="file:///Users/editor/Movies/MyLibrary.fcpbundle">
        <event name="Scene 1" uid="E1234567">
            <project name="Scene 1 - Assembly" uid="P1234567" modDate="2024-01-15 10:30:00 -0800">
                <sequence format="r1"
                          duration="1000s"
                          tcStart="86400s"
                          tcFormat="NDF"
                          audioLayout="stereo"
                          audioRate="48k">
                    <spine>
                        <asset-clip ref="r2"
                                    name="A001_C001"
                                    offset="0s"
                                    start="100s"
                                    duration="500s"
                                    audioRole="dialogue">
                            <adjust-volume amount="-3dB"/>
                        </asset-clip>

                        <transition name="Cross Dissolve" duration="1001/24000s">
                            <filter-video ref="r4"/>
                        </transition>

                        <asset-clip ref="r3"
                                    name="A001_C002"
                                    offset="499s"
                                    start="50s"
                                    duration="500s"
                                    audioRole="dialogue"/>
                    </spine>
                </sequence>
            </project>

            <keyword-collection name="Selects"/>
            <smart-collection name="Favorites" match="all">
                <match-ratings enabled="1" value="favorites"/>
            </smart-collection>
        </event>
    </library>
</fcpxml>
```

## Sources

- [Apple FCPXML Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)
- [FCP Cafe - FCPXML Developer Resources](https://fcp.cafe/developers/fcpxml/)
- [FCPXML DTD v1.7](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/LegacyDTDsFinalCutPro/FCPXMLDTDv1.7/FCPXMLDTDv1.7.html)
- [Apple Use XML to Transfer Projects](https://support.apple.com/guide/final-cut-pro/use-xml-to-transfer-projects-verdbd66ae/mac)
