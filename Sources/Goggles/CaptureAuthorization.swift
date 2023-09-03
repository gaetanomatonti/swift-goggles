//
// Goggles
//
// Copyright © 2023 Gaetano Matonti. All rights reserved.
//

#if !os(visionOS)
import AVFoundation

/// An object that manages authorization requests to capture devices.
public struct CaptureAuthorization {

  // MARK: - Stored Properties
  
  /// Requests the authorization status for the specified `AVMediaType`.
  public var requestAuthorization: (AVMediaType) async -> Bool
  
  /// The authorization status for the specified `AVMediaType`.
  public var authorizationStatus: (AVMediaType) -> AVAuthorizationStatus

  /// Requests the authorization status for the `.video` media type.
  ///
  /// Use this function to request the authorization status for the `Camera` object.
  public let requestCameraAuthorization: () async -> Bool
  
  /// The authorization status for the `.video` media type.
  ///
  /// Use this function to access the authorization status for the `Camera` object.
  public var cameraAuthorizationStatus: AVAuthorizationStatus {
    authorizationStatus(.video)
  }
  
  // MARK: - Init
  
  /// Creates an instance of the `CaptureAuthorization` object.
  /// - Parameters:
  ///   - requestAuthorization: The function that requests the authorization status for the specified `AVMediaType`.
  ///   - authorizationStatus: The function that returns the authorization status for the specified `AVMediaType`.
  public init(
    authorizationStatus: @escaping (AVMediaType) -> AVAuthorizationStatus,
    requestAuthorization: @escaping (AVMediaType) async -> Bool
  ) {
    self.authorizationStatus = authorizationStatus
    self.requestAuthorization = requestAuthorization
    self.requestCameraAuthorization = {
      await requestAuthorization(.video)
    }
  }
}

public extension CaptureAuthorization {
  /// A live instance of the `CaptureAuthorization` object.
  ///
  /// This object interacts with the `AVFoundation` APIs to determine and request authorization to capture devices.
  static let live = CaptureAuthorization { mediaType in
    AVCaptureDevice.authorizationStatus(for: mediaType)
  } requestAuthorization: { mediaType in
    await AVCaptureDevice.requestAccess(for: mediaType)
  }
  
  /// A mock instance of the `CaptureAuthorization` object.
  ///
  /// This object returns a `.authorized` status and authorization request always succeeds.
  static let mockWithAuthorizedStatus = CaptureAuthorization { _ in
    .authorized
  } requestAuthorization: { _ in
    true
  }
  
  /// A mock instance of the `CaptureAuthorization` object.
  ///
  /// This object returns a `.restricted` status and authorization request always fails.
  static let mockWithRestrictedStatus = CaptureAuthorization { _ in
    .restricted
  } requestAuthorization: { _ in
    false
  }
  
  /// A mock instance of the `CaptureAuthorization` object.
  ///
  /// This object returns a `.notDetermined` status and authorization request always fails.
  static let mockWithNotDeterminedStatus = CaptureAuthorization { _ in
    .notDetermined
  } requestAuthorization: { _ in
    false
  }
  
  /// A mock instance of the `CaptureAuthorization` object.
  ///
  /// This object returns a `.denied` status and authorization request always fails.
  static let mockWithDeniedStatus = CaptureAuthorization { _ in
    .denied
  } requestAuthorization: { _ in
    false
  }
}
#endif
