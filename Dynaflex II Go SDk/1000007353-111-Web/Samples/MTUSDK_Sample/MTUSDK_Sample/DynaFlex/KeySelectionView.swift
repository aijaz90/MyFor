//
//  KeySelectionView.swift
//  MTUSDK_MacSample
//
//  Created by Yong Guo on 6/1/22.
//

import SwiftUI

struct KeySelectionView: View {
    @Binding
    var keys : [KeyInfo]?
    
    let action : (_ key: KeyInfo)->()
    let cancel : ()->()
    
    var body: some View {
        ForEach(keys!, id:\.id) {key in
            Button(key.keyName!) {
                action(key)
            }
        }
        Button("Cancel") {
            cancel()
        }
    }
}
