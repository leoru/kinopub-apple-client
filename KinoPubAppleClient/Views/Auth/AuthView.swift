//
//  AuthView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//
import SwiftUI
import KinoPubUI
import SimpleToast

struct AuthView: View {
  
  @ObservedObject private var model: AuthModel
  
  init(model: AuthModel) {
    self.model = model
  }
  
  var body: some View {
    Color.KinoPub.background
      .edgesIgnoringSafeArea(.all)
      .overlay(
        VStack(spacing: 50) {
          VStack(spacing: 20) {
            Text("Auth_CodeActivationTitle")
              .font(.system(size: 20, weight: Font.Weight.semibold))
              .frame(alignment: .leading)
              .foregroundColor(Color.KinoPub.text)
            Text("Auth_CodeActivationText")
              .lineLimit(nil)
              .font(.system(size: 14, weight: Font.Weight.regular))
              .foregroundColor(Color.KinoPub.text)
              .multilineTextAlignment(.center)
          }
          .fixedSize(horizontal: false, vertical: true)
          VStack(spacing: 5) {
            Text(model.deviceCode)
              .font(.system(size: 34, weight: Font.Weight.bold))
              .foregroundColor(Color.KinoPub.text)
              .frame(minHeight: 44, idealHeight: 44, maxHeight: 44)
            Text("Auth_DeviceCode")
              .foregroundColor(Color.KinoPub.text)
              .font(.system(size: 14, weight: Font.Weight.regular))
          }
          .fixedSize(horizontal: false, vertical: true)
          Button("Auth_Activate", action: { })
            .foregroundColor(Color.KinoPub.text)
            .padding(EdgeInsets.init(top: 16, leading: 16, bottom: 16, trailing: 16))
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(Color.KinoPub.text, lineWidth: 2)
            )
        }
          .padding(EdgeInsets.init(top: 0, leading: 16, bottom: 0, trailing: 16))
          .fixedSize(horizontal: false, vertical: true)
      )
      .interactiveDismissDisabled(true)
      .simpleToast(isPresented: $model.showError, options: SimpleToastOptions.error, content: {
        Text(model.error ?? "")
          .foregroundStyle(Color.white)
      })
      .onAppear(perform: {
        model.fetchDeviceCode()
      })
  }
}

//struct AuthView_Previews: PreviewProvider {
//  static var previews: some View {
//    AuthView()
//  }
//}
