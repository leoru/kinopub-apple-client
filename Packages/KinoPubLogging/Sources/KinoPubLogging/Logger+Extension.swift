//
//  Logger+Extension.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
import OSLog

/// An enumeration representing different categories for logging.
/// These categories can be used to categorize and filter logs.
enum LoggingCategory: String {
  case viewCycle    // Represents logging related to the view's lifecycle events
  case analytics    // Represents logging related to analytics events or data
  case backend      // Represents logging related to backend interactions and responses
  case app          // Represents general application-level logging
  case kit          // Represents logging related to kit
}

public extension Logger {
  
  /// The application's bundle identifier, used as the subsystem for logging.
  private static var subsystem = Bundle.main.bundleIdentifier!
  
  /// Logger instance specific to `viewCycle` logging.
  static let viewCycle = Logger(subsystem: subsystem, category: LoggingCategory.viewCycle.rawValue)
  
  /// Logger instance specific to `analytics` logging.
  static let analytics = Logger(subsystem: subsystem, category: LoggingCategory.analytics.rawValue)
  
  /// Logger instance specific to `backend` logging.
  static let backend = Logger(subsystem: subsystem, category: LoggingCategory.backend.rawValue)
  
  /// Logger instance specific to general `app` logging.
  static let app = Logger(subsystem: subsystem, category: LoggingCategory.app.rawValue)
  
  /// Logger instance specific to general `kit` logging.
  static let kit = Logger(subsystem: subsystem, category: LoggingCategory.kit.rawValue)
}
