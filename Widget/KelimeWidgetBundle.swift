import SwiftUI
import WidgetKit

@main
struct KelimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
        QuizWidget()
        ReviewRingWidget()
        if #available(iOS 18.0, *) {
            QuickReviewControl()
            CurrentWordControl()
        }
    }
}
