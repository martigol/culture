//
//  ScopedSearch.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

extension View {
    /// Search limited to the current screen (Home, Stories, Library…). A
    /// magnifier in the navigation bar reveals a standard search field and
    /// focuses it; Cancel hides it again and clears the query. The Search tab
    /// is the app-wide search; this one only filters what's here.
    func scopedSearch(text: Binding<String>, prompt: String) -> some View {
        modifier(ScopedSearch(text: text, prompt: prompt))
    }
}

private struct ScopedSearch: ViewModifier {
    @Binding var text: String
    let prompt: String
    /// The field is in the navigation bar.
    @State private var isShown = false
    /// The field is focused (driven by `searchable`, e.g. Cancel sets it false).
    @State private var isPresented = false

    func body(content: Content) -> some View {
        if isShown {
            content
                .searchable(text: $text, isPresented: $isPresented,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text(prompt))
                .task {
                    // Focus once the field has been added to the bar.
                    try? await Task.sleep(for: .milliseconds(150))
                    isPresented = true
                }
                .onChange(of: isPresented) { _, presented in
                    guard !presented else { return }
                    text = ""
                    withAnimation(Motion.smooth) { isShown = false }
                }
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { withAnimation(Motion.smooth) { isShown = true } } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel(prompt)
                    }
                }
        }
    }
}
