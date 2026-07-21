import Foundation
import Testing
@testable import NoType

@MainActor
@Suite("PreviewWindowController")
struct PreviewWindowControllerTests {

    @Test func confirmWithoutEditReturnsProcessedText() {
        let preview = PreviewWindowController()
        var confirmed: String?
        preview.onConfirm = { confirmed = $0 }

        preview.present(text: "Hello world", modeName: "Everyday polish")
        preview.confirm()

        #expect(preview.hasResolved == true)
        #expect(preview.resolvedText == "Hello world")
        #expect(confirmed == "Hello world")
    }

    @Test func confirmAfterEditReturnsEditedText() {
        let preview = PreviewWindowController()
        var confirmed: String?
        preview.onConfirm = { confirmed = $0 }

        preview.present(text: "Hello world", modeName: nil)
        preview.setText("Hello edited world")
        preview.confirm()

        #expect(preview.resolvedText == "Hello edited world")
        #expect(confirmed == "Hello edited world")
    }

    @Test func cancelDeliversNothingAndResolvesToNil() {
        let preview = PreviewWindowController()
        var cancelled = false
        var confirmed: String?
        preview.onCancel = { cancelled = true }
        preview.onConfirm = { confirmed = $0 }

        preview.present(text: "discard me", modeName: nil)
        preview.cancel()

        #expect(preview.hasResolved == true)
        #expect(preview.resolvedText == nil)
        #expect(cancelled == true)
        #expect(confirmed == nil)
    }

    @Test func secondConfirmIsIgnored() {
        let preview = PreviewWindowController()
        var confirmCount = 0
        preview.onConfirm = { _ in confirmCount += 1 }

        preview.present(text: "once", modeName: nil)
        preview.confirm()
        preview.confirm() // already resolved

        #expect(confirmCount == 1)
    }

    @Test func presentResolvesPriorState() {
        let preview = PreviewWindowController()
        preview.present(text: "first", modeName: nil)
        preview.confirm()
        #expect(preview.hasResolved == true)

        // A new presentation resets the resolved state.
        preview.present(text: "second", modeName: nil)
        #expect(preview.hasResolved == false)
        #expect(preview.currentText == "second")
    }
}
