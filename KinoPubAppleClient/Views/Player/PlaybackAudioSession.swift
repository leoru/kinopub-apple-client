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
/// than mirroring). **Apple API limitation:** `AVAudioSession.RouteSharingPolicy.longFormVideo`
/// is `API_UNAVAILABLE(tvos)` in the tvOS 26 SDK — the constant does not compile there at
/// all, so the policy is iOS-only rather than merely attempted everywhere. Re-probe on the
/// next SDK. Where it is available it is still only attempted: a policy the device refuses
/// must not cost us the category.
enum PlaybackAudioSession {

  /// Off the main thread on purpose: `setActive` blocks on the audio daemon, and UIKit
  /// says so out loud ("This method can lead to UI unresponsiveness if called on the main
  /// thread") — the call used to come straight from `preparePlayback`, which is main-actor.
  static func activate() {
    Task.detached(priority: .userInitiated) {
      let session = AVAudioSession.sharedInstance()
      do {
        try setPlaybackCategory(on: session)
        try session.setActive(true)
      } catch {
        Logger.app.error("Audio session activation failed: \(error.localizedDescription)")
      }
    }
  }

  private static func setPlaybackCategory(on session: AVAudioSession) throws {
#if os(iOS)
    do {
      try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
      return
    } catch {
      Logger.app.debug("Long-form video policy refused: \(error.localizedDescription)")
    }
#endif
    try session.setCategory(.playback, mode: .moviePlayback)
  }

  /// Handing the session back is what lets whatever was playing before us resume. Called
  /// when a stream is torn down, never merely when it pauses. Off-main like `activate`.
  static func deactivate() {
    Task.detached(priority: .utility) {
      do {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      } catch {
        // Routine: the session refuses to go inactive while any of our audio is still
        // winding down. The next `activate()` re-establishes it either way.
        Logger.app.debug("Audio session deactivation skipped: \(error.localizedDescription)")
      }
    }
  }
}
#endif
