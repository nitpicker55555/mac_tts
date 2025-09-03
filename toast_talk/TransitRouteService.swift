//
//  TransitRouteService.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation
import CoreLocation

// MARK: - 数据模型

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct TransitStop: Codable {
    let id: String
    let name: String
    let location: Coordinate?
    let distance: Double?
}

struct Journey: Codable {
    let legs: [Leg]
    let departure: String?
    let arrival: String?
}

struct Leg: Codable {
    let origin: Stop
    let destination: Stop
    let departure: String?
    let arrival: String?
    let line: Line?
    let walking: Bool?
    let distance: Int?
    let stopovers: [Stopover]?
}

struct Stop: Codable {
    let name: String?
    let location: Location?
}

struct Location: Codable {
    let latitude: Double?
    let longitude: Double?
}

struct Line: Codable {
    let name: String?
    let mode: String?
}

struct Stopover: Codable {
    let stop: Stop?
    let arrival: String?
    let departure: String?
}

// GeoJSON相关结构
struct GeoJSONFeatureCollection: Codable {
    let type = "FeatureCollection"
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Codable {
    let type = "Feature"
    let geometry: GeoJSONGeometry
    let properties: [String: String?]
}

enum GeoJSONGeometry: Codable {
    case point(coordinates: [Double])
    case lineString(coordinates: [[Double]])
    
    private enum CodingKeys: String, CodingKey {
        case type, coordinates
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .point(let coords):
            try container.encode("Point", forKey: .type)
            try container.encode(coords, forKey: .coordinates)
        case .lineString(let coords):
            try container.encode("LineString", forKey: .type)
            try container.encode(coords, forKey: .coordinates)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "Point":
            let coords = try container.decode([Double].self, forKey: .coordinates)
            self = .point(coordinates: coords)
        case "LineString":
            let coords = try container.decode([[Double]].self, forKey: .coordinates)
            self = .lineString(coordinates: coords)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown geometry type"))
        }
    }
}

// MARK: - API响应结构

struct NearbyStopsResponse: Codable {
    let stops: [TransitStop]?
    
    init(from decoder: Decoder) throws {
        // API直接返回数组
        if let container = try? decoder.singleValueContainer(),
           let stops = try? container.decode([TransitStop].self) {
            self.stops = stops
        } else {
            self.stops = nil
        }
    }
}

struct JourneysResponse: Codable {
    let journeys: [Journey]
}

// MARK: - 交通路线服务

class TransitRouteService {
    static let shared = TransitRouteService()
    private let baseURL = "https://v6.db.transport.rest"
    private let session = URLSession.shared
    
    private init() {}
    
    // 查找坐标附近的站点
    func findNearestStops(latitude: Double, longitude: Double, radius: Int = 1000, results: Int = 5) async throws -> [TransitStop] {
        var components = URLComponents(string: "\(baseURL)/locations/nearby")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "distance", value: String(radius)),
            URLQueryItem(name: "stops", value: "true"),
            URLQueryItem(name: "poi", value: "false")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let stops = try JSONDecoder().decode([TransitStop].self, from: data)
        return stops
    }
    
    // 搜索路线
    func searchJourney(fromStopId: String, toStopId: String, results: Int = 3, stopovers: Bool = true) async throws -> JourneysResponse {
        var components = URLComponents(string: "\(baseURL)/journeys")!
        components.queryItems = [
            URLQueryItem(name: "from", value: fromStopId),
            URLQueryItem(name: "to", value: toStopId),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "stopovers", value: stopovers ? "true" : "false")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        
        // 记录API请求
        LogManager.shared.logAPI("请求路线: \(url)", endpoint: "journeys")
        
        let response = try JSONDecoder().decode(JourneysResponse.self, from: data)
        
        // 调试：打印第一条路线的时间信息
        if let firstJourney = response.journeys.first {
            print("=== 路线时间信息调试 ===")
            print("Journey级别 - departure: \(firstJourney.departure ?? "nil"), arrival: \(firstJourney.arrival ?? "nil")")
            
            var logMessage = "=== 路线时间信息调试 ===\n"
            logMessage += "Journey级别 - departure: \(firstJourney.departure ?? "nil"), arrival: \(firstJourney.arrival ?? "nil")\n"
            
            if let firstLeg = firstJourney.legs.first {
                print("第一段 - departure: \(firstLeg.departure ?? "nil"), origin: \(firstLeg.origin.name ?? "unknown")")
                logMessage += "第一段 - departure: \(firstLeg.departure ?? "nil"), origin: \(firstLeg.origin.name ?? "unknown")\n"
            }
            
            if let lastLeg = firstJourney.legs.last {
                print("最后段 - arrival: \(lastLeg.arrival ?? "nil"), destination: \(lastLeg.destination.name ?? "unknown")")
                logMessage += "最后段 - arrival: \(lastLeg.arrival ?? "nil"), destination: \(lastLeg.destination.name ?? "unknown")\n"
            }
            
            // 打印所有leg的时间信息
            for (index, leg) in firstJourney.legs.enumerated() {
                print("Leg \(index): dep=\(leg.departure ?? "nil"), arr=\(leg.arrival ?? "nil"), walking=\(leg.walking ?? false)")
                logMessage += "Leg \(index): dep=\(leg.departure ?? "nil"), arr=\(leg.arrival ?? "nil"), walking=\(leg.walking ?? false)\n"
            }
            
            LogManager.shared.logAPI(logMessage, endpoint: "journeys")
        }
        
        LogManager.shared.logAPI("获取到 \(response.journeys.count) 条路线", endpoint: "journeys")
        
        return response
    }
    
    // 根据经纬度搜索路线
    func searchRouteByCoordinates(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, numResults: Int = 3) async throws -> (journeys: JourneysResponse, fromStop: TransitStop, toStop: TransitStop) {
        // 查找起点附近的站点
        let fromStops = try await findNearestStops(latitude: fromLat, longitude: fromLon)
        guard let fromStop = fromStops.first else {
            throw TransitError.noNearbyStops(location: "起点")
        }
        
        // 查找终点附近的站点
        let toStops = try await findNearestStops(latitude: toLat, longitude: toLon)
        guard let toStop = toStops.first else {
            throw TransitError.noNearbyStops(location: "终点")
        }
        
        // 搜索路线
        let journeys = try await searchJourney(fromStopId: fromStop.id, toStopId: toStop.id, results: numResults)
        
        return (journeys, fromStop, toStop)
    }
    
    // 提取路线坐标并生成GeoJSON（增强版，包含交通类型）
    func extractRouteGeoJSON(from journey: Journey) -> GeoJSONFeatureCollection {
        var features: [GeoJSONFeature] = []
        var lineCoordinates: [[Double]] = []
        var isFirstLeg = true
        var isLastLeg = false
        
        for (legIndex, leg) in journey.legs.enumerated() {
            isLastLeg = (legIndex == journey.legs.count - 1)
            
            // 获取交通类型
            let transitType = leg.walking ?? false ? "walking" : (leg.line?.mode ?? "bus").lowercased()
            
            // 起点（只在第一段标记为origin）
            if let location = leg.origin.location,
               let lat = location.latitude,
               let lon = location.longitude {
                var properties: [String: String?] = [
                    "name": leg.origin.name ?? "Unknown",
                    "type": isFirstLeg ? "origin" : "stopover",
                    "transit_type": transitType
                ]
                
                if let dep = leg.departure {
                    properties["departure"] = dep
                }
                
                let feature = GeoJSONFeature(
                    geometry: .point(coordinates: [lon, lat]),
                    properties: properties
                )
                features.append(feature)
                lineCoordinates.append([lon, lat])
                
                isFirstLeg = false
            }
            
            // 途经站点
            if let stopovers = leg.stopovers {
                for stopover in stopovers {
                    if let stop = stopover.stop,
                       let location = stop.location,
                       let lat = location.latitude,
                       let lon = location.longitude {
                        var properties: [String: String?] = [
                            "name": stop.name ?? "Unknown",
                            "type": "stopover",
                            "transit_type": transitType
                        ]
                        
                        if let arrival = stopover.arrival {
                            properties["arrival"] = arrival
                        }
                        if let departure = stopover.departure {
                            properties["departure"] = departure
                        }
                        
                        let feature = GeoJSONFeature(
                            geometry: .point(coordinates: [lon, lat]),
                            properties: properties
                        )
                        features.append(feature)
                        lineCoordinates.append([lon, lat])
                    }
                }
            }
            
            // 终点（只在最后一段标记为destination）
            if let location = leg.destination.location,
               let lat = location.latitude,
               let lon = location.longitude {
                var properties: [String: String?] = [
                    "name": leg.destination.name ?? "Unknown",
                    "type": isLastLeg ? "destination" : "stopover",
                    "transit_type": transitType
                ]
                
                if let arr = leg.arrival {
                    properties["arrival"] = arr
                }
                
                let feature = GeoJSONFeature(
                    geometry: .point(coordinates: [lon, lat]),
                    properties: properties
                )
                features.append(feature)
                lineCoordinates.append([lon, lat])
            }
        }
        
        // 添加线路（整条路线）
        if lineCoordinates.count > 1 {
            let lineFeature = GeoJSONFeature(
                geometry: .lineString(coordinates: lineCoordinates),
                properties: ["name": "Route", "type": "route"] as [String: String?]
            )
            features.append(lineFeature)
        }
        
        return GeoJSONFeatureCollection(features: features)
    }
    
    // 格式化路线信息（增强版，包含时刻表）
    func formatRouteInfo(journey: Journey, fromStop: TransitStop, toStop: TransitStop) -> String {
        var result = "🚊 路线信息\n"
        result += "起点: \(fromStop.name) (距离: \(Int(fromStop.distance ?? 0))m)\n"
        result += "终点: \(toStop.name) (距离: \(Int(toStop.distance ?? 0))m)\n\n"
        
        // 从legs中获取时间
        var departureTime: String? = nil
        var arrivalTime: String? = nil
        
        if let firstLeg = journey.legs.first {
            departureTime = firstLeg.departure
            print("formatRouteInfo - 第一段departure: \(departureTime ?? "nil")")
        }
        
        if let lastLeg = journey.legs.last {
            arrivalTime = lastLeg.arrival
            print("formatRouteInfo - 最后段arrival: \(arrivalTime ?? "nil")")
        }
        
        // 使用journey级别的时间，如果没有则使用leg级别的时间
        let finalDeparture = journey.departure ?? departureTime
        let finalArrival = journey.arrival ?? arrivalTime
        
        print("formatRouteInfo - 最终时间: departure=\(finalDeparture ?? "nil"), arrival=\(finalArrival ?? "nil")")
        LogManager.shared.logTool("formatRouteInfo - 最终时间: departure=\(finalDeparture ?? "nil"), arrival=\(finalArrival ?? "nil")", toolName: "search_transit_route")
        
        if let departure = finalDeparture,
           let arrival = finalArrival {
            let formatter = ISO8601DateFormatter()
            if let depTime = formatter.date(from: departure),
               let arrTime = formatter.date(from: arrival) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                
                result += "出发时间: \(timeFormatter.string(from: depTime))\n"
                result += "到达时间: \(timeFormatter.string(from: arrTime))\n"
                
                let duration = arrTime.timeIntervalSince(depTime)
                let minutes = Int(duration / 60)
                let hours = minutes / 60
                let mins = minutes % 60
                
                if hours > 0 {
                    result += "行程时间: \(hours)小时\(mins)分钟\n"
                } else {
                    result += "行程时间: \(mins)分钟\n"
                }
            }
        }
        
        // 计算换乘次数
        let transfers = journey.legs.filter { !($0.walking ?? false) }.count - 1
        result += "换乘: \(max(0, transfers))次\n\n"
        
        result += "路线详情:\n"
        let formatter = ISO8601DateFormatter()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone.current
        
        for (index, leg) in journey.legs.enumerated() {
            if leg.walking ?? false {
                result += "\(index + 1). 🚶 步行 \(leg.distance ?? 0)米"
                
                // 显示步行时间
                if let dep = leg.departure, let arr = leg.arrival,
                   let depTime = formatter.date(from: dep),
                   let arrTime = formatter.date(from: arr) {
                    let walkMinutes = Int(arrTime.timeIntervalSince(depTime) / 60)
                    result += " (约\(walkMinutes)分钟)"
                }
                result += "\n"
                
            } else {
                let lineName = leg.line?.name ?? "未知线路"
                let lineMode = leg.line?.mode ?? ""
                let origin = leg.origin.name ?? "未知站点"
                let destination = leg.destination.name ?? "未知站点"
                
                // 根据交通方式添加图标
                let icon = getTransitIcon(mode: lineMode)
                
                result += "\(index + 1). \(icon) \(lineName)\n"
                result += "   从: \(origin)"
                
                // 添加出发时间
                if let dep = leg.departure,
                   let depTime = formatter.date(from: dep) {
                    result += " [\(timeFormatter.string(from: depTime))]"
                }
                
                result += "\n   到: \(destination)"
                
                // 添加到达时间
                if let arr = leg.arrival,
                   let arrTime = formatter.date(from: arr) {
                    result += " [\(timeFormatter.string(from: arrTime))]"
                }
                
                // 显示途经站数
                if let stopovers = leg.stopovers, !stopovers.isEmpty {
                    result += "\n   途经 \(stopovers.count) 站"
                }
                
                result += "\n"
            }
        }
        
        return result
    }
    
    // 根据交通方式返回对应图标
    private func getTransitIcon(mode: String) -> String {
        switch mode.lowercased() {
        case "bus":
            return "🚌"
        case "tram", "streetcar":
            return "🚊"
        case "subway", "metro", "underground":
            return "🚇"
        case "train", "railway":
            return "🚆"
        case "ferry", "boat":
            return "⛴️"
        default:
            return "🚌"
        }
    }
}

// MARK: - 错误定义

enum TransitError: LocalizedError {
    case noNearbyStops(location: String)
    case noRouteFound
    case invalidCoordinates
    
    var errorDescription: String? {
        switch self {
        case .noNearbyStops(let location):
            return "\(location)附近未找到公共交通站点"
        case .noRouteFound:
            return "未找到可用路线"
        case .invalidCoordinates:
            return "无效的坐标"
        }
    }
}