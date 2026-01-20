//
//  HomeTaskData.swift
//  taika
//
//  Created by product on 03.09.2025.
//
import Foundation

public enum HTaskStatus: String, Codable, Equatable {
    case locked
    case available
    case inProgress
    case done
}

public struct HTask: Identifiable, Codable, Equatable {
    public var id: String
    public var courseId: String
    public var lessonIndex: Int
    public var title: String
    public var details: String
    public var status: HTaskStatus
    public var updatedAt: Date

    public init(id: String = UUID().uuidString,
                courseId: String,
                lessonIndex: Int,
                title: String,
                details: String = "",
                status: HTaskStatus,
                updatedAt: Date = .init()) {
        self.id = id
        self.courseId = courseId
        self.lessonIndex = lessonIndex
        self.title = title
        self.details = details
        self.status = status
        self.updatedAt = updatedAt
    }
}

public struct HTaskProgress: Equatable {
    public var done: Int
    public var total: Int
    public var available: Int { min(done, total) }
}
