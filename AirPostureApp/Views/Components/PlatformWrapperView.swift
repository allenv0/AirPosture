import SwiftUI

struct PlatformWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        #else
        content
        #endif
    }
}
