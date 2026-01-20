//
//  taikafmData.swift
//  taika
//
//  Created by product on 01.12.2025.
//

//
//  taikafmData.swift
//  taika
//
//  Created by product on 01.12.2025.
//

import Foundation

// единый скоуп для всех экранов, где есть таика fm
public enum TaikaFMScope: String, CaseIterable, Codable {
    case main
    case course
    case lessons
    case step
    case fav
}

// конфиг для одного скоупа в taikafm.json
public struct TaikaFMScopeConfig: Decodable {
    public let messages: [String]
    public let reactions: [String]
}

// корневой json taikafm.json
private struct TaikaFMRootConfig: Decodable {
    let version: Int
    let main: TaikaFMScopeConfig
    let course: TaikaFMScopeConfig
    let lessons: TaikaFMScopeConfig
    let step: TaikaFMScopeConfig
    let fav: TaikaFMScopeConfig

    func config(for scope: TaikaFMScope) -> TaikaFMScopeConfig {
        switch scope {
        case .main:    return main
        case .course:  return course
        case .lessons: return lessons
        case .step:    return step
        case .fav:     return fav
        }
    }
}

/// один фрагмент текста Таика FM с пометкой, акцентный он или нет
public struct TaikaFMChunk: Equatable {
    public let text: String
    public let isAccent: Bool
}

/// единая точка доступа к taikafm.json
public final class TaikaFMData {
    public static let shared = TaikaFMData()

    private let root: TaikaFMRootConfig?

    private init() {
        if
            let url = Bundle.main.url(forResource: "taikafm", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(TaikaFMRootConfig.self, from: data)
        {
            self.root = decoded
        } else {
            self.root = nil
            #if DEBUG
            print("[TaikaFMData] failed to load taikafm.json")
            #endif
        }
    }

    /// сообщения для конкретного экрана (main / course / lessons / step / fav)
    public func messages(for scope: TaikaFMScope) -> [String] {
        root?.config(for: scope).messages ?? []
    }

    /// реакции для конкретного экрана в виде маленьких групп по одному эмодзи,
    /// чтобы удобно отдавать их в бабл
    public func reactionGroups(for scope: TaikaFMScope) -> [[String]] {
        guard let flat = root?.config(for: scope).reactions, !flat.isEmpty else { return [] }
        return flat.map { [$0] }
    }

    /// сообщения для конкретного экрана в виде акцентных чанков,
    /// где фрагменты в [[двойных скобках]] помечены как isAccent = true
    public func accentMessages(for scope: TaikaFMScope) -> [[TaikaFMChunk]] {
        messages(for: scope).map { Self.parseAccentChunks($0) }
    }

    /// специальный helper для step‑экрана:
    /// берём tip из steps.json и превращаем его в один "сообщение" Таика FM
    /// если tip пустой или nil — возвращаем [], чтобы DS мог показать только "печатает..." без текста
    public func accentMessagesFromStepTip(_ tip: String?) -> [[TaikaFMChunk]] {
        guard let raw = tip?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return []
        }
        return [Self.parseAccentChunks(raw)]
    }

    // MARK: - Accent Parsing

    /// простой парсер для [[accent]]-синтаксиса, как в LessonsDS.accentText(_:)
    private static func parseAccentChunks(_ raw: String) -> [TaikaFMChunk] {
        var result: [TaikaFMChunk] = []
        var buffer = ""
        var isAccent = false

        var index = raw.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            result.append(TaikaFMChunk(text: buffer, isAccent: isAccent))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < raw.endIndex {
            // начало акцентного сегмента [[
            if raw[index...].hasPrefix("[[") {
                flushBuffer()
                isAccent = true
                index = raw.index(index, offsetBy: 2)
                continue
            }

            // конец акцентного сегмента ]]
            if raw[index...].hasPrefix("]]") {
                flushBuffer()
                isAccent = false
                index = raw.index(index, offsetBy: 2)
                continue
            }

            buffer.append(raw[index])
            index = raw.index(after: index)
        }

        flushBuffer()
        return result
    }
}
