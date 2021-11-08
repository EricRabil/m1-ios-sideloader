//
//  IPA.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

public class IPA {
    public let url: URL
    public private(set) var workDir: URL?
    
    public init(url: URL) {
        self.url = url
    }
    
    public func allocateWorkDir() throws -> URL {
        if let workDir = workDir, FileManager.default.fileExists(atPath: workDir.path) {
            return workDir
        }
        
        let workDir = try SideloadIO.allocateTempDirectory()
        self.workDir = workDir
        
        return workDir
    }
    
    public func releaseWorkDir() throws {
        guard let workDir = workDir else {
            return
        }
        
        if FileManager.default.fileExists(atPath: workDir.path) {
            try FileManager.default.removeItem(at: workDir)
        }
        
        self.workDir = nil
    }
    
    public func unzip() throws -> App {
        let workDir = try allocateWorkDir()
        
        switch unzip_to_destination(url.path, workDir.path) {
        case .success:
            return try App(detectingAppNameInFolder: workDir.appendingPathComponent("Payload"))
        case let bomError: throw bomError
        }
    }
}
