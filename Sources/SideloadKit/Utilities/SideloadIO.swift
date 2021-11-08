//
//  SideloadIO.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

/// Helpers for where to store working data
internal class SideloadIO {
    static var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SideloadKit")
    }
    
    static var tempDirectory: URL {
        documentDirectory.appendingPathComponent("tmp")
    }
    
    static func allocateTempDirectory() throws -> URL {
        let workDir = SideloadIO.tempDirectory.appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true, attributes: [:])
        
        return workDir
    }
}
