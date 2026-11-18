#if os(iOS)

import UIKit
import ObjectiveC.runtime

/// Attempts to raise the native tab limit using an undocumented UIKit selector.
/// Selector availability does not guarantee that the current layout supports six tabs.
@MainActor
@discardableResult
func tryAllowingSixTabs(on controller: UITabBarController) -> Bool {
    let selector = NSSelectorFromString("_setMaximumNumberOfItems:")

    guard controller.responds(to: selector),
          let method = class_getInstanceMethod(type(of: controller), selector)
    else {
        return false
    }

    // This selector takes an unsigned integer, rather than an NSNumber object.
    typealias Setter = @convention(c) (AnyObject, Selector, UInt) -> Void
    let setter = unsafeBitCast(method_getImplementation(method), to: Setter.self)
    setter(controller, selector, 6)
    return true
}

#endif
