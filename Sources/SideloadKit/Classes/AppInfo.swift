//
//  AppInfo.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

public class AppInfo {
    public enum AppInfoError: Error {
        case invalidRoot(Any)
    }
    
    public let url: URL
    fileprivate var rawStorage: NSMutableDictionary
    
    public init(contentsOf url: URL) throws {
        rawStorage = try NSMutableDictionary(contentsOf: url, error: ())
        
        self.url = url
    }
    
    private init(url: URL, rawStorage: NSMutableDictionary) {
        self.url = url
        self.rawStorage = rawStorage
    }
    
    public func retargeted(toURL url: URL) -> AppInfo {
        AppInfo(url: url, rawStorage: rawStorage.mutableCopy() as! NSMutableDictionary)
    }
}

public extension AppInfo {
    /// Write an XML-serialized representation of this info to the given URL
    func write(toURL url: URL) throws {
        try rawStorage.write(to: url)
    }
    
    /// Overwrites the file this AppInfo was loaded from
    func write() throws {
        try write(toURL: url)
    }
}

// MARK: - Subscripting

public extension AppInfo {
    subscript (string index: String) -> String? {
        get {
            rawStorage[index] as? String
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (object index: String) -> NSObject? {
        get {
            rawStorage[index] as? NSObject
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (dictionary index: String) -> NSMutableDictionary? {
        get {
            rawStorage[index] as? NSMutableDictionary
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (strings index: String) -> [String]? {
        get {
            rawStorage[index] as? [String]
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (array index: String) -> NSMutableArray? {
        get {
            rawStorage[index] as? NSMutableArray
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (numbers index: String) -> [NSNumber]? {
        get {
            rawStorage[index] as? [NSNumber]
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (ints index: String) -> [Int]? {
        get {
            rawStorage[index] as? [Int]
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (doubles index: String) -> [Double]? {
        get {
            rawStorage[index] as? [Double]
        }
        set {
            rawStorage[index] = newValue
        }
    }
    
    subscript (bool index: String) -> Bool? {
        get {
            rawStorage[index] as? Bool
        }
        set {
            rawStorage[index] = newValue
        }
    }
}

// MARK: - Frequent Fliers

public extension AppInfo {
    var minimumOSVersion: String {
        get {
            self[string: "MinimumOSVersion"]!
        }
        set {
            self[string: "MinimumOSVersion"] = newValue
        }
    }
    
    var bundleName: String {
        self[string: "CFBundleName"]!
    }
    
    var displayName: String {
        self[string: "CFBundleDisplayName"]!
    }
    
    var bundleIdentifier: String {
        self[string: "CFBundleIdentifier"]!
    }
    
    var executableName: String {
        self[string: "CFBundleExecutable"]!
    }
}

// MARK: - Patching

public extension AppInfo {
    func assert(minimumVersion: Double) {
        if Double(minimumOSVersion)! < 11.0 {
            minimumOSVersion = Int(minimumVersion).description
        }
    }
}
