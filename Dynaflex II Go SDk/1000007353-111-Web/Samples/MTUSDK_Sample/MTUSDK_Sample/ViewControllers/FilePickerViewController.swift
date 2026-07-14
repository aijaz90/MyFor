//
//  FilePickerViewController.swift
//  MTSCRA FW Update Swift
//
//  Created by Yong Guo on 2/11/22.
//

import UIKit
import UniformTypeIdentifiers

class FilePickerViewController: UIDocumentPickerViewController, UIDocumentPickerDelegate {
    
    let complete: (_ success: Bool, _ file: Data?) -> Void
    
    init(_ completeHanlder: @escaping (_ success: Bool, _ file: Data?) -> Void) {
        complete = completeHanlder
        
        if #available(iOS 14.0, *) {
            // UTTypeData also conforms to UTTypeItem (public.item), which is a generic base type for most items in a file system, such as files or directories.
            // Creates and returns a document picker that can open or copy the types of documents you specify.
            super.init(forOpeningContentTypes: [UTType.item], asCopy: false)
        } else {
            super.init(documentTypes: ["public.item"], in: .import)
        }
        
        modalPresentationStyle = .fullScreen
        shouldShowFileExtensions = true
        allowsMultipleSelection = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        complete(false, nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if (urls.count > 0) {
            do {
                // Get file content from: file:///private/var/mobile/Library/Mobile%20Documents/com~apple~Numbers/Documents/CFG0006364-E1.xlsx
                self.debugPrintLog("Get file content from: \(urls[0])")
                
                let url = urls[0]
                
                if url.startAccessingSecurityScopedResource() {
                    let data = try Data(contentsOf: url)
                    complete(true, data)
                }
                url.stopAccessingSecurityScopedResource()
            } catch {
                print("Load file: \(urls[0]) with Error: \(error.localizedDescription)")
                complete(false, nil)
            }
        }
        else {
            complete(false, nil)
        }
    }
}
