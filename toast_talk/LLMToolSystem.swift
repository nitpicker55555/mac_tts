//
//  LLMToolSystem.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation

// MARK: - Tool协议和基础结构

protocol LLMTool {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Any] { get }
    
    func execute(parameters: [String: Any]) async throws -> Any
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

struct ToolResponse: Codable {
    let toolCallId: String
    let content: String
}

// MARK: - 交通路线搜索工具

class TransitRouteTool: LLMTool {
    // 静态属性用于存储完整的路线数据
    static var lastFullJourneys: [[String: Any]] = []
    
    let name = "search_transit_route"
    let description = "搜索两点之间的公共交通路线"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "from_latitude": [
                "type": "number",
                "description": "起点纬度"
            ],
            "from_longitude": [
                "type": "number",
                "description": "起点经度"
            ],
            "to_latitude": [
                "type": "number",
                "description": "终点纬度"
            ],
            "to_longitude": [
                "type": "number",
                "description": "终点经度"
            ],
            "num_results": [
                "type": "integer",
                "description": "返回的路线数量",
                "default": 3
            ]
        ],
        "required": ["from_latitude", "from_longitude", "to_latitude", "to_longitude"]
    ]
    
    func execute(parameters: [String: Any]) async throws -> Any {
        guard var fromLat = parameters["from_latitude"] as? Double,
              var fromLon = parameters["from_longitude"] as? Double,
              var toLat = parameters["to_latitude"] as? Double,
              var toLon = parameters["to_longitude"] as? Double else {
            throw ToolError.invalidParameters
        }
        
        let numResults = parameters["num_results"] as? Int ?? 3
        
        // 记录工具调用
        LogManager.shared.logTool("开始执行交通路线搜索", toolName: "search_transit_route")
        LogManager.shared.logTool("参数: 起点(\(fromLat), \(fromLon)), 终点(\(toLat), \(toLon)), 结果数: \(numResults)", toolName: "search_transit_route")
        
        // 检查是否需要获取当前位置
        if fromLat == -999 && fromLon == -999 {
            print("检测到当前位置请求（起点）")
            LogManager.shared.logTool("检测到当前位置请求（起点）", toolName: "search_transit_route")
            do {
                let location = try await LocationService.shared.getCurrentLocation()
                fromLat = location.coordinate.latitude
                fromLon = location.coordinate.longitude
                print("获取到当前位置: \(fromLat), \(fromLon)")
                LogManager.shared.logTool("获取到当前位置: \(fromLat), \(fromLon)", toolName: "search_transit_route")
            } catch {
                LogManager.shared.logError("获取当前位置失败: \(error.localizedDescription)", category: .tool)
                throw ToolError.executionFailed(reason: "获取当前位置失败: \(error.localizedDescription)")
            }
        }
        
        if toLat == -999 && toLon == -999 {
            print("检测到当前位置请求（终点）")
            LogManager.shared.logTool("检测到当前位置请求（终点）", toolName: "search_transit_route")
            do {
                let location = try await LocationService.shared.getCurrentLocation()
                toLat = location.coordinate.latitude
                toLon = location.coordinate.longitude
                print("获取到当前位置: \(toLat), \(toLon)")
                LogManager.shared.logTool("获取到当前位置: \(toLat), \(toLon)", toolName: "search_transit_route")
            } catch {
                LogManager.shared.logError("获取当前位置失败: \(error.localizedDescription)", category: .tool)
                throw ToolError.executionFailed(reason: "获取当前位置失败: \(error.localizedDescription)")
            }
        }
        
        do {
            let result = try await TransitRouteService.shared.searchRouteByCoordinates(
                fromLat: fromLat,
                fromLon: fromLon,
                toLat: toLat,
                toLon: toLon,
                numResults: numResults
            )
            
            var response: [String: Any] = [:]
            response["from_stop"] = [
                "name": result.fromStop.name,
                "distance": result.fromStop.distance ?? 0,
                "coordinates": ["lat": fromLat, "lon": fromLon]
            ]
            response["to_stop"] = [
                "name": result.toStop.name,
                "distance": result.toStop.distance ?? 0,
                "coordinates": ["lat": toLat, "lon": toLon]
            ]
            
            var journeys: [[String: Any]] = []
            
            for (index, journey) in result.journeys.journeys.prefix(numResults).enumerated() {
                let geoJSON = TransitRouteService.shared.extractRouteGeoJSON(from: journey)
                let routeInfo = TransitRouteService.shared.formatRouteInfo(
                    journey: journey,
                    fromStop: result.fromStop,
                    toStop: result.toStop
                )
                
                // 转换GeoJSON为字典
                let encoder = JSONEncoder()
                let geoJSONData = try encoder.encode(geoJSON)
                let geoJSONDict = try JSONSerialization.jsonObject(with: geoJSONData) as? [String: Any]
                
                // 获取第一个和最后一个leg的时间
                var departureTime = ""
                var arrivalTime = ""
                
                if let firstLeg = journey.legs.first {
                    departureTime = firstLeg.departure ?? ""
                    print("LLMTool - Journey \(index) 第一段时间: \(departureTime)")
                    LogManager.shared.logTool("Journey \(index) 第一段时间: \(departureTime)", toolName: "search_transit_route")
                }
                
                if let lastLeg = journey.legs.last {
                    arrivalTime = lastLeg.arrival ?? ""
                    print("LLMTool - Journey \(index) 最后段时间: \(arrivalTime)")
                    LogManager.shared.logTool("Journey \(index) 最后段时间: \(arrivalTime)", toolName: "search_transit_route")
                }
                
                // 如果leg级别没有，尝试journey级别
                if departureTime.isEmpty {
                    departureTime = journey.departure ?? ""
                    print("LLMTool - 使用journey级别departure: \(departureTime)")
                    LogManager.shared.logTool("使用journey级别departure: \(departureTime)", toolName: "search_transit_route")
                }
                
                if arrivalTime.isEmpty {
                    arrivalTime = journey.arrival ?? ""
                    print("LLMTool - 使用journey级别arrival: \(arrivalTime)")
                    LogManager.shared.logTool("使用journey级别arrival: \(arrivalTime)", toolName: "search_transit_route")
                }
                
                // 创建legs数组，包含经停站信息
                var legsData: [[String: Any]] = []
                
                for leg in journey.legs {
                    var legData: [String: Any] = [
                        "walking": leg.walking ?? false,
                        "distance": leg.distance ?? 0,
                        "origin": [
                            "name": leg.origin.name ?? "",
                            "location": [
                                "lat": leg.origin.location?.latitude ?? 0,
                                "lon": leg.origin.location?.longitude ?? 0
                            ]
                        ],
                        "destination": [
                            "name": leg.destination.name ?? "",
                            "location": [
                                "lat": leg.destination.location?.latitude ?? 0,
                                "lon": leg.destination.location?.longitude ?? 0
                            ]
                        ]
                    ]
                    
                    if let line = leg.line {
                        legData["line"] = [
                            "name": line.name ?? "",
                            "mode": line.mode ?? ""
                        ]
                    }
                    
                    if let departure = leg.departure {
                        legData["departure"] = departure
                    }
                    
                    if let arrival = leg.arrival {
                        legData["arrival"] = arrival
                    }
                    
                    // 添加经停站
                    if let stopovers = leg.stopovers {
                        var stopoversList: [[String: Any]] = []
                        for stopover in stopovers {
                            var stopData: [String: Any] = [
                                "name": stopover.stop?.name ?? ""
                            ]
                            // 添加位置信息
                            if let location = stopover.stop?.location {
                                stopData["location"] = [
                                    "lat": location.latitude ?? 0,
                                    "lon": location.longitude ?? 0
                                ]
                            }
                            if let arrival = stopover.arrival {
                                stopData["arrival"] = arrival
                            }
                            if let departure = stopover.departure {
                                stopData["departure"] = departure
                            }
                            stopoversList.append(stopData)
                        }
                        legData["stopovers"] = stopoversList
                    }
                    
                    legsData.append(legData)
                }
                
                journeys.append([
                    "index": index,
                    "route_info": routeInfo,
                    "geojson": geoJSONDict ?? [:],
                    "departure": departureTime,
                    "arrival": arrivalTime,
                    "legs": legsData  // 添加完整的legs数据
                ])
            }
            
            response["journeys"] = journeys
            response["total_results"] = result.journeys.journeys.count
            
            // 保存完整数据供地图使用
            TransitRouteTool.lastFullJourneys = journeys
            
            print("LLMToolSystem - 返回 journeys.count: \(journeys.count)")
            LogManager.shared.logTool("成功返回 \(journeys.count) 条路线", toolName: "search_transit_route")
            
            return response
            
        } catch {
            LogManager.shared.logError("工具执行失败: \(error.localizedDescription)", category: .tool)
            throw ToolError.executionFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - 工具管理器

class LLMToolManager {
    static let shared = LLMToolManager()
    
    private var tools: [String: LLMTool] = [:]
    
    private init() {
        registerDefaultTools()
    }
    
    private func registerDefaultTools() {
        let transitTool = TransitRouteTool()
        tools[transitTool.name] = transitTool
    }
    
    func registerTool(_ tool: LLMTool) {
        tools[tool.name] = tool
    }
    
    func getTool(name: String) -> LLMTool? {
        return tools[name]
    }
    
    func getAllTools() -> [LLMTool] {
        return Array(tools.values)
    }
    
    func getToolDescriptions() -> [[String: Any]] {
        return tools.values.map { tool in
            return [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters
                ]
            ]
        }
    }
    
    func executeToolCall(_ toolCall: ToolCall) async throws -> ToolResponse {
        guard let tool = getTool(name: toolCall.function.name) else {
            throw ToolError.toolNotFound(name: toolCall.function.name)
        }
        
        // 解析参数
        guard let argumentsData = toolCall.function.arguments.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            throw ToolError.invalidArguments
        }
        
        // 执行工具
        let result = try await tool.execute(parameters: parameters)
        
        // 对路线搜索工具的结果进行特殊处理
        var processedResult = result
        if toolCall.function.name == "search_transit_route",
           let resultDict = result as? [String: Any] {
            processedResult = simplifyTransitRouteResult(resultDict)
        }
        
        // 将结果转换为JSON字符串
        let resultData = try JSONSerialization.data(withJSONObject: processedResult)
        let resultString = String(data: resultData, encoding: .utf8) ?? "{}"
        
        return ToolResponse(toolCallId: toolCall.id, content: resultString)
    }
    
    // 简化路线搜索结果，避免消息历史过大
    private func simplifyTransitRouteResult(_ result: [String: Any]) -> [String: Any] {
        guard let journeys = result["journeys"] as? [[String: Any]] else {
            return result
        }
        
        var simplifiedJourneys: [[String: Any]] = []
        for journey in journeys {
            var simplified: [String: Any] = [
                "route_info": journey["route_info"] as? String ?? "",
                "departure": journey["departure"] as? String ?? "",
                "arrival": journey["arrival"] as? String ?? ""
            ]
            
            // 只包含简化的legs信息
            if let legs = journey["legs"] as? [[String: Any]] {
                var legsInfo: [String] = []
                for leg in legs {
                    if let walking = leg["walking"] as? Bool, walking {
                        legsInfo.append("步行")
                    } else if let line = leg["line"] as? [String: Any],
                              let name = line["name"] as? String {
                        legsInfo.append(name)
                    }
                }
                simplified["transport_modes"] = legsInfo
            }
            
            simplifiedJourneys.append(simplified)
        }
        
        return [
            "status": result["status"] as? String ?? "success",
            "message": result["message"] as? String ?? "",
            "total_results": result["total_results"] as? Int ?? 0,
            "journeys": simplifiedJourneys
        ]
    }
}

// MARK: - 错误定义

enum ToolError: LocalizedError {
    case toolNotFound(name: String)
    case invalidParameters
    case invalidArguments
    case executionFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "工具未找到: \(name)"
        case .invalidParameters:
            return "无效的参数"
        case .invalidArguments:
            return "无效的参数格式"
        case .executionFailed(let reason):
            return "工具执行失败: \(reason)"
        }
    }
}