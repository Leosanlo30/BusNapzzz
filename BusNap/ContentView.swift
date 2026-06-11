//
//  ContentView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/06/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Welcome to BUSNAPZZZ")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.primary)
                .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
