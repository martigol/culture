//
//  PreviewSupport.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI

extension View {
    /// Injects every app-wide dependency with sample data, for `#Preview`:
    /// router, library, highlights and site photos (seeded), location, mock services, dark scheme.
    @MainActor
    func previewEnvironment() -> some View {
        self
            .environment(Router())
            .environment(LibraryStore())
            .environment(HighlightStore.preview)
            .environment(PhotoStore.preview)
            .environment(LocationProvider())
            .environment(PermissionsCenter())
            .environment(NearbySiteAlerts())
            .environment(\.services, .mock)
            .preferredColorScheme(.dark)
    }
}
