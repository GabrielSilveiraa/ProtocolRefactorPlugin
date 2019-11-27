//
//  SourceEditorCommand.swift
//  ProtocolRefactorExtension
//
//  Created by Gabriel Silveira on 26/11/19.
//  Copyright © 2019 Gabriel Silveira. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        if invocation.buffer.selections.count > 1 {
            completionHandler(nil)
            return
        }
        
        var text = invocation.buffer.completeBuffer
        let functions = getFunctions(from: &text)
        guard let classDeclarationRange = getClassDeclarationRange(from: text) else {
            return
        }
        let protocolName = getProtocolName(from: text)
        let refactoredClassDeclaration =
            getRefactoredClassDeclaration(text: text, protocolName: protocolName)
        
        guard let lines = invocation.buffer.lines as? [String] else { return }
        guard let line = lines.first(where: { $0.contains("class") }),
            let classLineIndex = lines.firstIndex(of: line) else { return }
        
        invocation.buffer.completeBuffer.removeSubstring(with: classDeclarationRange)
        invocation.buffer.lines.insert(refactoredClassDeclaration, at: classLineIndex)
        invocation.buffer.lines.insert("", at: classLineIndex)
        invocation.buffer.lines.insert("}", at: classLineIndex)
        functions.reversed().forEach {
            invocation.buffer.lines.insert("\t\($0)", at: classLineIndex)
        }
        invocation.buffer.lines.insert("protocol \(protocolName): AnyObject {", at: classLineIndex)
        
        completionHandler(nil)
    }
    
    private func getFunctions(from text: inout String) -> [String] {
        var functions: [String] = []
        var `continue` = true
        
        while(`continue`) {
            if let range = text.range(of: "func *[0-9a-zA-Z_]+ *\\(([0-9a-zA-Z_\\: \\,\\n\\t\\(\\)->]+\\)?)", options: .regularExpression) {
                functions.append(text.substring(from: range))
                text.removeSubstring(with: range)
            } else {
                `continue` = false
            }
        }
        return functions
    }
    
    private func getClassDeclarationRange(from text: String) -> Range<String.Index>? {
        return text.range(of: "(final)? *(public|private|internal)? *class *[0-9a-zA-Z_]+\\:? *([0-9a-zA-Z_]+\\,? *)*", options: .regularExpression)
    }
    
    private func getProtocolName(from text: String) -> String {
        guard let range = getClassDeclarationRange(from: text) else {
            return ""
        }
        let classText = text.substring(from: range)
        guard let classIndex = classText.range(of: "class ")?.upperBound else {
            return ""
        }
        let finalIndex = classText.range(of: ":")?.lowerBound ?? classText.range(of: "{")?.lowerBound ?? classText.endIndex
        
        let className = classText[classIndex..<finalIndex].replacingOccurrences(of: " ", with: "")
        return "\(className)Protocol"
    }
    
    private func getRefactoredClassDeclaration(text: String, protocolName: String) -> String {
        guard let range = getClassDeclarationRange(from: text) else {
            return ""
        }
        let classText = text.substring(from: range)
        var refactoredClassText = text.substring(from: range)
        
        if classText.contains(":") {
            refactoredClassText.append(contentsOf: ", \(protocolName) {")
        } else {
            refactoredClassText.append(contentsOf: ": \(protocolName) {")
        }
        return refactoredClassText
    }
}

extension String {
    func substring(from range: Range<String.Index>) -> String {
        if !(startIndex <= range.lowerBound && endIndex >= range.upperBound) {
            return ""
        }
        
        var distance = self.distance(from: startIndex, to: range.lowerBound)
        let rangeStartIndex = index(startIndex, offsetBy: distance)
        
        distance = self.distance(from: startIndex, to: range.upperBound) - 1
        if distance < 0 {
            distance = 0
        }
        let rangeEndIndex = index(startIndex, offsetBy: distance)
        
        return String(self[rangeStartIndex...rangeEndIndex])
    }
    
    mutating func removeSubstring(with range: Range<String.Index>) {
        if !(startIndex <= range.lowerBound && endIndex >= range.upperBound) {
            return
        }
        
        var distance = self.distance(from: startIndex, to: range.lowerBound)
        let rangeStartIndex = index(startIndex, offsetBy: distance-1)
        let leftSide = String(self[startIndex..<rangeStartIndex])
        
        distance = self.distance(from: startIndex, to: range.upperBound)
        let rangeEndIndex = index(startIndex, offsetBy: distance)
        let rightSide = String(self[rangeEndIndex..<endIndex])
        
        self = leftSide + rightSide
    }
}
