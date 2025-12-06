# FCPXML Reference Documentation

## Overview

FCPXML (Final Cut Pro XML) is Apple's XML interchange format for Final Cut Pro X. It allows third-party applications to create, read, and manipulate Final Cut Pro projects, timelines, and media references.

**Current Version:** 1.11 (as of Final Cut Pro 10.7+)
**Supported Versions:** 1.6 through 1.11

## Document Structure

An FCPXML document follows this basic hierarchy:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.11">
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

## Core Elements

### Root Element

```xml
<!ELEMENT fcpxml (import-options?, resources?, (library | event* | (%event_item;)*))>
<!ATTLIST fcpxml version CDATA #FIXED "1.11">
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

#### Asset

Defines media file references:

```xml
<asset id="r2"
       name="Interview_A"
       src="file:///path/to/media.mov"
       start="0s"
       duration="3600s"
       hasVideo="1"
       hasAudio="1"
       format="r1"
       audioSources="1"
       audioChannels="2"
       audioRate="48000">
    <media-rep kind="original-media" src="file:///path/to/media.mov"/>
</asset>
```

**Attributes:**
- `id` (required): Unique identifier
- `name`: Display name
- `src` (required): File URL to media
- `start`: Media start time
- `duration`: Media duration
- `hasVideo`, `hasAudio`: Media type flags (0 or 1)
- `format`: Reference to format ID
- `audioRate`: Sample rate (32000, 44100, 48000, 96000)
- `audioChannels`: Number of audio channels

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
<fcpxml version="1.11">
    <resources>
        <format id="r1"
                name="FFVideoFormat1080p2398"
                frameDuration="1001/24000s"
                width="1920"
                height="1080"
                colorSpace="1-1-1 (Rec. 709)"/>

        <asset id="r2"
               name="A001_C001"
               src="file:///Volumes/Media/A001_C001.mov"
               start="0s"
               duration="600s"
               hasVideo="1"
               hasAudio="1"
               format="r1"
               audioChannels="2"
               audioRate="48000"/>

        <asset id="r3"
               name="A001_C002"
               src="file:///Volumes/Media/A001_C002.mov"
               start="0s"
               duration="450s"
               hasVideo="1"
               hasAudio="1"
               format="r1"
               audioChannels="2"
               audioRate="48000"/>

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
