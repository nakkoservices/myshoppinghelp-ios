//
//  SHManager.swift
//  NKRecipes
//
//  Created by Mihai Fratu on 02.12.2024.
//

public struct SHManagerConfiguration {
    
    public let clientId: String
    public let appGroupId: String?
    public let redirectUrlProtocol: String?
    
    public init(clientId: String, appGroupId: String? = nil, redirectUrlProtocol: String? = nil) {
        self.clientId = clientId
        self.appGroupId = appGroupId
        self.redirectUrlProtocol = redirectUrlProtocol
    }
    
}
