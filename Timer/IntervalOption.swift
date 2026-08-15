//
//  IntervalOption.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import Foundation

/// Predefined reminder intervals shown in the segmented picker, plus a sentinel
/// case for user-supplied custom minute values.
enum IntervalOption: Int, CaseIterable, Codable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    case custom = -1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fifteen: "15"
        case .thirty: "30"
        case .sixty: "60"
        case .custom: "Other"
        }
    }
}
