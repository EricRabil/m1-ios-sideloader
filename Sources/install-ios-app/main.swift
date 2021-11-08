//
//  main.swift
//  install-ios-app
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation
import SideloadKit
import SwiftCLI

class Installer: Command {
    let name = "install"
    
    @Param var src: String
    @Param var dst: String
    
    @Flag("-v", "--vtool") var vtoolPatch: Bool
    
    lazy var srcURL = URL(fileURLWithPath: src)
    lazy var dstURL = URL(fileURLWithPath: dst)
    
    func execute() throws {
        var app: App, ipa: IPA?
        
        if srcURL.pathExtension == "ipa" {
            // extract IPA
            ipa = IPA(url: srcURL)
            app = try ipa!.unzip()
        } else {
            app = App(url: srcURL)
        }
        
        let entitlements = try app.readEntitlements()

        let machos = try app.resolveValidMachOs()

        // modify all machos to make macos shut the hell up
        for macho in machos {
            if try app.isMachoEncrypted(atURL: macho) {
                print("Can't process encrypted files at this time, bye!")
                exit(-1)
            }
            
            if vtoolPatch {
                try app.overwriteVTool(atURL: macho)
            } else {
                _ = try app.masqueradeToSimulator(atURL: macho)
            }
            
            _ = try app.fakesign(macho)
        }

        // -rwxr-xr-x
        try app.setBinaryPosixPermissions(0o755)

        let info = try app.readInfo()
        info.assert(minimumVersion: 11.0)
        try info.write()
        
        try app.wrap(toLocation: dstURL)

        try App(url: dstURL).resign(withEntitlements: entitlements)
        
        // cleanup tempdir if we unzipped an ipa
        try ipa?.releaseWorkDir()
    }
}

CLI(singleCommand: Installer()).goAndExit()
