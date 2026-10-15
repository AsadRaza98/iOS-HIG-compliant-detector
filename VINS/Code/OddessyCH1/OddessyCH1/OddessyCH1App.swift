//
//  OddessyCH1App.swift
//  OddessyCH1
//
//  Created by Asad Raza on 25/09/2026.
//

import SwiftUI

@main
struct OddessyCH1App: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Text", systemImage: "textformat.size") {
                    ContentView()
                }
                Tab("Elements", systemImage: "square.dashed") {
                    DetectorView()
                }
            }
        }
    }
}
