//
//  Document.swift
//  MTSCRADemo-Swift
//
//  Created by Tam Nguyen on 6/9/20.
//  Copyright © 2020 MagTek. All rights reserved.
//
import UIKit
import Foundation
class Document: UIDocument {
    
    // #2.0 - Model for storing binary data when file type is "public.image".
    var fileData: Data?
    // #2.1 - Model for storing text when file type is "public.plain-text".
    var filesText: String?
    
    // #3.0 - Use this for WRITING/SAVING files. I only allow
    // editing/saving of text files, not image files.
    // "Override this method to return the document data to be saved."
    override func contents(forType typeName: String) throws -> Any {
        
        // #3.1 - UIDocument knows what type of file it
        // currently represents. The file type is passed
        // to this method when it's called during saves.
        if typeName == "public.xml " {
            
            // #3.2 - Use optional binding to find out
            // whether the "filesText" optional contains a value.
            if let content = filesText {
                
                // #3.3 - Return a Data instance containing
                // a representation of the String encoded using
                // UTF-8 (basically, plain text).
                let data = content.data(using: .utf8)
                return data!
                
            } else {
                return Data()
            }
            
        } else {
            return Data()
        }
        
    } // end func contents
    
    // #4.0 - "load" is called soon after "open"; used for READING data
    // from the user-selected document and storing that data
    // in the UIDocument's model. Called when document is opened.
    // "Override this method to load the document data into the app's data model."
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        
        // #4.1 - We can only read data if we know
        // what type of file we're reading from.
        if let fileType = typeName {
            
          if fileType == "com.apple.macbinary-archive" {
                
                // #4.5 - ... and if reading was successful, store
                // the UTF-8 encoded text data into the document model.
                if let fileContents = contents as? Data {
                    fileData = fileContents
                    filesText = String(data: fileContents, encoding: .utf8)
                    
                }
                
            } else {
                print("File type unsupported.")
            }
            
        } // end if let fileType = typeName
        
    } // end func load
    
    // #5.0 - "A UIDocument object has a specific state at
    // any moment in its life cycle. You can check
    // the current state by querying the documentState
    // property..." State can help us in debugging.
    public var state: String {
        
        switch documentState {
            
        case .normal:
            return "Normal"
        case .closed:
            return "Closed"
        case .inConflict:
            return "Conflict"
        case .savingError:
            return "Save Error"
        case .editingDisabled:
            return "Editing Disabled"
        case .progressAvailable:
            return "Progress Available"
            
        default:
            return "Unknown"
            
        }
        
    } // e
}
