# FCPXML Element Reference

This document provides a quick reference for all FCPXML elements and their attributes.

## Root Element

### `<fcpxml>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `version` | String | Yes | FCPXML version (e.g., "1.11") |

**Children:** `import-options?`, `resources?`, `library | event* | event_item*`

---

## Resource Elements

### `<resources>`

Container for all reusable resources.

**Children:** `asset*`, `effect*`, `format*`, `media*`

---

### `<format>`

Defines video format specifications.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | ID | Yes | Unique identifier |
| `name` | String | No | Display name |
| `frameDuration` | Time | No | Duration per frame |
| `fieldOrder` | String | No | Field order for interlacing |
| `width` | Int | No | Frame width in pixels |
| `height` | Int | No | Frame height in pixels |
| `paspH` | Int | No | Pixel aspect ratio horizontal |
| `paspV` | Int | No | Pixel aspect ratio vertical |
| `colorSpace` | String | No | Color space specification |
| `projection` | String | No | VR projection type |
| `stereoscopic` | String | No | Stereoscopic mode |

---

### `<asset>`

Defines external media file reference.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | ID | Yes | Unique identifier |
| `name` | String | No | Display name |
| `uid` | String | No | FCP-assigned unique ID |
| `src` | URL | Yes | File URL to media |
| `start` | Time | No | Media start time |
| `duration` | Time | No | Media duration |
| `hasVideo` | 0/1 | No | Has video track |
| `format` | IDREF | No | Reference to format |
| `hasAudio` | 0/1 | No | Has audio track |
| `audioSources` | Int | No | Number of audio sources |
| `audioChannels` | Int | No | Number of audio channels |
| `audioRate` | Int | No | Audio sample rate |
| `customLUTOverride` | String | No | Custom LUT override |
| `colorSpaceOverride` | String | No | Color space override |
| `projectionOverride` | String | No | VR projection override |
| `stereoscopicOverride` | String | No | Stereoscopic override |

**Children:** `bookmark?`, `metadata?`, `media-rep*`

---

### `<effect>`

Defines an effect, transition, or generator.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | ID | Yes | Unique identifier |
| `name` | String | No | Display name |
| `uid` | String | Yes | Effect unique identifier |
| `src` | URL | No | Path to effect bundle |

---

### `<media>`

Defines compound clips, multicam, or sequences.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | ID | Yes | Unique identifier |
| `name` | String | No | Display name |
| `uid` | String | No | FCP-assigned unique ID |
| `projectRef` | IDREF | No | Reference to project |
| `modDate` | DateTime | No | Modification date |

**Children:** `multicam | sequence`

---

## Organizational Elements

### `<library>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | URL | No | File URL to library bundle |
| `colorProcessing` | Enum | No | standard, wide, wide-hdr |

**Children:** `event*`, `smart-collection*`

---

### `<event>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Event name |
| `uid` | String | No | Unique identifier |

**Children:** `clip*`, `audition*`, `mc-clip*`, `ref-clip*`, `sync-clip*`, `asset-clip*`, `project*`, `collection-folder*`, `keyword-collection*`, `smart-collection*`

---

### `<project>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Project name |
| `uid` | String | No | Unique identifier |
| `id` | ID | No | Document ID |
| `modDate` | DateTime | No | Modification date |

**Children:** `sequence`

---

## Timeline Elements

### `<sequence>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `format` | IDREF | Yes | Reference to format |
| `duration` | Time | No | Sequence duration |
| `tcStart` | Time | No | Starting timecode |
| `tcFormat` | DF/NDF | No | Timecode format |
| `audioLayout` | Enum | No | mono, stereo, surround |
| `audioRate` | Enum | No | 32k, 44.1k, 48k, etc. |
| `renderFormat` | String | No | Render codec |
| `keywords` | String | No | Associated keywords |

**Children:** `note?`, `spine`, `metadata?`

---

### `<spine>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `name` | String | No | Display name |
| `format` | IDREF | No | Reference to format |

**Children:** `clip_item*`, `transition*`

---

## Clip Elements

### `<asset-clip>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to asset |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start time |
| `duration` | Time | No | Clip duration |
| `enabled` | 0/1 | No | Active state (default: 1) |
| `srcEnable` | Enum | No | all, audio, video |
| `audioRole` | String | No | Audio role assignment |
| `videoRole` | String | No | Video role assignment |
| `modDate` | DateTime | No | Modification date |

**Children:** `note?`, `conform-rate?`, `timeMap?`, intrinsic-params, `anchor_item*`, `marker_item*`, `audio-channel-source*`, `filter-video*`, `filter-audio*`, `metadata?`

---

### `<clip>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start time |
| `duration` | Time | Yes | Clip duration |
| `enabled` | 0/1 | No | Active state (default: 1) |
| `format` | IDREF | No | Reference to format |
| `tcStart` | Time | No | Timecode start |
| `tcFormat` | DF/NDF | No | Timecode format |
| `audioStart` | Time | No | Audio start offset |
| `audioDuration` | Time | No | Audio duration |
| `modDate` | DateTime | No | Modification date |

**Children:** `note?`, `conform-rate?`, `timeMap?`, intrinsic-params, `spine?`, `clip_item*`, `marker_item*`, `audio-channel-source*`, `filter-video*`, `filter-audio*`, `metadata?`

---

### `<ref-clip>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to media |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start time |
| `duration` | Time | No | Clip duration |
| `enabled` | 0/1 | No | Active state (default: 1) |
| `srcEnable` | Enum | No | all, audio, video |
| `useAudioSubroles` | 0/1 | No | Use audio subroles |

**Children:** `note?`, `conform-rate?`, `timeMap?`, intrinsic-params, `anchor_item*`, `marker_item*`, `audio-role-source*`, `filter-video*`, `filter-audio*`, `metadata?`

---

### `<sync-clip>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start time |
| `duration` | Time | No | Clip duration |
| `enabled` | 0/1 | No | Active state (default: 1) |
| `format` | IDREF | No | Reference to format |

**Children:** `note?`, `conform-rate?`, `timeMap?`, intrinsic-params, `spine?`, `clip_item*`, `marker_item*`, `sync-source*`, `filter-video*`, `filter-audio*`, `metadata?`

---

### `<mc-clip>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to multicam media |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start time |
| `duration` | Time | No | Clip duration |
| `enabled` | 0/1 | No | Active state (default: 1) |
| `srcEnable` | Enum | No | all, audio, video |

**Children:** `note?`, `conform-rate?`, `timeMap?`, `adjust-volume?`, `adjust-panner?`, `mc-source*`, `anchor_item*`, `marker_item*`, `filter-audio*`, `metadata?`

---

### `<gap>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Display name |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Start time |
| `duration` | Time | Yes | Gap duration |
| `enabled` | 0/1 | No | Active state (default: 1) |

**Children:** `note?`, `anchor_item*`, `marker_item*`, `metadata?`

---

### `<audition>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `modDate` | DateTime | No | Modification date |

**Children:** `audio | video | title | ref-clip | asset-clip | clip | sync-clip`+

---

## Audio/Video Elements

### `<video>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to asset |
| `srcID` | String | No | Source track ID |
| `role` | String | No | Role assignment |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start |
| `duration` | Time | Yes | Duration |
| `enabled` | 0/1 | No | Active state |

---

### `<audio>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to asset |
| `srcID` | String | No | Source track ID |
| `role` | String | No | Role assignment |
| `srcCh` | String | No | Source channels |
| `outCh` | String | No | Output channels |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start |
| `duration` | Time | Yes | Duration |
| `enabled` | 0/1 | No | Active state |

---

### `<title>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to effect |
| `name` | String | No | Display name |
| `lane` | Int | No | Vertical position |
| `offset` | Time | No | Timeline position |
| `start` | Time | No | Source start |
| `duration` | Time | Yes | Duration |
| `enabled` | 0/1 | No | Active state |
| `role` | String | No | Role assignment |

**Children:** `param*`, `text*`, `text-style-def*`, `note?`, intrinsic-params-video, `anchor_item*`, `marker_item*`, `filter-video*`, `metadata?`

---

## Transition Element

### `<transition>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Display name |
| `offset` | Time | No | Timeline position |
| `duration` | Time | Yes | Transition duration |

**Children:** `filter-video?`, `filter-audio?`, `marker_item*`, `metadata?`

---

## Adjustment Elements

### `<adjust-transform>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `enabled` | 0/1 | No | Active state |
| `position` | String | No | "x y" position |
| `scale` | String | No | "x y" scale |
| `rotation` | Float | No | Rotation in degrees |
| `anchor` | String | No | "x y" anchor point |

---

### `<adjust-crop>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `mode` | Enum | Yes | trim, crop, pan |
| `enabled` | 0/1 | No | Active state |

**Children:** `crop-rect?`, `trim-rect?`, `pan-rect*`

---

### `<adjust-volume>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `amount` | String | No | Volume in dB (e.g., "-6dB") |

**Children:** `param*`

---

### `<adjust-blend>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `amount` | Float | No | Opacity (0.0-1.0) |
| `mode` | String | No | Blend mode |

---

### `<adjust-conform>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | Enum | No | fit, fill, none |

---

## Timing Elements

### `<conform-rate>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `scaleEnabled` | 0/1 | No | Enable scaling |
| `srcFrameRate` | Enum | No | Source frame rate |
| `frameSampling` | Enum | No | Sampling method |

---

### `<timeMap>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `frameSampling` | Enum | No | Sampling method |
| `preservesPitch` | 0/1 | No | Preserve audio pitch |

**Children:** `timept*`

---

### `<timept>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `time` | Time | Yes | Output time |
| `value` | String | Yes | Source time ratio |
| `interp` | Enum | No | smooth2, linear, smooth |
| `inTime` | Time | No | Bezier in time |
| `outTime` | Time | No | Bezier out time |

---

## Filter Elements

### `<filter-video>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to effect |
| `name` | String | No | Display name |
| `enabled` | 0/1 | No | Active state |

**Children:** `info-asc-cdl?`, `data?`, `param*`

---

### `<filter-audio>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | Yes | Reference to effect |
| `name` | String | No | Display name |
| `enabled` | 0/1 | No | Active state |
| `presetID` | String | No | Preset identifier |

**Children:** `data?`, `param*`

---

## Parameter & Animation Elements

### `<param>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | Parameter name |
| `key` | String | No | Parameter key |
| `value` | String | No | Parameter value |
| `enabled` | 0/1 | No | Active state |

**Children:** `fadeIn?`, `fadeOut?`, `keyframeAnimation?`, `param*`

---

### `<keyframeAnimation>`

**Children:** `keyframe*`

---

### `<keyframe>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `time` | Time | Yes | Keyframe time |
| `value` | String | Yes | Keyframe value |
| `interp` | Enum | No | linear, ease, easeIn, easeOut |
| `curve` | Enum | No | linear, smooth |

---

## Marker Elements

### `<marker>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `start` | Time | Yes | Marker position |
| `duration` | Time | No | Marker duration |
| `value` | String | Yes | Marker text |
| `completed` | String | No | To-do completion |
| `note` | String | No | Additional notes |

---

### `<chapter-marker>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `start` | Time | Yes | Marker position |
| `duration` | Time | No | Duration |
| `value` | String | Yes | Chapter name |
| `note` | String | No | Notes |
| `posterOffset` | Time | No | Poster frame offset |

---

### `<keyword>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `start` | Time | No | Range start |
| `duration` | Time | No | Range duration |
| `value` | String | Yes | Keyword text |
| `note` | String | No | Notes |

---

### `<rating>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | No | Rating name |
| `start` | Time | No | Range start |
| `duration` | Time | No | Range duration |
| `value` | Enum | Yes | favorite, reject |
| `note` | String | No | Notes |

---

## Metadata Elements

### `<metadata>`

**Children:** `md*`

---

### `<md>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | String | Yes | Metadata key |
| `value` | String | No | Metadata value |
| `editable` | 0/1 | No | User editable |
| `type` | Enum | No | string, boolean, integer, float, date, timecode |
| `displayName` | String | No | Display name |
| `description` | String | No | Description |
| `source` | String | No | Value source |

---

## Text Elements

### `<text>`

Contains text content with optional styling.

**Children:** `#PCDATA`, `text-style*`

---

### `<text-style>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `ref` | IDREF | No | Reference to style def |
| `font` | String | No | Font name |
| `fontSize` | Float | No | Font size |
| `fontFace` | String | No | Font face |
| `fontColor` | String | No | "R G B A" |
| `bold` | 0/1 | No | Bold style |
| `italic` | 0/1 | No | Italic style |
| `strokeColor` | String | No | Stroke color |
| `strokeWidth` | Float | No | Stroke width |
| `baseline` | Float | No | Baseline offset |
| `shadowColor` | String | No | Shadow color |
| `shadowOffset` | String | No | Shadow offset |
| `shadowBlurRadius` | Float | No | Shadow blur |
| `kerning` | Float | No | Letter spacing |
| `alignment` | Enum | No | left, center, right, justified |
| `lineSpacing` | Float | No | Line spacing |

---

### `<text-style-def>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | ID | Yes | Unique identifier |
| `name` | String | No | Style name |

**Children:** `text-style`

---

## Collection Elements

### `<keyword-collection>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | Collection name |

---

### `<smart-collection>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | Collection name |
| `match` | Enum | Yes | any, all |

**Children:** `match-text*`, `match-ratings*`, `match-media*`, `match-clip*`, `match-keywords*`, `match-property*`, `match-time*`, `match-timeRange*`, `match-roles*`

---

### `<collection-folder>`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | Folder name |

**Children:** `collection-folder*`, `keyword-collection*`, `smart-collection*`
