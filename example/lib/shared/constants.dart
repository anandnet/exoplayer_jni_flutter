/// Shared test URLs and helpers used across all example screens.
library;

// ── Sample media URLs ────────────────────────────────────────────────────────

const kHlsUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

const kDashUrl =
    'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.mpd';

const kMp4Url =
    'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4';

const kMp4Url2 =
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';

/// A deliberately invalid URL for testing error handling.
const kBadUrl = 'https://invalid.example.test/not-a-video.m3u8';

// ── Audio-only sample URLs ────────────────────────────────────────────────────

const kAudioMp3Url =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

const kAudioMp3Url2 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';

const kAudioMp3Url3 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';

const kAudioMp3Url4 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3';

const kAudioMp3Url5 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3';

const kAudioMp3Url6 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3';

const kAudioMp3Url7 =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3';

const kAudioPlaylist = [
  PlaylistEntry(
      title: 'SoundHelix Song 1',
      artist: 'SoundHelix',
      url: kAudioMp3Url,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 2',
      artist: 'SoundHelix',
      url: kAudioMp3Url2,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 3',
      artist: 'SoundHelix',
      url: kAudioMp3Url3,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 4',
      artist: 'SoundHelix',
      url: kAudioMp3Url4,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 5',
      artist: 'SoundHelix',
      url: kAudioMp3Url5,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 6',
      artist: 'SoundHelix',
      url: kAudioMp3Url6,
      format: 'MP3'),
  PlaylistEntry(
      title: 'SoundHelix Song 7',
      artist: 'SoundHelix',
      url: kAudioMp3Url7,
      format: 'MP3'),
];

// ── Playlist entries ──────────────────────────────────────────────────────────

class PlaylistEntry {
  final String title;
  final String artist;
  final String url;
  final String format;

  const PlaylistEntry({
    required this.title,
    required this.artist,
    required this.url,
    required this.format,
  });
}

const kPlaylist = [
  PlaylistEntry(
    title: 'Big Buck Bunny',
    artist: 'Blender Foundation',
    url: kHlsUrl,
    format: 'HLS',
  ),
  PlaylistEntry(
    title: '⚠ Broken Video (error test)',
    artist: 'Test',
    url: kBadUrl,
    format: 'BAD',
  ),
  PlaylistEntry(
    title: 'Tears of Steel',
    artist: 'Blender Foundation',
    url: kDashUrl,
    format: 'DASH',
  ),
  PlaylistEntry(
    title: 'Big Buck Bunny (MP4)',
    artist: 'Blender Foundation',
    url: kMp4Url,
    format: 'MP4',
  ),
  PlaylistEntry(
    title: "Elephant's Dream",
    artist: 'Blender Foundation',
    url: kMp4Url2,
    format: 'MP4',
  ),
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
