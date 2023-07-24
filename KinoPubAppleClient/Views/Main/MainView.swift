//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI

struct MainView: View {
    var body: some View {
      NavigationView {
        VStack {
          ContentItemsListView()
        }
        .navigationTitle("Main")
        .background(Color.KinoPub.background)
      }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
      MainView()
    }
}
