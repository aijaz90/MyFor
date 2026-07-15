//
//  ContentView.swift
//  MrFor
//
//  Created by Aijaz Ali on 08/07/2026.
//

import SwiftUI

struct ContentView: View {
    let reader: ReaderEngine

    var body: some View {
        PaymentView(reader: reader)
    }
}

#Preview {
    ContentView(reader: ReaderEngine())
}
