//
//  AuthorizationServiceProvider.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

protocol AuthorizationServiceProvider {
  var authService: AuthorizationService { get set }
}
