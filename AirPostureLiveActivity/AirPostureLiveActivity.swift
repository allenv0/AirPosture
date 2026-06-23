import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AirPostureLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        AirPostureLiveActivityWidget()
    }
}

struct AirPostureLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AirPostureActivityAttributes.self) { context in
            LiveActivityLockScreenView(snapshot: LiveActivitySnapshot(context: context))
        } dynamicIsland: { context in
            let snapshot = LiveActivitySnapshot(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AvatarCircleExpanded(snapshot: snapshot, size: 64)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ScoreCircleExpanded(snapshot: snapshot, size: 64)
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(snapshot: snapshot)
                }
            } compactLeading: {
                CompactLeadingView(snapshot: snapshot)
            } compactTrailing: {
                CompactTrailingView(snapshot: snapshot)
            } minimal: {
                MinimalStatusView(snapshot: snapshot)
            }
        }
    }
}

#if DEBUG
struct AirPostureLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Lock Screen Previews
            LiveActivityLockScreenView(snapshot: .alignedPreview)
                .previewDisplayName("Lock Screen / Good")
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            LiveActivityLockScreenView(snapshot: .correctingPreview)
                .previewDisplayName("Lock Screen / Correcting")
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            LiveActivityLockScreenView(snapshot: .pausedPreview)
                .previewDisplayName("Lock Screen / Paused")
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            LiveActivityLockScreenView(snapshot: .monitoringPreview)
                .previewDisplayName("Lock Screen / Calibrating")
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            LiveActivityLockScreenView(snapshot: .missingAvatarPreview)
                .previewDisplayName("Lock Screen / Missing Avatar")
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            // Dynamic Island Expanded
            ExpandedCenterView(snapshot: .alignedPreview)
                .padding()
                .background(Color.liveCoal)
                .previewDisplayName("Island / Good")
                .previewContext(WidgetPreviewContext(family: .accessoryInline))

            ExpandedCenterView(snapshot: .tiltingPreview)
                .padding()
                .background(Color.liveCoal)
                .previewDisplayName("Island / Correcting")
                .previewContext(WidgetPreviewContext(family: .accessoryInline))

            ExpandedBottomView(snapshot: .alignedPreview)
                .padding()
                .background(Color.liveCoal)
                .previewDisplayName("Island Bottom / Good")

            ExpandedBottomView(snapshot: .tiltingPreview)
                .padding()
                .background(Color.liveCoal)
                .previewDisplayName("Island Bottom / Correcting")

            // Compact Views
            HStack(spacing: 16) {
                CompactLeadingView(snapshot: .alignedPreview)
                CompactTrailingView(snapshot: .alignedPreview)
                MinimalStatusView(snapshot: .monitoringPreview)
            }
            .padding()
            .background(Color.liveCoal)
            .previewDisplayName("Compact + Minimal")
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        }
    }
}
#endif
