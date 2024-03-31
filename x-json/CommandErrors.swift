//
//  CommandErrors.swift
//  x-json
//
//  Created by Ren Jeremy on 2024/3/23.
//

import Foundation

enum CommandErrors: Error, LocalizedError, CustomNSError {
    case noSelection
    case invalidJson
    
    var localizedDescription: String {
        switch self {
        case .noSelection:
            return "Error: no text selected."
        case .invalidJson:
            return "Error: invalid Json"
        }
    }
    
    var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: localizedDescription]
    }
}
