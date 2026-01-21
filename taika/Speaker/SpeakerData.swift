//
//  SpeakerData.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import Foundation

// MARK: - B3: Persistence models for speaker attempts

/// Stored result of a speaker attempt for a specific step
struct SpeakerAttemptResult: Codable, Equatable {
    let courseId: String
    let lessonId: String
    let stepIndex: Int
    
    let heardThai: String?
    let heardTranslit: String?
    let heardConfidence: Int
    let attemptCount: Int
    let lastAttemptURL: String? // stored as path string
    
    let timestamp: Date
}

/// Storage key for UserDefaults
private let speakerAttemptsStoreKey = "SpeakerManager.attempts.v1"

/// B3: Persistence helper for speaker attempts
struct SpeakerAttemptsStore {
    static func save(attempt: SpeakerAttemptResult, forKey key: String) {
        var all = loadAll()
        all[key] = attempt
        saveAll(all)
    }
    
    static func load(forKey key: String) -> SpeakerAttemptResult? {
        return loadAll()[key]
    }
    
    static func loadAll() -> [String: SpeakerAttemptResult] {
        guard let data = UserDefaults.standard.data(forKey: speakerAttemptsStoreKey) else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: SpeakerAttemptResult].self, from: data)
        } catch {
            return [:]
        }
    }
    
    static func saveAll(_ attempts: [String: SpeakerAttemptResult]) {
        do {
            let data = try JSONEncoder().encode(attempts)
            UserDefaults.standard.set(data, forKey: speakerAttemptsStoreKey)
        } catch {
            // silent fail in production
        }
    }
    
    /// Generate storage key for a step
    static func key(courseId: String, lessonId: String, stepIndex: Int) -> String {
        return "\(courseId)|\(lessonId)|\(stepIndex)"
    }
}