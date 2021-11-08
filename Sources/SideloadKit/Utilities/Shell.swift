//
//  Shell.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/7/21.
//

import Foundation

/// Synchronously execute a command in a shell-like fashion, returning an aggregation of stdout and stderr
internal func shell(_ binary: String, _ args: String...) throws -> String {
    let process = Process()
    
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = args
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    try process.run()
    process.waitUntilExit()
    
    let output = try pipe.fileHandleForReading.readToEnd() ?? Data()
    
    return String(decoding: output, as: UTF8.self)
}
