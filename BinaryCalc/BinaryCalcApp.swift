//
//  BinaryCalcApp.swift
//  BinaryCalc
//
//  Created by Chiel Zwinkels on 28/10/2026.
//

import SwiftUI

@main
struct BinaryCalcApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.binaryTheme, .default)
                .environment(\.binaryDisplayMode, .wide)
        }
    }
}
