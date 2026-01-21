//
//  SHManager.swift
//  NKRecipes
//
//  Created by Mihai Fratu on 26.11.2024.
//

import Foundation
import OSLog

private struct FailableDecodable<T: Decodable>: Decodable {
    
    let value: T?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
    
}

public struct SHList: Decodable, Identifiable {
    
    public let id: String
    public let ref: SHRef?
    public let items: [SHListItem]?
    
    enum CodingKeys: CodingKey {
        case id
        case ref
        case items
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.ref = try container.decodeIfPresent(SHRef.self, forKey: .ref)
        
        var decodedItems: [SHListItem] = []
        if var itemsContainer = try? container.nestedUnkeyedContainer(forKey: .items) {
            while !itemsContainer.isAtEnd {
                if let decodedItem = try itemsContainer.decode(FailableDecodable<SHListItem>.self).value {
                    decodedItems.append(decodedItem)
                }
            }
        }
        self.items = decodedItems.isEmpty ? nil : decodedItems
    }
    
}

public struct SHListCreatePayload: Encodable {
    
    public let ref: SHRef
    public let uniqueItems: Bool
    public let checkboxes: Bool
    public let quantities: Bool
    public var name: String
    
    public init(ref: SHRef, uniqueItems: Bool = true, checkboxes: Bool = false, quantities: Bool = false) {
        self.ref = ref
        self.name = ref.type.rawValue
        self.uniqueItems = uniqueItems
        self.checkboxes = checkboxes
        self.quantities = quantities
    }
    
}

public enum SHItemType: String, Codable {
    case recipe
    case ingredient
}

public struct SHListItem: Decodable, Identifiable {
    
    public let id: String
    public let ref: SHRef?
    public let type: SHItemType
    public let name: String
    public let url: URL?
    public let imageUrl: URL?
    public let checked: Bool?
    public let quantity: Double?
    public let attributes: [String: String]?
    
    public init(id: String, ref: SHRef?, type: SHItemType, name: String, url: URL?, imageUrl: URL?, checked: Bool? = nil, quantity: Double? = nil, attributes: [String : String]?) {
        self.id = id
        self.ref = ref
        self.type = type
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
        self.checked = checked
        self.quantity = quantity
        self.attributes = attributes
    }
    
}

public struct SHListItemCreatePayload: Encodable {
    
    public let ref: SHRef?
    public let type: SHItemType
    public let name: String
    public let url: URL?
    public let imageUrl: URL?
    public let checked: Bool?
    public let quantity: Double?
    public let attributes: [String: String]?
    
    public init(ref: SHRef?, type: SHItemType, name: String, url: URL?, imageUrl: URL?, checked: Bool? = nil, quantity: Double? = nil, attributes: [String : String]?) {
        self.ref = ref
        self.type = type
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
        self.checked = checked
        self.quantity = quantity
        self.attributes = attributes
    }
    
}

public struct SHListItemUpdatePayload: Encodable {
    
    public let id: String
    public let ref: SHRef?
    public let type: SHItemType
    public let name: String
    public let url: URL?
    public let imageUrl: URL?
    public let checked: Bool?
    public let quantity: Double?
    public let attributes: [String: String]?
    
    public init(id: String, ref: SHRef?, type: SHItemType, name: String, url: URL?, imageUrl: URL?, checked: Bool? = nil, quantity: Double? = nil, attributes: [String : String]?) {
        self.id = id
        self.ref = ref
        self.type = type
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
        self.checked = checked
        self.quantity = quantity
        self.attributes = attributes
    }
    
}

public enum SHRefType: String, Decodable {
    case list
    case recipe = "wprm_recipe"
    case weekmenu
    case shoppinglist
    case unkown
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = (try? container.decode(Self.self)) ?? .unkown
    }
    
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
        
        hostname = components[2]
        type = SHRefType(rawValue: components[3]) ?? .unkown
        id = components[4]
        suffix = components.count > 5 ? components[5] : nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
}

public struct SHRecipeMetadata: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case authority
        case title
        case metadata = "objects"
    }
    
    public let id: String
    public let url: URL
    public let authority: String
    public let title: String
    public let metadata: Metadata?
    
    public struct Metadata: Decodable {
        
        private struct Image: Decodable {
            let url: URL?
        }
        
        public struct Nutrition: Decodable {
            public let calories: String?
            public let carbohydrateContent: String?
            public let fatContent: String?
            public let fiberContent: String?
            public let proteinContent: String?
        }
        
        private enum ObjectCodingKeys: String, CodingKey {
            case type = "@type"
            case name
            case description
            case image
            case prepTime
            case cookTime
            case totalTime
            case recipeCategory
            case recipeCuisine
            case nutrition
        }
        
        public let name: String?
        public let description: String?
        public let image: URL?
        public let prepTime: String?
        public let cookTime: String?
        public let totalTime: String?
        public let recipeCategory: String?
        public let recipeCuisine: String?
        public let nutrition: Nutrition?
        
        public init(from decoder: any Decoder) throws {
            var arrayContainer = try decoder.unkeyedContainer()
            var metadata: Metadata? = nil
            
            while !arrayContainer.isAtEnd && metadata == nil {
                let objectContainer = try arrayContainer.nestedContainer(keyedBy: ObjectCodingKeys.self)
                
                // Make sure this is a recipe object
                guard let type = try? objectContainer.decodeIfPresent(String.self, forKey: .type),
                      type == "Recipe" else { continue }
                
                let name = try? objectContainer.decodeIfPresent(String.self, forKey: .name)
                let description = try? objectContainer.decodeIfPresent(String.self, forKey: .description)
                
                let image: URL? = {
                    if let image = try? objectContainer.decodeIfPresent(URL.self, forKey: .image) {
                        return image
                    }
                    else if let images = try? objectContainer.decodeIfPresent([URL].self, forKey: .image), let image = images.first {
                        return image
                    }
                    else if let image = try? objectContainer.decodeIfPresent(Image.self, forKey: .image) {
                        return image.url
                    }
                    return nil
                }()
                
                let prepTime = try? objectContainer.decodeIfPresent(String.self, forKey: .prepTime)
                let cookTime = try? objectContainer.decodeIfPresent(String.self, forKey: .cookTime)
                let totalTime = try? objectContainer.decodeIfPresent(String.self, forKey: .totalTime)
                
                let recipeCategory: String? = {
                    if let recipeCategory = try? objectContainer.decodeIfPresent(String.self, forKey: .recipeCategory) {
                        return recipeCategory
                    }
                    return (try? objectContainer.decodeIfPresent([String].self, forKey: .recipeCategory))?.joined(separator: ",")
                }()
                
                let recipeCuisine: String? = {
                    if let recipeCuisine = try? objectContainer.decodeIfPresent(String.self, forKey: .recipeCuisine) {
                        return recipeCuisine
                    }
                    return (try? objectContainer.decodeIfPresent([String].self, forKey: .recipeCuisine))?.joined(separator: ",")
                }()
                
                let nutrition = try? objectContainer.decodeIfPresent(Nutrition.self, forKey: .nutrition)
                
                metadata = .init(name: name,
                                 description: description,
                                 image: image,
                                 prepTime: prepTime,
                                 cookTime: cookTime,
                                 totalTime: totalTime,
                                 recipeCategory: recipeCategory,
                                 recipeCuisine: recipeCuisine,
                                 nutrition: nutrition)
            }
            
            guard let metadata else {
                throw DecodingError.valueNotFound(Metadata.self, .init(codingPath: decoder.codingPath, debugDescription: "Could not find or decode object with type Recipe"))
            }
            
            self = metadata
        }
        
        private init(name: String?, description: String?, image: URL?, prepTime: String?, cookTime: String?, totalTime: String?, recipeCategory: String?, recipeCuisine: String?, nutrition: Nutrition?) {
            self.name = name
            self.description = description
            self.image = image
            self.prepTime = prepTime
            self.cookTime = cookTime
            self.totalTime = totalTime
            self.recipeCategory = recipeCategory
            self.recipeCuisine = recipeCuisine
            self.nutrition = nutrition
        }
        
    }
    
}

public actor SHManager: ObservableObject {
    
    public static let shared = SHManager()
    
    @MainActor public static func shared(with configuration: SHManagerConfiguration) -> SHManager {
        shared.configure(configuration: configuration)
        return shared
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
    
    @MainActor public func configure(configuration: SHManagerConfiguration) {
        SHSessionManager.shared.configure(configuration: configuration)
    }
    
    public func getLists() async throws -> [SHList] {
        guard let currentUserId = SHSessionManager.shared.currentUserId else {
            throw SHManager.Error.notAuthorized
        }
        let listsWrappers: [FailableDecodable<SHList>] = try await getData(at: "lists", queryItems: [.init(name: "userId", value: currentUserId)])
        return listsWrappers.compactMap { $0.value }
    }
    
    public func getList(listId: SHList.ID) async throws -> SHList {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        return try await getData(at: "lists/\(listId)")
    }
    
    public func createList(ref: SHRef, withUniqueItems uniqueItems: Bool = true, checkboxes: Bool = false, quantities: Bool = false) async throws -> SHList.ID {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        struct CreateListResult: Decodable { let id: SHList.ID }
        let result: CreateListResult = try await getData(at: "lists", httpMethod: "POST", payload: SHListCreatePayload(ref: ref, uniqueItems: uniqueItems, checkboxes: checkboxes, quantities: quantities))
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
    
    public func update(item: SHListItemUpdatePayload, in listId: SHList.ID) async throws {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        try await getData(at: "lists/\(listId)/items/\(item.id)", httpMethod: "PUT", payload: item)
    }
    
    public func remove(itemId: SHListItem.ID, from listId: SHList.ID) async throws {
        guard SHSessionManager.shared.isLoggedIn else {
            throw SHManager.Error.notAuthorized
        }
        try await getData(at: "lists/\(listId)/items/\(itemId)", httpMethod: "DELETE")
    }
    
    public func getRecipeMetadata(for url: URL) async throws -> SHRecipeMetadata? {
        try await getData(at: "metadata", queryItems: [.init(name: "url", value: url.absoluteString)])
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
