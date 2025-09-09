//
//  DateFormatter.swift
//  SeSACLocation
//
//  Created by Lee on 9/9/25.
//

import Foundation

final class DateManager {
    static let dateFormatter = DateFormatter()

    static func changeDateForString(date: Date) -> String {
        dateFormatter.dateFormat = "yyyy년 MM월 dd일 a HH시 mm분"
        dateFormatter.locale = Locale(identifier: "ko_KR")
        return dateFormatter.string(from: date)
    }
}
