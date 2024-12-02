//
//  SHSessionManager.swift
//  NKRecipes
//
//  Created by Mihai Fratu on 25.11.2024.
//

import Foundation
import AppAuth
import JWTDecode
import KeychainSwift

@MainActor public class SHSessionManager: ObservableObject {
    
    public static let shared = SHSessionManager()
    
    private var configuration: SHManagerConfiguration? = nil
    
    private lazy var keychain: KeychainSwift = {
        let keychain = KeychainSwift()
        keychain.accessGroup = configuration?.appGroupId
        return keychain
    }()
    
    @Published public private(set) var currentSession: OIDAuthState? = nil {
        didSet {
            if let currentSession {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: currentSession, requiringSecureCoding: false)
                    keychain.set(data.base64EncodedString(), forKey: "ShoppingHelpSession")
                } catch {
                    print("Could not save session. Reason: \(error.localizedDescription)")
                }
            }
            else {
                keychain.delete("ShoppingHelpSession")
            }
            
            if oldValue == nil, currentSession != nil {
                NotificationCenter.default.post(name: SHSessionManager.sessionDidChange, object: self)
            }
            else if oldValue != nil, currentSession == nil {
                NotificationCenter.default.post(name: SHSessionManager.sessionDidChange, object: self)
            }
        }
    }
    
    @Published public private(set) var isBusy: Bool = false
    
    private(set) var currentAuthorizationFlow: OIDExternalUserAgentSession? = nil
    
    public var isLoggedIn: Bool {
        currentSession?.isAuthorized ?? false
    }
    
    public var currentToken: String? {
        currentSession?.lastTokenResponse?.accessToken
    }
    
    public var currentUserId: String? {
        guard let currentToken else { return nil }
        return try? decode(jwt: currentToken).subject
    }
    
    private init() { }
    
    func configure(configuration: SHManagerConfiguration) {
        self.configuration = configuration
        
        do {
            if let sessionString = keychain.get("ShoppingHelpSession"),
               let sessionData = Data(base64Encoded: sessionString),
               let session = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [OIDAuthState.self], from: sessionData) as? OIDAuthState {
                self.currentSession = session
            }
            else {
                self.currentSession = nil
            }
        } catch {
            print("Could not resume SH session. Reason: \(error.localizedDescription)")
            NotificationCenter.default.post(name: SHSessionManager.sessionDidChange, object: self)
            self.currentSession = nil
        }
    }
    
    private func setIsBusy(_ isBusy: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setIsBusy(isBusy)
            }
            return
        }
        self.isBusy = isBusy
    }
    
    public func tryLogin(with presentingViewController: UIViewController) {
        guard let clientId = configuration?.clientId else { return }
        guard let redirectUrlProtocol = configuration?.redirectUrlProtocol else { return }
        guard let issuer = URL(string: "https://auth.myshopping.help") else { return }
        setIsBusy(true)
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { [weak self] configuration, error in
            guard let configuration else {
                self?.setIsBusy(false)
                return
            }
            self?.loginConfigurationFetched(configuration, for: presentingViewController, with: clientId, and: redirectUrlProtocol)
        }
    }
    
    private func loginConfigurationFetched(_ configuration: OIDServiceConfiguration, for presentingViewController: UIViewController, with clientId: String, and redirectUrlProtocol: String) {
        let request = OIDAuthorizationRequest(configuration: configuration,
                                              clientId: clientId,
                                              scopes: [OIDScopeOpenID, OIDScopeEmail, OIDScopeProfile],
                                              redirectURL: URL(string: "\(redirectUrlProtocol)://msh/callback")!,
                                              responseType: OIDResponseTypeCode,
                                              nonce: nil,
                                              additionalParameters: nil)
        currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController, prefersEphemeralSession: true, callback: loginFlowDidFinish)
    }
    
    private func loginFlowDidFinish(_ state: OIDAuthState?, _ error: Error?) {
        if let state {
            currentSession = state
        }
        else if let error {
            print(error)
        }
        setIsBusy(false)
    }
    
    public func resumeExternalUserAgentFlow(with url: URL) -> Bool {
        if currentAuthorizationFlow?.resumeExternalUserAgentFlow(with: url) ?? false {
            currentAuthorizationFlow = nil
            return true
        }
        return false
    }
    
    public func logout() {
        currentSession = nil
    }
    
}

public extension SHSessionManager {
    
    static let sessionDidChange: Notification.Name = .init("SHSessionManagerSessionDidChange")
    
}
