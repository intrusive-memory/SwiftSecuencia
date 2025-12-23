# TODO

## Audio Generation Enhancements

- [x] Add inline timecodes during Mac audio generation for karaoke-style transcript sync (COMPLETED)
  - When generating audio from fountain scripts, output timing data (start/end timestamps) for each spoken line/segment
  - This enables synchronized "follow along" text display in the Daily Dao web player
  - **Implementation**: WebVTT and JSON timing data export integrated into ForegroundAudioExporter
  - **Formats**: `.webvtt` (TextTrack API, ±10ms precision), `.json` (custom parsers)
  - **Usage**: Set `timingDataFormat` parameter in `exportAudio`/`exportAudioDirect` methods
