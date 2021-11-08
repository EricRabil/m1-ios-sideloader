//
//  ObjectiveC.swift
//  SideloadKit
//
//  Created by Eric Rabil on 11/6/21.
//

import Foundation

extension NSObjectProtocol {
    static func enumerateMethods(`static` staticMethods: Bool = false, _ iterator: (Method) throws -> ()) rethrows {
        var count: UInt32 = 0
        
        guard let methodList = class_copyMethodList(staticMethods ? object_getClass(self) : self, &count) else {
            return
        }
        
        for i in 0..<Int(count) {
            try iterator(methodList.advanced(by: i).pointee)
        }
    }
}
