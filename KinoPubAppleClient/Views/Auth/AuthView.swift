//
//  AuthView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//
import SwiftUI
import KinoPubUI
import PopupView

struct AuthView: View {
  
  @StateObject var model: AuthModel
  @Environment(\.dismiss) var dismiss
  
  init(model: @autoclosure @escaping () -> AuthModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var body: some View {
    return VStack(spacing: 50) {
      titleView
      deviceCodeView
      activateButton
    }
    .padding(EdgeInsets.init(top: 0, leading: 16, bottom: 0, trailing: 16))
    .fixedSize(horizontal: false, vertical: true)
    .edgesIgnoringSafeArea(.all)
    .background(Color.KinoPub.background)
    .popup(isPresented: $model.showError) {
      ToastContentView(text: model.error ?? "")
        .padding()
    } customize: {
      $0
        .type(.floater())
        .position(.bottom)
        .animation(.spring())
        .closeOnTapOutside(true)
        .autohideIn(5.0)
    }
    .interactiveDismissDisabled(true)
    .task {
      model.fetchDeviceCode()
    }
    .onReceive(model.$close, perform: { shouldClose in
      if shouldClose {
        dismiss()
      }
    })
  }
  
  var titleView: some View {
    VStack(spacing: 20) {
      Text("Auth_CodeActivationTitle")
        .font(.system(size: 24, weight: Font.Weight.semibold))
        .frame(alignment: .leading)
        .foregroundColor(Color.KinoPub.text)
      Text("Auth_CodeActivationText")
        .lineLimit(nil)
        .font(.system(size: 16, weight: Font.Weight.regular))
        .foregroundColor(Color.KinoPub.text)
        .multilineTextAlignment(.center)
        .padding(.top, 16)
    }
    .background(Color.KinoPub.background)
    .fixedSize(horizontal: false, vertical: true)
  }
  
  var deviceCodeView: some View {
    VStack(spacing: 5) {
      Text(model.deviceCode)
        .font(.system(size: 40, weight: Font.Weight.bold))
        .foregroundColor(Color.KinoPub.text)
        .frame(minHeight: 44, idealHeight: 44, maxHeight: 44)
      Text("Auth_DeviceCode")
        .foregroundColor(Color.KinoPub.text)
        .font(.system(size: 16, weight: Font.Weight.regular))
    }
    .fixedSize(horizontal: false, vertical: true)
  }
  
  var activateButton: some View {
    Button("Auth_Activate", action: { model.openActivationURL() })
      .foregroundColor(Color.KinoPub.text)
      .padding(.all, 20.0)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.KinoPub.text, lineWidth: 2)
      )
  }
}

//struct AuthView_Previews: PreviewProvider {
//  static var previews: some View {
//    AuthView()
//  }
//}
