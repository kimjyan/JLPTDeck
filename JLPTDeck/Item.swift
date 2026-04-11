//
//  Item.swift
//  JLPTDeck
//
//  Created by 김재한 on 4/11/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
