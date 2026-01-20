//
//  SpeakerAPI.swift
//  taika
//
//  created by product on 13.01.2026.
//

import Foundation

// MARK: - public models

enum SpeakerAPIError: Error, LocalizedError {
    case notConfigured
    case invalidRequest
    case badResponse
    case http(Int)
    case decode

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "speaker api is not configured"
        case .invalidRequest: return "invalid request"
        case .badResponse: return "bad response"
        case .http(let code): return "http error \(code)"
        case .decode: return "decode error"
        }
    }
}

/// minimal issue item for ui mapping (mvp)
struct SpeakerIssue: Identifiable, Hashable {
    let id: String
    let kind: Kind
    let message: String

    enum Kind: String, Hashable {
        case tone
        case vowel
        case consonant
        case timing
        case stress
        case unknown
    }
}

/// normalized result that speaker manager/ds can consume regardless of provider
struct SpeakerAssessmentResult: Hashable {
    /// 0…100
    let score: Double

    /// what stt heard (thai, if provider returns it)
    let heardThai: String?

    /// what stt heard as translit (optional, provider-specific)
    let heardTranslit: String?

    /// short teacher-style feedback lines (already curated)
    let feedback: [String]

    /// structured issues for later: highlights, chips, etc.
    let issues: [SpeakerIssue]
}

// MARK: - provider contract

protocol SpeakerAssessmentProviding {
    /// assess a recorded attempt against an expected thai text.
    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult
}

// MARK: - api entry

/// single entry point for speaker integrations.
///
/// current mvp: provider is optional. if not configured, it throws `notConfigured`.
final class SpeakerAPI {
    static let shared = SpeakerAPI()

    private var provider: SpeakerAssessmentProviding?

    private init() {}

    func configure(provider: SpeakerAssessmentProviding) {
        self.provider = provider
    }

    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult {
        guard let provider else { throw SpeakerAPIError.notConfigured }
        let trimmed = expectedThai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpeakerAPIError.invalidRequest }
        return try await provider.assess(audioURL: audioURL, expectedThai: trimmed)
    }
}

// MARK: - azure skeleton (not wired)

/// azure pronunciation assessment provider skeleton.
///
/// note: keys/endpoints are intentionally not embedded in code.
/// you will configure it from app config.
final class AzurePronunciationAssessor: SpeakerAssessmentProviding {
    struct Config {
        let endpoint: URL
        let subscriptionKey: String
        /// e.g. "th-TH"
        let locale: String

        init(endpoint: URL, subscriptionKey: String, locale: String = "th-TH") {
            self.endpoint = endpoint
            self.subscriptionKey = subscriptionKey
            self.locale = locale
        }
    }

    private let config: Config
    private let session: URLSession

    init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult {
        // mvp: request/response mapping will be implemented once endpoint + contract are confirmed.
        // keep compile-safe: perform a minimal guard and throw until wired.
        _ = audioURL
        _ = expectedThai

        // once wired, return a fully populated result.
        throw SpeakerAPIError.notConfigured
    }
}
