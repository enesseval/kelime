import KelimeCore
import WidgetKit

/// The widget timeline entry is the shared snapshot itself, so the app and the extension
/// can never disagree on its shape.
extension WidgetSnapshot: TimelineEntry {}
