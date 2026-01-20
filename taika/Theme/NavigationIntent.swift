//
//  NavigationIntent.swift
//  taika
//
//  Created by product on 15.12.2025.
//

import Foundation
import SwiftUI

/// a tiny, app-wide navigation signal.
///
/// goal: views/managers can *request* navigation without directly owning navigation state.
/// actual navigation is performed by the root view that observes `route`.
@MainActor
public final class NavigationIntent: ObservableObject {

    public enum Route: Hashable {
        // course list / lessons list screen for a course
        case lessons(courseId: String)

        // open a specific lesson inside a course
        case lesson(courseId: String, lessonId: String)
        // MARK: - legacy aliases (keep call-sites compiling)

        @available(*, deprecated, message: "use .lessons(courseId:) instead")
        public static func steps(courseId: String) -> Route {
            .lessons(courseId: courseId)
        }

        @available(*, deprecated, message: "use .lesson(courseId:lessonId:) instead")
        public static func step(courseId: String, lessonId: String) -> Route {
            .lesson(courseId: courseId, lessonId: lessonId)
        }
        // optional: open the course screen itself
        case course(courseId: String)
    }

    @Published public var path: [Route] = []

    public init() {}

    public func go(_ route: Route) {
        // important: keep `path` elements homogeneous (Route only)
        path.append(route)
    }

    /// replace the whole stack with a single route (useful to avoid multiple updates per frame)
    public func set(_ route: Route) {
        path = [route]
    }

    /// convenience for returning to root without touching other state
    public func popToRoot() {
        path.removeAll(keepingCapacity: true)
    }

    public func reset() {
        path.removeAll()
    }
}
