import SwiftUI
import WidgetKit

@main
struct KelimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
        QuizWidget()
        ReviewRingWidget()
    }
}
