//
//  CameraPreview.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import AVFoundation
import SwiftUI
import UIKit

/// Live camera feed (`AVCaptureVideoPreviewLayer`), aspect-filled edge to edge.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session { uiView.previewLayer.session = session }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

#Preview {
    // The canvas has no camera: this shows the black placeholder the feed draws into.
    CameraPreview(session: AVCaptureSession())
        .ignoresSafeArea()
}
