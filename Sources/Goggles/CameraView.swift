//
// Goggles
//
// Copyright © 2023 Gaetano Matonti. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI

public struct CameraView: View {
  
  // MARK: - Stored Properties
  
  @State private var image: Image?
  
  /// The object that manages connection to the device camera and outputs a stream of images.
  private let camera: Camera
  
  // MARK: - Init
  
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
      camera.startSession()
    }
    .onDisappear {
      camera.stopSession()
    }
  }
}

// MARK: - Preview

#Preview {
  CameraView()
}
#endif
