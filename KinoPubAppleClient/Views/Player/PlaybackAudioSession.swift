//
//  PlaybackAudioSession.swift
//  KinoPubAppleClient
//
//  The audio session video playback needs, activated around a `PlayerManager`.
//

#if os(iOS) || os(tvOS)
import AVFoundation
import KinoPubLogging
import OSLog

/// **Why the iPhone player was silent.** An app that never configures its session gets
/// `.soloAmbient`, and that category is *obeys the Ring/Silent switch* by definition: with
/// the switch down there is no sound and no way to turn any on, because the volume buttons
/// are moving the ringer, not media. `.playback` is the category for media that is the
/// point of the app — it plays through the silent switch, takes the media volume, and is
/// the category Picture in Picture and background audio are only granted with.
///
/// `.longFormVideo` is the routing policy for a video app (AirPlay 2 video routes rather
/// than mirroring); it is attempted first and the plain category is the fallback, because a
/// policy the platform refuses must not cost us the category.
enum PlaybackAudioSession {

  static func activate() {
    let session = AVAudioSession.sharedInstance()
    do {
      do {
        try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
      } catch {
        Logger.app.debug("Long-form video policy refused: \(error.localizedDescription)")
        try session.setCategory(.playback, mode: .moviePlayback)
      }
      try session.setActive(true)
    } catch {
      Logger.app.error("Audio session activation failed: \(error.localizedDescription)")
    }
  }

  /// Handing the session back is what lets whatever was playing before us resume. Called
  /// when a stream is torn down, never merely when it pauses.
  static func deactivate() {
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      // Routine: the session refuses to go inactive while any of our audio is still
      // winding down. The next `activate()` re-establishes it either way.
      Logger.app.debug("Audio session deactivation skipped: \(error.localizedDescription)")
    }
  }
}
#endif
