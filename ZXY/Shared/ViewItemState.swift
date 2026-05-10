//
//  ViewState.swift
//
//  Created by Harsh Kumar on 03/04/26.
//

import Foundation

enum ViewItemState<T> {
    case initial
    case loading
    case loaded(T)
    case error(String)
}
