//
//  SHManager.swift
//  NKRecipes
//
//  Created by Mihai Fratu on 02.12.2024.
//

import Foundation

public struct SHManagerConfiguration {
    
    public let clientId: String
    public let bundleId: String
    public let appGroupId: String?
    public let redirectUrlProtocol: String
    public let redirectUrlPath: String
    
    public init(clientId: String, bundleId: String? = nil, appGroupId: String? = nil, redirectUrlProtocol: String, redirectUrlPath: String?) {
        self.clientId = clientId
        self.bundleId = bundleId ?? Bundle.main.bundleIdentifier!
        self.appGroupId = appGroupId
        self.redirectUrlProtocol = redirectUrlProtocol
        self.redirectUrlPath = redirectUrlPath ?? "msh/callback"
    }
    
}
