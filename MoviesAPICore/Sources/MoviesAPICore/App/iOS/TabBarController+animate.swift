//
//  TabBarController+animate.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/20/26.
//

#if os(iOS)
import UIKit
import ObjectiveC.runtime

@MainActor
@discardableResult
func tryAnimateTabs(on controller: UITabBarController) -> Bool {

    for view in controller.tabBar.subviews {
        animateSelectedContent(in: view)
        print("View:", type(of: view))
        print("Subviews:", view.subviews)
    }
    return true
}

private func animateSelectedContent(in view: UIView) {
    if String(describing: type(of: view))
        .contains("SelectedContentView") {

        let originalTransform = view.transform

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            view.transform = originalTransform.scaledBy(x: 0.5, y: 0.5)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                view.transform = originalTransform
            }
        }
    }

    for subview in view.subviews {
        animateSelectedContent(in: subview)
    }
}
#endif
