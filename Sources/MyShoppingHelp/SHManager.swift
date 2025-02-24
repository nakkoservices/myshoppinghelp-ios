//
//  SHManager.swift
//  NKRecipes
//
//  Created by Mihai Fratu on 26.11.2024.
//

import Foundation
import OSLog

public struct SHList: Decodable, Identifiable {
    
    public let id: String
    public let ref: SHRef?
    public let items: [SHListItem]?
    
}

public struct SHListCreatePayload: Encodable {
    
    public let ref: SHRef
    
    public init(ref: SHRef) {
        self.ref = ref
    }
    
}

public enum SHItemType: String, Codable {
    case recipe
}

public struct SHListItem: Decodable, Identifiable {
    
    public let id: String
    public let ref: SHRef?
    public let type: SHItemType
    public let name: String
    public let url: URL?
    public let imageUrl: URL?
    public let attributes: [String: String]?
    
    public init(id: String, ref: SHRef?, type: SHItemType, name: String, url: URL?, imageUrl: URL?, attributes: [String : String]?) {
        self.id = id
        self.ref = ref
        self.type = type
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
        self.attributes = attributes
    }
    
}

public struct SHListItemCreatePayload: Encodable {
    
    public let ref: SHRef
    public let type: SHItemType
    public let name: String
    public let url: URL?
    public let imageUrl: URL?
    public let attributes: [String: String]?
    
    public init(ref: SHRef, type: SHItemType, name: String, url: URL?, imageUrl: URL?, attributes: [String : String]?) {
        self.ref = ref
        self.type = type
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
        self.attributes = attributes
    }
    
}

public enum SHRefType: String, Decodable {
    case list
    case weekmenu
    case recipe = "wprm_recipe"
}

public struct SHRef: Codable, Hashable {
    
    private let value: String
    public let hostname: String
    public let type: SHRefType
    public let id: String
    public let suffix: String?
    
    public init(hostname: String? = nil, type: SHRefType, id: String = "default", suffix: String? = nil) {
        self.hostname = hostname ?? ""
        self.type = type
        self.id = id
        self.suffix = suffix
        
        if let suffix = self.suffix {
            self.value = "nrn:msh:\(self.hostname):\(self.type.rawValue):\(self.id):\(suffix)"
        }
        else {
            self.value = "nrn:msh:\(self.hostname):\(self.type.rawValue):\(self.id)"
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(String.self)
        let components = value.split(separator: ":", omittingEmptySubsequences: false).map { String($0) }
        
        // Make sure the ref is in the correct format: "nrn:msh:{hostname}:{type}:{id}:{optional-suffix}"
        guard (5...6).contains(components.count), components[0] == "nrn", components[1] == "msh" else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid SHRef format: \(value).")
        }
        
        guard let refType = SHRefType(rawValue: components[3]) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid SHRefType value: \(components[3]).")
        }
        
        hostname = components[2]
        type = refType
        id = components[4]
        suffix = components.count > 5 ? components[5] : nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
}

@MainActor public class SHManager: ObservableObject {
    
    public static func shared(with configuration: SHManagerConfiguration) -> SHManager {
        .init(configuration: configuration)
    }
    
    #if DEBUG
    private var bundleId: String = "com.nakko.shoppinghelp"
    private lazy var logger: Logger = .init(subsystem: bundleId, category: "SHManager")
    private lazy var logQueue: DispatchQueue = .init(label: bundleId, qos: .background)
    private lazy var logFileDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("logs")
    private lazy var logFileURL: URL = logFileDirectory.appendingPathComponent("data").appendingPathExtension("log")
    private var currentLogs: String? {
        guard let logData = try? Data(contentsOf: logFileURL) else { return nil }
        return String(data: logData, encoding: .utf8)
    }
    #endif
    
    private init(configuration: SHManagerConfiguration) {
        SHSessionManager.shared.configure(configuration: configuration)
    }
    
    public func getLists() async throws -> [SHList] {
        guard let currentUserId = SHSessionManager.shared.currentUserId else {
            throw SHManager.Error.notAuthorized
        }
        return try await getData(at: "lists", queryItems: [.init(name: "userId", value: currentUserId)])
    }
    
    public func getList(listId: SHList.ID) async throws -> SHList {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        return try await getData(at: "lists/\(listId)")
    }
    
    public func createList(ref: SHRef) async throws -> SHList.ID {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        struct CreateListResult: Decodable { let id: SHList.ID }
        let result: CreateListResult = try await getData(at: "lists", httpMethod: "POST", payload: SHListCreatePayload(ref: ref))
        return result.id
    }
    
    public func deleteList(listId: SHList.ID) async throws {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        try await getData(at: "lists/\(listId)", httpMethod: "DELETE")
    }
    
    public func add(item: SHListItemCreatePayload, to listId: SHList.ID) async throws {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        try await getData(at: "lists/\(listId)/items", httpMethod: "POST", payload: item)
    }
    
    public func remove(itemId: SHListItem.ID, from listId: SHList.ID) async throws {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        try await getData(at: "lists/\(listId)/items/\(itemId)", httpMethod: "DELETE")
    }
    
    private func getData<T: Decodable>(at path: String, queryItems: [URLQueryItem] = [], httpMethod: String = "GET", payload: (any Encodable)? = nil) async throws -> T {
        let (data, request) = try await getData(at: path, queryItems: queryItems, httpMethod: httpMethod, payload: payload)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            var debugString = "Cannot parse data for \(request.url?.absoluteString ?? "n\\a"). Reason:\n\n";
            debugString += "\(error)"
            // Log to console
            log(string: debugString, logType: .error)
            #endif
            throw error
        }
    }
    
    @discardableResult
    private func getData(at path: String, queryItems: [URLQueryItem] = [], httpMethod: String = "GET", payload: (any Encodable)? = nil) async throws -> (Data, URLRequest) {
        let accessToken: String = try await withCheckedThrowingContinuation { continuation in
            SHSessionManager.shared.currentSession?.performAction(freshTokens: { accessToken, refreshToken, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let accessToken else {
                    continuation.resume(throwing: SHManager.Error.notAuthorized)
                    return
                }
                
                continuation.resume(returning: accessToken)
            })
        }
        
        var urlComponents = URLComponents(string: "https://api.myshopping.help/v1/\(path)")
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            throw SHManager.Error.unkownError
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = httpMethod
        
        if let payload {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
        }
        
        #if DEBUG
            let startDate = Date()
            var debugString = "\n\n--- \(startDate)"
            debugString += "\nGetting data:\n"
            debugString += request.curlDebugString
            log(string: debugString, logType: .default)
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
            let endDate = Date()
            debugString = "--- \(endDate) | Total time: \(endDate.timeIntervalSince(startDate))"
            debugString += "\nGot data for: \(request.httpMethod!) - \(request.url?.absoluteString ?? "-")"
            guard let httpResponse = response as? HTTPURLResponse else {
                debugString += "\nCODE: n\\a - timeout ?!?"
                log(string: debugString, logType: .error)
                throw SHManager.Error.unkownError
            }
            debugString += "\nCODE: \(httpResponse.statusCode)"
            debugString += "\nHEADERS: \(httpResponse.allHeaderFields)"
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                debugString += "\nDATA: \(String(data: try! JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted), encoding: .utf8)!)"
            }
            else {
                debugString += "\nDATA: \(String(data: data, encoding: .utf8) ?? "n\\a")"
            }
            log(string: debugString, logType: .default)
        #endif
        
        return (data, request)
    }
    
    private func log(string: String, logType: OSLogType = .default) {
        #if DEBUG
        logger.log(level: logType, "\(string)")
        logQueue.sync {
            if !FileManager.default.fileExists(atPath: logFileDirectory.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: logFileDirectory, withIntermediateDirectories: true)
            }
            
            let letFinalLogString = (currentLogs ?? "") + "\n" + string
            do {
                try letFinalLogString.write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                logger.log(level: .error, "Failed to log: \(error)")
            }
        }
        #endif
    }
    
}

public extension SHManager {
    
    enum Error: Swift.Error {
        case notAuthorized
        case unkownError
    }
    
}

#if DEBUG

fileprivate extension URLRequest {
    
    var curlDebugString: String {
        guard let url = url else { return "" }
        var baseCommand = #"curl "\#(url.absoluteString)""#
        
        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }
        
        var command = [baseCommand]
        
        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }
        
        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body.replacingOccurrences(of: "'", with: "'\\''"))'")
        }
        
        return command.joined(separator: " \\\n\t")
    }
    
}

#endif
