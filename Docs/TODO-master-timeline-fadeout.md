---
type: doc
name: Master Timeline Fade-Out (export-time)
description: Add an optional whole-timeline fade-out ramp to the foreground exporter so the final mix smooths out instead of hard-cutting at the end.
status: incomplete
---

# Master Timeline Fade-Out (export-time)

**Goal.** Add an optional **master fade-out** over the final *N* seconds of the
**entire** exported timeline — one ramp applied across the whole mix, so *any*
number of lanes still playing at the end (dialogue tail, a background bed that
overruns, an overlay) fade out together smoothly instead of hard-cutting.

**Why now.** Produciesta is lifting intro/outro `<include>` beds onto one global
timeline (see Produciesta `Docs/TODO-global-timeline-brackets.md`). A bed that
runs past the last spoken word currently ends with an abrupt cut, because the
exporter has no fade. Produciesta clamps such a bed to the timeline end (hard
cut) as a stopgap; this TODO is the real fix that makes the cut a smooth fade.
Produciesta will pass a fade duration through once this lands.

## Current state (accurate as of v3.4.0)

The infrastructure is already here — this is an **extension, not new plumbing**:

- `ForegroundAudioExporter.exportComposition` already attaches an
  `AVMutableAudioMix` to the export session
  (`exportSession.audioMix = audioMix`, ForegroundAudioExporter.swift:748).
- `makeAudioMix(_:)` (ForegroundAudioExporter.swift:833) builds one
  `AVMutableAudioMixInputParameters` per track and currently only sets a
  **constant** volume: `params.setVolume(entry.volume, at: .zero)` (line 839).
- `AVMutableAudioMixInputParameters` also supports
  `setVolumeRamp(fromStartVolume:toEndVolume:timeRange:)` — that is the missing
  piece.

## Proposed change

1. **API.** Add an optional `masterFadeOut: TimeInterval = 0` parameter to the
   public `exportAudio(timeline:modelContext:to:timingDataFormat:progress:)`
   (and `exportAudioDirect`). `0` ⇒ today's behavior exactly (no ramp).
2. **Compute the fade window.** Total timeline duration `T` is already known when
   the composition is built. Fade range = `[max(0, T − masterFadeOut), T]`,
   clamped so the fade never exceeds the timeline.
3. **Apply the ramp to every track.** In (or after) `makeAudioMix`, for each
   `AVMutableAudioMixInputParameters`, append
   `setVolumeRamp(fromStartVolume: entry.volume, toEndVolume: 0,
   timeRange: fadeRange)`. Because it is applied per-track across **all** lanes,
   a bed/overlay still sounding at `T` fades with the dialogue tail — the whole
   mix goes to silence together.
   - Keep the existing `setVolume(entry.volume, at: .zero)` so the clip holds its
     gain up to the fade start, then ramps down.
4. **No clamp here.** Bounding the composition to the timeline end stays the
   caller's concern (Produciesta clamps bed `clip.duration`). This TODO is purely
   the trailing ramp.

## Test plan

- **Unit (`makeAudioMix`/export):** with `masterFadeOut: 4`, every input-parameter
  set has a volume ramp ending at `0` over `[T−4, T]`; with `masterFadeOut: 0`
  the mix is byte-for-byte the pre-change constant-volume mix.
- **Unit (clamp of fade window):** `masterFadeOut` longer than `T` ramps over the
  whole `[0, T]` rather than going negative.
- **Integration:** export a timeline with a lane still playing at `T`; assert the
  tail RMS over the final second is monotonically decreasing to ~silence.
- **Regression:** existing exporter tests (no `masterFadeOut`) unchanged.

## Release

Cut a SwiftSecuencia release after this lands and bump Produciesta off the
pinned `v3.4.0`, then wire Produciesta's bracket fade-out through the new param
(replacing the hard-cut stopgap).
</content>
