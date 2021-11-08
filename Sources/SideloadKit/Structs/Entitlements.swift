//
//  Entitlements.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

public struct Entitlements: Codable {
    public typealias RawStorage = [String: Entitlement]
    
    public var rawStorage: RawStorage
    
    public init(rawStorage: RawStorage) {
        self.rawStorage = rawStorage
    }
    
    public init(from decoder: Decoder) throws {
        rawStorage = try RawStorage(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try rawStorage.encode(to: encoder)
    }
}

public extension Entitlements {
    
    
    static func parse(rawEntitlements: NSDictionary) -> Entitlements {
        Entitlements(rawStorage: Entitlement.parse(rawEntitlements: rawEntitlements))
    }
    
    static func read(fromURL url: URL) throws -> Entitlements {
        var error: NSError?
        let ent = AppSandboxEntitlementsCls.entitlementsForCodeAtURL(url as NSURL, error: &error)
        
        if let error = error {
            throw error
        }
        
        return Entitlements.parse(rawEntitlements: ent.allEntitlements())
    }
    
    subscript (bool index: String) -> Bool? {
        guard case .boolean(let boolValue) = rawStorage[index] else {
            return nil
        }
        
        return boolValue
    }
    
    subscript (string index: String) -> String? {
        guard case .string(let stringValue) = rawStorage[index] else {
            return nil
        }
        
        return stringValue
    }
    
    subscript (strings index: String) -> [String]? {
        guard case .strings(let stringsValue) = rawStorage[index] else {
            return nil
        }
        
        return stringsValue
    }
}

// Private API that lets us copy the entitlements of an app
@objc private protocol AppSandboxEntitlements: NSObjectProtocol {
    @objc static func entitlementsForCodeAtURL(_ url: NSURL, error: UnsafeMutablePointer<NSError?>) -> AppSandboxEntitlements
    @objc func allEntitlements() -> NSDictionary
}

private let AppSandboxEntitlementsCls: AppSandboxEntitlements.Type = {
    let handle = dlopen("/System/Library/PrivateFrameworks/AppSandbox.framework/AppSandbox", RTLD_NOW)
    defer { dlclose(handle) }
    
    return unsafeBitCast(NSClassFromString("AppSandboxEntitlements"), to: AppSandboxEntitlements.Type.self)
}()
