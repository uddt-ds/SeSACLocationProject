//
//  WeatherModel.swift
//  SeSACLocation
//
//  Created by Lee on 9/9/25.
//

import Foundation

//metric으로 요청

// 현재온도, 최저온도, 최고온도, 습도, 풍속
struct WeatherModel: Decodable {
    let main: WeatherMain
    let wind: Wind
}

struct WeatherMain: Decodable {
    let temp: Double
    let tempMin: Double
    let tempMax: Double
    let humidity: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case humidity
    }
}

struct Wind: Decodable {
    let speed: Double
}
