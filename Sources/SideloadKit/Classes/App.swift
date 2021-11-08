//
//  App.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation
import Darwin.sys
import CSideloadKit

/// Represents an iOS-formatted .app bundle on the filesystem
public class App {
    enum AppError: Error {
        case noCandidatesDetected
    }
    
    public let url: URL
    
    /// The entitlements for this app. Call readEntitlements to ensure you get a non-nil value.
    public private(set) var entitlements: Entitlements?
    
    /// Info.plist -- call readInfo to ensure you get a non-nil value
    public private(set) var info: AppInfo?
    
    /// All mach-o binaries within the app, including the executable itself. Call resolveValidMachOs to ensure a non-nil value.
    public private(set) var validMachOs: [URL]?
    
    /// Whether this app was created by unzipping from an IPA
    public var isTemporary: Bool {
        url.path.starts(with: SideloadIO.tempDirectory.path)
    }
    
    public init(url: URL) {
        self.url = url
    }
    
    /// Scans a folder for an app, and uses the first match. Throws if theres no apps in the folder.
    internal init(detectingAppNameInFolder folderURL: URL) throws {
        let contents = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
        
        var url: URL?
        
        for entry in contents {
            guard entry.hasSuffix(".app") else {
                continue
            }
            
            let entryURL = folderURL.appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            
            guard FileManager.default.fileExists(atPath: entryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            url = entryURL
            break
        }
        
        guard let url = url else {
            throw AppError.noCandidatesDetected
        }
        
        self.url = url
    }
    
    /// Reads the entitlements from the app, or returns a cached value if it was already read.
    public func readEntitlements() throws -> Entitlements {
        if let entitlements = entitlements {
            return entitlements
        }
        
        let entitlements = (try? Entitlements.read(fromURL: url)) ?? Entitlements(rawStorage: [:])
        self.entitlements = entitlements
        
        return entitlements
    }
    
    /// Reads the Info.plist from within the app, or returns a cached value if it was already read.
    public func readInfo() throws -> AppInfo {
        if let info = info {
            return info
        }
        
        let info = try AppInfo(contentsOf: url.appendingPathComponent("Info.plist"))
        self.info = info
        
        return info
    }
}

// MARK: - Mach-O

private extension URL {
    // Wraps NSFileEnumerator since the geniuses at corelibs-foundation decided it should be completely untyped
    func enumerateContents(_ callback: (URL, URLResourceValues) throws -> ()) throws {
        guard let enumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            do {
                try callback(fileURL, fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]))
            }
        }
    }
}

// You know, it'd be cool if Swift supported associated values. Unfortunately, fuck you.

public extension App {
    /// Returns an array of URLs to MachO files within the app
    func resolveValidMachOs() throws -> [URL] {
        if let validMachOs = validMachOs {
            return validMachOs
        }
        
        var resolved: [URL] = []
        
        try url.enumerateContents { url, attributes in
            guard attributes.isRegularFile == true, let fileSize = attributes.fileSize, fileSize > 4 else {
                return
            }
            
            if !url.pathExtension.isEmpty && url.pathExtension != "dylib" {
                return
            }
            
            let handle = try FileHandle(forReadingFrom: url)
            
            defer {
                try! handle.close()
            }
            
            guard let data = try handle.read(upToCount: 4) else {
                return
            }
            
            switch Array(data) {
            case [202, 254, 186, 190]: resolved.append(url)
            case [207, 250, 237, 254]: resolved.append(url)
            default: return
            }
        }
        
        validMachOs = resolved
        
        return resolved
    }
}

// MARK: - Compatibility overrides

public extension App {
    func overwriteVTool(atURL url: URL) throws {
        _ = try shell(
            "/usr/bin/vtool",
            "-arch", "arm64",
            "-set-build-version", "maccatalyst", "10.0", "14.5",
            "-replace", "-output",
            url.path, url.path
        )
    }
    
    /// Callout to C, because Swift's philosophy is that anything non-trivial should be verbose and ugly
    func masqueradeToSimulator(atURL url: URL) throws -> Bool {
        convert(url.path) == 0
    }
    
    /// Calls out to otool and scans for an encryption segment with cryptid 1
    func isMachoEncrypted(atURL url: URL) throws -> Bool {
        try shell(
            "/usr/bin/otool",
            "-l", url.path
        ).split(separator: "\n")
         .first(where: { $0.contains("LC_ENCRYPTION_INFO -A5") })?.contains("cryptid 1") ?? false
    }
    
    /// Equivalent to chmod -- setBinaryPosixPermissions(0o777)
    func setBinaryPosixPermissions(_ permissions: Int) throws {
        let info = try readInfo()
        
        let executablePath = url.appendingPathComponent(info.executableName)
        
        try FileManager.default.setAttributes([
            .posixPermissions: permissions
        ], ofItemAtPath: executablePath.path)
    }
}

// MARK: - Signature

public extension App {
    /// Wrapper for codesign, applies the given entitlements to the application and all of its contents
    func resign(withEntitlements entitlements: Entitlements) throws {
        let directory = try SideloadIO.allocateTempDirectory()
        defer {
            try! FileManager.default.removeItem(at: directory)
        }
        
        let entURL = directory.appendingPathComponent("entitlements.plist")
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        try encoder.encode(entitlements).write(to: entURL)
        
        print(try shell("/usr/bin/codesign", "-fs-", url.path, "--deep", "--entitlements", entURL.path))
    }
}

// MARK: - Wrapping

public extension App {
    /// Generates a wrapper bundle for an iOS app that allows it to be launched from Finder and other macOS UIs
    func wrap(toLocation location: URL) throws {
        if FileManager.default.fileExists(atPath: location.path) {
            try FileManager.default.removeItem(at: location)
        }
        
        let wrapperURL = location.appendingPathComponent("Wrapper")
        let appDestination = wrapperURL.appendingPathComponent(url.lastPathComponent)
        
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: wrapperURL, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.copyItem(at: url, to: appDestination)
        try FileManager.default.createSymbolicLink(atPath: location.appendingPathComponent("WrappedBundle").path, withDestinationPath: "Wrapper/".appending(url.lastPathComponent))
    }
}

public extension App {
    /// Regular codesign, does not accept entitlements. Used to re-seal an app after you've modified it.
    func fakesign(_ url: URL) throws {
        _ = try shell("/usr/bin/codesign", "-fs-", url.path)
    }
}
