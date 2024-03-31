//
//  SourceEditorCommand.swift
//  x-json
//
//  Created by Ren Jeremy on 2024/3/23.
//

import Foundation
import XcodeKit

indirect enum PropertyType {
    case classType(String)
    case arrayType(PropertyType)
    case stringType
    case floatType
    case intType
    case boolType
    
    func getTypeString() -> String {
        switch self {
        case let .classType(val):
            return val.isEmpty ? "Model": val
        case let .arrayType(property):
            return property.getTypeString()
        case .stringType:
            return "String"
        case .floatType:
            return "float"
        case .intType:
            return "int"
        case .boolType:
            return "Bool"
        }
    }
}

class Model {
    let name: String
    var properties: [PropertyModel]
    
    init(name: String, properties: [PropertyModel] = [PropertyModel]()) {
        self.name = name.capitalized.replacingOccurrences(of: " ", with: "")
        self.properties = properties
    }
}

class PropertyModel {
    let key: String
    var type: PropertyType
    
    init(key: String, type: PropertyType) {
        self.key = key.replacingOccurrences(of: " ", with: "")
        self.type = type
    }
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    var models = [Model]()
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
        let selections = invocation.buffer.selections.compactMap { $0 as? XCSourceTextRange }
        if selections.isEmpty {
            // 可能是文件内容是空的吧
            return completionHandler(CommandErrors.noSelection)
        } else {
            let lines = invocation.buffer.lines
            
            let start = selections[0].start
            let end = selections[0].end
            if start.line - end.line == 0 && start.column - end.column == 0 {
                return completionHandler(CommandErrors.noSelection)
            }
            var jsonString = ""
            for row in start.line ... end.line {
                jsonString += lines[row] as! String
            }
            print("selection string: \(jsonString)")
            
            var json: Any
            
            var updatedText = Array(lines)
            var name = ""
            if (updatedText.count > 1) {
                name = wrapClassName(name: updatedText[1] as! String)
            }
            if let jsonData = jsonString.data(using: .utf8) {
                do {
                    json = try JSONSerialization.jsonObject(with: jsonData)
                    if let array = json as? Array<Any> {
                        _ = handleArray(name: name, array: array)
                    } else if let object = json as? [String: Any] {
                        _ = handleObject(name: name, object: object)
                    }
                } catch {
                    return completionHandler(CommandErrors.invalidJson)
                }
            }
            
            updatedText.removeSubrange(start.line ... end.line)
            
            if let string = convertModelToString() {
                if (start.line > updatedText.count) {
                    updatedText.append(string)
                } else {
                    updatedText.insert(string, at: start.line)
                }
            }
            
            lines.removeAllObjects()
            lines.addObjects(from: updatedText)
        }
        //        // Reverse the order of the lines in a copy.
        //        let updatedText = Array(lines.reversed())
        //        lines.removeAllObjects()
        //        lines.addObjects(from: updatedText)
        //        // Signal to Xcode that the command has completed.
        
        completionHandler(nil)
    }
    
    func wrapClassName(name: String) -> String {
        //  test.h
        let pattern = "(^\\/+\\s*)|(\\.swift$)"
        var result = ""
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            result = regex.stringByReplacingMatches(in: name, options: [], range: NSRange(name.startIndex..., in: name), withTemplate: "")
        } catch {
            print("error")
        }
        return result
    }
    
    func handleArray(name: String, array: Array<Any>) -> PropertyModel? {
        if (array.count > 0) {
            let first = array.first
            if let childArray = first as? Array<Any> {
                let propertyModel = handleArray(name: name, array: childArray)
                return propertyModel
            } else if let childObject = first as? [String: Any] {
                let propertyModel = handleObject(name: name, object: childObject)
                return propertyModel
            } else if (first as? String) != nil {
                let propertyModel = PropertyModel(key: "", type: .stringType)
                return propertyModel
            } else if (first as? Float) != nil {
                let propertyModel = PropertyModel(key: "", type: .floatType)
                return propertyModel
            } else if (first as? Int) != nil {
                let propertyModel = PropertyModel(key: "", type: .intType)
                return propertyModel
            } else if (first as? Bool) != nil {
                let propertyModel = PropertyModel(key: "", type: .boolType)
                return propertyModel
            }
        }
        return nil
    }
    
    func handleObject(name: String, object: [String: Any]) -> PropertyModel? {
        let model = Model(name: name)
        for key in object.keys {
            let item = object[key]
            if let childArray = item as? Array<Any> {
                if let propertyModel = handleArray(name: key, array: childArray) {
                    model.properties.append(propertyModel)
                }
            } else if let childObject = item as? [String: Any] {
                _ = handleObject(name: key, object: childObject)
            } else if (item as? String) != nil {
                let propertyModel = PropertyModel(key: key, type: .stringType)
                model.properties.append(propertyModel)
            } else if (item as? Float) != nil {
                let propertyModel = PropertyModel(key: key, type: .floatType)
                model.properties.append(propertyModel)
            } else if (item as? Int) != nil {
                let propertyModel = PropertyModel(key: key, type: .intType)
                model.properties.append(propertyModel)
            } else if (item as? Bool) != nil {
                let propertyModel = PropertyModel(key: key, type: .boolType)
                model.properties.append(propertyModel)
            }
        }
        models.append(model)
        return PropertyModel.init(key: name, type: .classType(name.capitalized))
    }
    
    func convertModelToString() -> String? {
        var string = ""
        for model in models {
            if model.name.isEmpty {
                string += "class Model {\n"
            } else {
                string += "class \(model.name) {\n"
            }
            
            var index = 0
            for property in model.properties {
                if property.key.isEmpty {
                    string += "    let \(property.key)-\(index): \(property.type.getTypeString())\n"
                } else {
                    string += "    let \(property.key): \(property.type.getTypeString())\n"
                }
                index += 1
            }
            string += "}\n"
        }
        return string
    }
    
}

//if num.truncatingRemainder(dividingBy: 1) == 0 {
//    print("整数")
//} else {
//    print("非整数")
//}
