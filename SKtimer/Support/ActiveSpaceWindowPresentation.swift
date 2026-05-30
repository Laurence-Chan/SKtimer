import AppKit

extension NSWindow {
    func configureForActiveSpacePresentation(includeFullScreenAuxiliary: Bool = false) {
        collectionBehavior.insert(.moveToActiveSpace)

        if includeFullScreenAuxiliary {
            collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }

    func presentOnActiveSpace(includeFullScreenAuxiliary: Bool = false) {
        configureForActiveSpacePresentation(includeFullScreenAuxiliary: includeFullScreenAuxiliary)

        if isMiniaturized {
            deminiaturize(nil)
        }

        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        orderFrontRegardless()
    }
}
