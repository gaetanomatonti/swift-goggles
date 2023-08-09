//
// Goggles
//
// Copyright © 2023 Gaetano Matonti. All rights reserved.
//

import SwiftUI

/// A view that displays the frames of a video stream.
public struct CameraView: View {
  
  // MARK: - Stored Properties
  
  /// The current video frame.
  @State private var image: Image?
  
  /// The object that manages connection to the device camera and outputs a stream of images.
  private let camera: Camera
  
  // MARK: - Init
  
  /// Creates a view that displays a video stream.
  /// - Parameter camera: The object that manages connection to the device camera and outputs a stream of images.
  ///                     Defaults to an instance that only streams video frames.
  public init(camera: Camera = Camera()) {
    self.camera = camera
  }
  
  // MARK: - Body
  
  public var body: some View {
    GeometryReader { geometry in
      if let image = image {
        image
          .resizable()
          .scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
    .ignoresSafeArea()
    .task {
      for await image in camera.stream {
        self.image = image
      }
    }
    .onAppear {
      camera.startCapture()
    }
    .onDisappear {
      camera.stopCapture()
    }
  }
}

// MARK: - Preview

#Preview {
  CameraView()
}
