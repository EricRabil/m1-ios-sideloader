//
//  Entitlement.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

public enum Entitlement {
    case boolean(Bool)
    case strings([String])
    case string(String)
}

extension Entitlement: Encodable {
    @_transparent private var encodable: Encodable {
        switch self {
        case .boolean(let boolValue):
            return boolValue
        case .strings(let stringsValue):
            return stringsValue
        case .string(let stringValue):
            return stringValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}

extension Entitlement: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        do {
            self = .boolean(try container.decode(Bool.self))
        } catch {
            do {
                self = .strings(try container.decode([String].self))
            } catch {
                self = .string(try container.decode(String.self))
            }
        }
    }
}

public extension Entitlement {
    static func parse(rawEntitlements: NSDictionary) -> [String: Entitlement] {
        var dictionary = [String: Entitlement](minimumCapacity: rawEntitlements.count)
        
        for (key, value) in rawEntitlements {
            switch value {
            case let boolean as Bool:
                dictionary[key as! String] = .boolean(boolean)
            case let array as [String]:
                dictionary[key as! String] = .strings(array)
            case let string as String:
                dictionary[key as! String] = .string(string)
            default:
                print("what")
            }
        }
        
        return dictionary
    }
}
