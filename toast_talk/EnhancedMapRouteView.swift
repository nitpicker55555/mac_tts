//
//  EnhancedMapRouteView.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI
import MapKit

// MARK: - 增强版地图路线视图

struct EnhancedMapRouteView: View {
    let journeys: [[String: Any]]
    var initialSelectedIndex: Int = 0
    
    @State private var selectedJourneyIndex: Int? = nil
    @State private var expandedJourneyIndex: Int? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var routeSegments: [RouteSegment] = []
    @State private var mapAnnotations: [EnhancedMapAnnotation] = []
    @State private var refreshID = UUID() // 添加刷新ID
    @State private var journeyInfos: [JourneyInfo] = []
    @State private var focusedLegIndex: Int? = nil  // 新增：聚焦的路段索引
    @State private var windowPosition = CGPoint.zero  // 新增：窗口位置
    @State private var isDragging = false  // 新增：拖拽状态
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 底层：地图全屏显示
            EnhancedMapKitView(
                region: $region,
                annotations: mapAnnotations,
                routeSegments: routeSegments
            )
            .id(refreshID)
            .edgesIgnoringSafeArea(.all)
            
            // 浮层：左侧方案卡片列表
            VStack(alignment: .leading, spacing: 12) {
                Text("路线方案")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<min(3, journeys.count), id: \.self) { index in
                            JourneyCard(
                                journey: journeys[index],
                                journeyInfo: index < journeyInfos.count ? journeyInfos[index] : nil,
                                index: index,
                                isSelected: selectedJourneyIndex == index,
                                isExpanded: expandedJourneyIndex == index,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedJourneyIndex = index
                                        focusedLegIndex = nil
                                        loadSelectedJourney()
                                    }
                                },
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if expandedJourneyIndex == index {
                                            expandedJourneyIndex = nil
                                        } else {
                                            expandedJourneyIndex = index
                                            selectedJourneyIndex = index
                                            focusedLegIndex = nil
                                            loadSelectedJourney()
                                        }
                                    }
                                },
                                onLegTap: { legIndex in
                                    focusOnLeg(journeyIndex: index, legIndex: legIndex)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .frame(width: 350)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)  // 毛玻璃效果
            .mask(
                RoundedRectangle(cornerRadius: 0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .offset(x: -12)
                    )
            )
            .shadow(radius: 10)
        }
        .frame(minWidth: 900, idealWidth: 900, maxWidth: .infinity, minHeight: 700, idealHeight: 700, maxHeight: .infinity)
        .onAppear {
            parseAllJourneys()
            if initialSelectedIndex < journeys.count {
                selectedJourneyIndex = initialSelectedIndex
                expandedJourneyIndex = initialSelectedIndex
                loadSelectedJourney()
            }
        }
    }
    
    private func loadSelectedJourney() {
        guard let index = selectedJourneyIndex,
              index < journeys.count,
              let geoJSONDict = journeys[index]["geojson"] as? [String: Any] else {
            return
        }
        
        print("加载方案 \(index + 1):")
        if let routeInfo = journeys[index]["route_info"] as? String {
            print("路线信息: \(routeInfo.prefix(100))...")
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: geoJSONDict)
            let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: jsonData)
            parseGeoJSONWithTransitInfo(geoJSON)
        } catch let error as DecodingError {
            print("解码GeoJSON失败: \(error)")
            switch error {
            case .dataCorrupted(let context):
                print("数据损坏: \(context)")
            case .keyNotFound(let key, let context):
                print("缺少键: \(key), 上下文: \(context)")
            case .typeMismatch(let type, let context):
                print("类型不匹配: \(type), 上下文: \(context)")
            case .valueNotFound(let type, let context):
                print("值未找到: \(type), 上下文: \(context)")
            @unknown default:
                print("未知解码错误")
            }
        } catch {
            print("解析GeoJSON失败: \(error)")
        }
    }
    
    private func focusOnLeg(journeyIndex: Int, legIndex: Int) {
        guard journeyIndex < journeys.count,
              let legs = journeys[journeyIndex]["legs"] as? [[String: Any]],
              legIndex < legs.count else { return }
        
        let leg = legs[legIndex]
        var coordinates: [CLLocationCoordinate2D] = []
        
        // 收集路段的所有坐标点
        if let origin = leg["origin"] as? [String: Any],
           let location = origin["location"] as? [String: Any],
           let lat = location["latitude"] as? Double,
           let lng = location["longitude"] as? Double {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        if let destination = leg["destination"] as? [String: Any],
           let location = destination["location"] as? [String: Any],
           let lat = location["latitude"] as? Double,
           let lng = location["longitude"] as? Double {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        // 如果有经停站，也加入计算
        if let stopovers = leg["stopovers"] as? [[String: Any]] {
            for stopover in stopovers {
                if let location = stopover["location"] as? [String: Any],
                   let lat = location["latitude"] as? Double,
                   let lng = location["longitude"] as? Double {
                    coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                }
            }
        }
        
        // 计算包含所有点的区域
        if !coordinates.isEmpty {
            var minLat = coordinates[0].latitude
            var maxLat = coordinates[0].latitude
            var minLon = coordinates[0].longitude
            var maxLon = coordinates[0].longitude
            
            for coord in coordinates {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }
            
            // 计算偏移后的中心点
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let lonOffset = (maxLon - minLon) * 0.25  // 向右偏移
            
            let center = CLLocationCoordinate2D(
                latitude: centerLat,
                longitude: centerLon + lonOffset
            )
            
            // 计算合适的缩放级别
            let latDelta = (maxLat - minLat) * 2.5
            let lonDelta = (maxLon - minLon) * 3.0  // 增加横向范围
            
            // 确保最小缩放级别
            let span = MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.01),
                longitudeDelta: max(lonDelta, 0.01)
            )
            
            withAnimation(.easeInOut(duration: 0.5)) {
                self.region = MKCoordinateRegion(center: center, span: span)
                self.focusedLegIndex = legIndex
            }
        }
    }
    
    private func parseAllJourneys() {
        var infos: [JourneyInfo] = []
        
        for journey in journeys {
            var info = JourneyInfo()
            
            // 解析时间
            if let departure = journey["departure"] as? String,
               let arrival = journey["arrival"] as? String {
                info.departureTime = formatTime(departure)
                info.arrivalTime = formatTime(arrival)
                info.duration = calculateDuration(from: departure, to: arrival)
            }
            
            // 解析交通线路
            if let legs = journey["legs"] as? [[String: Any]] {
                var transitLines: [TransitLineInfo] = []
                var addedLines = Set<String>()  // 避免重复
                
                for leg in legs {
                    if let walking = leg["walking"] as? Bool, walking {
                        // 跳过步行段，不显示步行标签
                        continue
                    } else if let line = leg["line"] as? [String: Any] {
                        let mode = line["mode"] as? String ?? ""
                        let lineName = line["name"] as? String ?? "未知线路"
                        
                        var transitType: TransitType
                        switch mode.lowercased() {
                        case "bus":
                            transitType = .bus
                        case "tram", "streetcar":
                            transitType = .tram
                        case "subway", "metro", "u-bahn", "s-bahn":
                            transitType = .subway
                        case "train", "railway":
                            transitType = .train
                        default:
                            transitType = .bus
                        }
                        
                        let transitLine = TransitLineInfo(name: lineName, type: transitType)
                        if !addedLines.contains(transitLine.name) {
                            transitLines.append(transitLine)
                            addedLines.insert(transitLine.name)
                        }
                    }
                }
                
                info.transitLines = transitLines
                info.legCount = legs.count
            }
            
            infos.append(info)
        }
        
        self.journeyInfos = infos
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: isoString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                return timeFormatter.string(from: date)
            }
        }
        
        return "--:--"
    }
    
    private func calculateDuration(from departure: String, to arrival: String) -> String {
        var depTime: Date?
        var arrTime: Date?
        
        let formatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if depTime == nil {
                depTime = formatter.date(from: departure)
            }
            if arrTime == nil {
                arrTime = formatter.date(from: arrival)
            }
            if depTime != nil && arrTime != nil {
                break
            }
        }
        
        if let depTime = depTime, let arrTime = arrTime {
            let duration = arrTime.timeIntervalSince(depTime)
            let minutes = Int(duration / 60)
            let hours = minutes / 60
            let mins = minutes % 60
            
            if hours > 0 {
                return "\(hours)小时\(mins)分钟"
            } else {
                return "\(mins)分钟"
            }
        }
        return "--"
    }
    
    private func parseGeoJSONWithTransitInfo(_ geoJSON: GeoJSONFeatureCollection) {
        var annotations: [EnhancedMapAnnotation] = []
        var segments: [RouteSegment] = []
        var currentSegmentCoords: [CLLocationCoordinate2D] = []
        var currentTransitType: TransitType = .unknown
        var segmentStartIndex = 0
        
        // 处理每个feature
        for (index, feature) in geoJSON.features.enumerated() {
            switch feature.geometry {
            case .point(let coords):
                if coords.count >= 2 {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: coords[1],
                        longitude: coords[0]
                    )
                    
                    // 创建增强的注释
                    let annotation = EnhancedMapAnnotation(
                        coordinate: coordinate,
                        title: feature.properties["name"] as? String ?? "Unknown",
                        type: feature.properties["type"] as? String ?? "point",
                        arrival: feature.properties["arrival"] as? String,
                        departure: feature.properties["departure"] as? String
                    )
                    annotations.append(annotation)
                    currentSegmentCoords.append(coordinate)
                    
                    // 检测交通工具变化
                    if let transitInfo = feature.properties["transit_type"] as? String {
                        let newType = TransitType(from: transitInfo)
                        if newType != currentTransitType && !currentSegmentCoords.isEmpty {
                            // 保存当前段
                            if currentSegmentCoords.count > 1 {
                                segments.append(RouteSegment(
                                    coordinates: currentSegmentCoords,
                                    transitType: currentTransitType
                                ))
                            }
                            // 开始新段
                            currentSegmentCoords = [coordinate]
                            currentTransitType = newType
                        }
                    }
                }
                
            case .lineString:
                // 处理整条线路
                break
            }
        }
        
        // 保存最后一段
        if currentSegmentCoords.count > 1 {
            segments.append(RouteSegment(
                coordinates: currentSegmentCoords,
                transitType: currentTransitType
            ))
        }
        
        // 如果没有分段信息，创建默认路线
        if segments.isEmpty && !annotations.isEmpty {
            let allCoords = annotations.map { $0.coordinate }
            segments.append(RouteSegment(coordinates: allCoords, transitType: .bus))
        }
        
        // 更新状态
        self.mapAnnotations = annotations
        self.routeSegments = segments
        self.refreshID = UUID() // 触发地图刷新
        
        // 计算地图区域
        updateMapRegion()
    }
    
    private func updateMapRegion() {
        guard !mapAnnotations.isEmpty else { return }
        
        let coordinates = mapAnnotations.map { $0.coordinate }
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        // 计算中心点，但偏移到右侧以避免被左侧面板遮挡
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let lonOffset = (maxLon - minLon) * 0.25  // 向右偏移25%
        
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: centerLon + lonOffset
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 2.0  // 增加横向范围以显示完整路线
        )
        
        self.region = MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - 路线信息结构

struct JourneyInfo {
    var departureTime: String = "--:--"
    var arrivalTime: String = "--:--"
    var duration: String = "--"
    var transitModes: [String] = []
    var transitLines: [TransitLineInfo] = []  // 新增：线路信息数组
    var legCount: Int = 0
}

// MARK: - 交通线路信息

struct TransitLineInfo: Hashable {
    let name: String
    let type: TransitType
    
    var color: Color {
        type.color
    }
}

// MARK: - 方案卡片视图

struct JourneyCard: View {
    let journey: [String: Any]
    let journeyInfo: JourneyInfo?
    let index: Int
    let isSelected: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpand: () -> Void
    let onLegTap: (Int) -> Void  // 新增：路段点击回调
    
    @State private var legDetails: [LegDetail] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片头部
            Button(action: onToggleExpand) {
                VStack(alignment: .leading, spacing: 8) {
                    // 方案标题
                    HStack {
                        Text("方案 \(index + 1)")
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                    
                    // 时间信息
                    if let info = journeyInfo {
                        HStack {
                            Text(info.departureTime)
                                .font(.system(size: 14, weight: .medium))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                            
                            Text(info.arrivalTime)
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            Text(info.duration)
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .foregroundColor(isSelected ? .white : .primary)
                        
                        // 交通线路标签
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(info.transitLines, id: \.self) { line in
                                    Text(line.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(line.color)
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Text("\(info.legCount) 段路程")
                                    .font(.system(size: 11))
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(isSelected ? Color.accentColor.opacity(0.8) : Color.clear)
                .background(.ultraThinMaterial)  // 毛玻璃效果
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的路线详情
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(legDetails.indices, id: \.self) { legIndex in
                        RouteSegmentCard(
                            legDetail: legDetails[legIndex],
                            isFirst: legIndex == 0,
                            isLast: legIndex == legDetails.count - 1,
                            journeyData: journey,
                            legIndex: legIndex,
                            onTap: {
                                onLegTap(legIndex)
                            }
                        )
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if isExpanded && legDetails.isEmpty {
                parseLegDetails()
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded && legDetails.isEmpty {
                parseLegDetails()
            }
        }
    }
    
    private func parseLegDetails() {
        if let legs = journey["legs"] as? [[String: Any]], !legs.isEmpty {
            parseFromLegs(legs)
        } else if let routeInfo = journey["route_info"] as? String {
            parseFromRouteInfo(routeInfo)
        }
    }
    
    private func parseFromLegs(_ legs: [[String: Any]]) {
        var details: [LegDetail] = []
        
        for leg in legs {
            var legDetail = LegDetail()
            
            // 解析基本信息
            if let walking = leg["walking"] as? Bool, walking {
                legDetail.type = .walking
                legDetail.icon = "🚶"
                legDetail.lineName = "步行"
                
                if let distance = leg["distance"] as? Int {
                    legDetail.distance = "\(distance)米"
                    let minutes = max(1, distance / 80)
                    legDetail.duration = "\(minutes)分钟"
                }
            } else if let line = leg["line"] as? [String: Any] {
                let mode = line["mode"] as? String ?? ""
                legDetail.lineName = line["name"] as? String ?? "未知线路"
                
                switch mode.lowercased() {
                case "bus":
                    legDetail.type = .bus
                    legDetail.icon = "🚌"
                case "tram", "streetcar":
                    legDetail.type = .tram
                    legDetail.icon = "🚊"
                case "subway", "metro", "u-bahn", "s-bahn":
                    legDetail.type = .subway
                    legDetail.icon = "🚇"
                case "train", "railway":
                    legDetail.type = .train
                    legDetail.icon = "🚆"
                default:
                    legDetail.type = .bus
                    legDetail.icon = "🚌"
                }
            }
            
            // 解析起点和终点
            if let origin = leg["origin"] as? [String: Any] {
                legDetail.origin = origin["name"] as? String ?? "未知起点"
            }
            
            if let destination = leg["destination"] as? [String: Any] {
                legDetail.destination = destination["name"] as? String ?? "未知终点"
            }
            
            // 解析时间
            if let departure = leg["departure"] as? String {
                legDetail.departureTime = formatTimeString(departure)
            }
            
            if let arrival = leg["arrival"] as? String {
                legDetail.arrivalTime = formatTimeString(arrival)
            }
            
            // 解析经停站
            if let stopovers = leg["stopovers"] as? [[String: Any]] {
                var stopoversList: [StopoverInfo] = []
                for stopover in stopovers {
                    let name = stopover["name"] as? String ?? "未知站点"
                    var time: String? = nil
                    
                    if let departure = stopover["departure"] as? String {
                        time = formatTimeString(departure)
                    } else if let arrival = stopover["arrival"] as? String {
                        time = formatTimeString(arrival)
                    }
                    
                    stopoversList.append(StopoverInfo(name: name, time: time))
                }
                legDetail.stopovers = stopoversList
                legDetail.stops = stopoversList.count
            }
            
            details.append(legDetail)
        }
        
        self.legDetails = details
    }
    
    private func parseFromRouteInfo(_ routeInfo: String) {
        // 降级方案：从路线信息字符串解析
        // ... (保留原有的解析逻辑)
    }
    
    private func formatTimeString(_ isoString: String) -> String {
        let formatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: isoString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                return timeFormatter.string(from: date)
            }
        }
        
        return isoString
    }
}

// MARK: - 时间信息卡片

struct TimeInfoCard: View {
    let departure: String
    let arrival: String
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("出发")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTime(departure))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text("到达")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTime(arrival))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("行程时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(calculateDuration(from: departure, to: arrival))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func formatTime(_ isoString: String) -> String {
        // 尝试多种ISO8601格式
        let formatters = [
            ISO8601DateFormatter(), // 标准格式
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: isoString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                return timeFormatter.string(from: date)
            }
        }
        
        // 如果ISO8601失败，尝试普通DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = dateFormatter.date(from: isoString) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.timeZone = TimeZone.current
            return timeFormatter.string(from: date)
        }
        
        return "--:--"
    }
    
    private func calculateDuration(from departure: String, to arrival: String) -> String {
        // 使用相同的格式化逻辑
        var depTime: Date?
        var arrTime: Date?
        
        let formatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if depTime == nil {
                depTime = formatter.date(from: departure)
            }
            if arrTime == nil {
                arrTime = formatter.date(from: arrival)
            }
            if depTime != nil && arrTime != nil {
                break
            }
        }
        
        if let depTime = depTime, let arrTime = arrTime {
            let duration = arrTime.timeIntervalSince(depTime)
            let minutes = Int(duration / 60)
            let hours = minutes / 60
            let mins = minutes % 60
            
            if hours > 0 {
                return "\(hours)小时\(mins)分钟"
            } else {
                return "\(mins)分钟"
            }
        }
        return "--"
    }
}

// MARK: - 路线图例

struct RouteLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图例")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(TransitType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(type.color)
                            .frame(width: 20, height: 3)
                        Text(type.name)
                            .font(.caption)
                    }
                }
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("📍")
                        .font(.caption)
                    Text("起点")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Text("🎯")
                        .font(.caption)
                    Text("终点")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Text("⏹")
                        .font(.caption)
                    Text("途经站")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - 交通类型

enum TransitType: CaseIterable {
    case walking
    case bus
    case tram
    case subway
    case train
    case unknown
    
    init(from string: String) {
        switch string.lowercased() {
        case "walking", "walk":
            self = .walking
        case "bus":
            self = .bus
        case "tram", "streetcar":
            self = .tram
        case "subway", "metro", "u-bahn", "s-bahn":
            self = .subway
        case "train", "railway":
            self = .train
        default:
            self = .unknown
        }
    }
    
    var color: Color {
        switch self {
        case .walking:
            return Color(NSColor.systemGray)
        case .bus:
            return Color(NSColor.systemBlue)
        case .tram:
            return Color(NSColor.systemOrange)
        case .subway:
            return Color(NSColor.systemPurple)
        case .train:
            return Color(NSColor.systemRed)
        case .unknown:
            return Color(NSColor.darkGray)
        }
    }
    
    var name: String {
        switch self {
        case .walking:
            return "步行"
        case .bus:
            return "公交"
        case .tram:
            return "有轨电车"
        case .subway:
            return "地铁"
        case .train:
            return "火车"
        case .unknown:
            return "其他"
        }
    }
}

// MARK: - 路线段

struct RouteSegment {
    let coordinates: [CLLocationCoordinate2D]
    let transitType: TransitType
}

// MARK: - 增强版地图注释

class EnhancedMapAnnotation: NSObject, MKAnnotation, Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: String
    let arrival: String?
    let departure: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String, type: String, arrival: String? = nil, departure: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.type = type
        self.arrival = arrival
        self.departure = departure
        
        // 设置副标题为时间信息
        if let dep = departure {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dep) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                self.subtitle = timeFormatter.string(from: date)
            } else {
                self.subtitle = nil
            }
        } else {
            self.subtitle = nil
        }
        
        super.init()
    }
    
    var markerColor: NSColor {
        switch type {
        case "origin":
            return .systemGreen
        case "destination":
            return .systemRed
        case "stopover":
            return .systemBlue
        default:
            return .systemGray
        }
    }
}

// MARK: - 增强版MapKit视图

struct EnhancedMapKitView: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [EnhancedMapAnnotation]
    let routeSegments: [RouteSegment]
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // 清除旧内容
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // 添加注释（直接使用EnhancedMapAnnotation）
        for annotation in annotations {
            mapView.addAnnotation(annotation)
        }
        
        // 添加路线段
        for (index, segment) in routeSegments.enumerated() {
            if segment.coordinates.count > 1 {
                let polyline = ColoredPolyline(coordinates: segment.coordinates, count: segment.coordinates.count)
                polyline.transitType = segment.transitType
                polyline.segmentIndex = index
                mapView.addOverlay(polyline)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: EnhancedMapKitView
        
        init(_ parent: EnhancedMapKitView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let enhancedAnnotation = annotation as? EnhancedMapAnnotation else {
                return nil
            }
            
            let identifier = "CustomPin"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 设置标记颜色
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = enhancedAnnotation.markerColor
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor(polyline.transitType.color)
                renderer.lineWidth = 4.0
                
                // 步行路线使用虚线
                if polyline.transitType == .walking {
                    renderer.lineDashPattern = [5, 5]
                }
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - 带颜色的折线

class ColoredPolyline: MKPolyline {
    var transitType: TransitType = .unknown
    var segmentIndex: Int = 0
}

// MARK: - 路线详情卡片(已废弃，功能移至JourneyCard)

struct RouteDetailsCards: View {
    let journeyData: [String: Any]
    
    @State private var legDetails: [LegDetail] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("路线详情")
                .font(.headline)
            
            ForEach(legDetails.indices, id: \.self) { index in
                RouteSegmentCard(
                    legDetail: legDetails[index],
                    isFirst: index == 0,
                    isLast: index == legDetails.count - 1,
                    journeyData: journeyData,
                    legIndex: index,
                    onTap: {}  // 添加空的onTap闭包
                )
            }
        }
        .onAppear {
            parseLegDetails()
        }
    }
    
    private func parseLegDetails() {
        print("解析路线详情...")
        
        // 尝试从原始数据中解析，如果没有则从格式化的路线信息解析
        if let geoJSON = journeyData["geojson"] as? [String: Any],
           parseFromGeoJSON(geoJSON) {
            print("使用 parseFromGeoJSON 解析成功")
            return
        }
        
        print("使用降级方案解析路线信息")
        
        // 从路线信息中解析详细信息（降级方案）
        guard let routeInfo = journeyData["route_info"] as? String else { return }
        
        var details: [LegDetail] = []
        
        // 解析路线信息字符串
        let lines = routeInfo.components(separatedBy: "\n")
        var currentLegIndex = -1
        
        for line in lines {
            // 查找路线段（数字开头的行）
            if let regex = try? NSRegularExpression(pattern: #"^(\d+)\.\s*(.+)$"#),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                currentLegIndex += 1
                
                if let contentRange = Range(match.range(at: 2), in: line) {
                    let content = String(line[contentRange])
                    var legDetail = LegDetail()
                    
                    // 解析步行段
                    if content.contains("🚶") {
                        legDetail.type = .walking
                        legDetail.icon = "🚶"
                        
                        if let distanceRegex = try? NSRegularExpression(pattern: #"(\d+)米"#),
                           let distanceMatch = distanceRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                           let distanceRange = Range(distanceMatch.range(at: 1), in: content) {
                            legDetail.distance = String(content[distanceRange]) + "米"
                        }
                        
                        if let timeRegex = try? NSRegularExpression(pattern: #"约(\d+)分钟"#),
                           let timeMatch = timeRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                           let timeRange = Range(timeMatch.range(at: 1), in: content) {
                            legDetail.duration = String(content[timeRange]) + "分钟"
                        }
                    
                    legDetail.lineName = "步行"
                    
                } else {
                    // 解析交通工具
                    let icons = ["🚌": TransitType.bus, "🚊": TransitType.tram, "🚇": TransitType.subway, "🚆": TransitType.train]
                    
                    for (icon, type) in icons {
                        if content.contains(icon) {
                            legDetail.type = type
                            legDetail.icon = icon
                            
                            // 提取线路名称（从icon后面到行尾）
                            let components = content.components(separatedBy: icon)
                            if components.count > 1 {
                                legDetail.lineName = components[1].trimmingCharacters(in: .whitespaces)
                            }
                            break
                        }
                    }
                }
                    
                    details.append(legDetail)
                }
            } else if currentLegIndex >= 0 && currentLegIndex < details.count {
                // 解析起点终点信息
                if line.contains("从:") {
                    if let fromRegex = try? NSRegularExpression(pattern: #"从:\s*(.+?)(?:\s*\[(.+?)\])?$"#),
                       let match = fromRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                        if let nameRange = Range(match.range(at: 1), in: line) {
                            details[currentLegIndex].origin = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                        }
                        if match.numberOfRanges > 2,
                           let timeRange = Range(match.range(at: 2), in: line) {
                            details[currentLegIndex].departureTime = String(line[timeRange])
                        }
                    }
                } else if line.contains("到:") {
                    if let toRegex = try? NSRegularExpression(pattern: #"到:\s*(.+?)(?:\s*\[(.+?)\])?$"#),
                       let match = toRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                        if let nameRange = Range(match.range(at: 1), in: line) {
                            details[currentLegIndex].destination = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                        }
                        if match.numberOfRanges > 2,
                           let timeRange = Range(match.range(at: 2), in: line) {
                            details[currentLegIndex].arrivalTime = String(line[timeRange])
                        }
                    }
                } else if line.contains("途经") {
                    if let stopsRegex = try? NSRegularExpression(pattern: #"途经\s*(\d+)\s*站"#),
                       let match = stopsRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                       let stopsRange = Range(match.range(at: 1), in: line) {
                        details[currentLegIndex].stops = Int(String(line[stopsRange])) ?? 0
                    }
                }
            }
        }
        
        self.legDetails = details
    }
    
    private func parseFromGeoJSON(_ geoJSON: [String: Any]) -> Bool {
        // 检查是否有legs数据
        guard let legs = journeyData["legs"] as? [[String: Any]], !legs.isEmpty else {
            return false
        }
        
        print("解析 legs 数据，共 \(legs.count) 段")
        if let firstLeg = legs.first,
           let lineName = (firstLeg["line"] as? [String: Any])?["name"] as? String {
            print("第一段线路: \(lineName)")
        }
        
        var details: [LegDetail] = []
        
        for leg in legs {
            var legDetail = LegDetail()
            
            // 解析基本信息
            if let walking = leg["walking"] as? Bool, walking {
                legDetail.type = .walking
                legDetail.icon = "🚶"
                legDetail.lineName = "步行"
                
                if let distance = leg["distance"] as? Int {
                    legDetail.distance = "\(distance)米"
                    let minutes = max(1, distance / 80) // 假设步行速度80米/分钟
                    legDetail.duration = "\(minutes)分钟"
                }
            } else if let line = leg["line"] as? [String: Any] {
                // 解析交通工具信息
                let mode = line["mode"] as? String ?? ""
                legDetail.lineName = line["name"] as? String ?? "未知线路"
                
                switch mode.lowercased() {
                case "bus":
                    legDetail.type = .bus
                    legDetail.icon = "🚌"
                case "tram", "streetcar":
                    legDetail.type = .tram
                    legDetail.icon = "🚊"
                case "subway", "metro", "u-bahn", "s-bahn":
                    legDetail.type = .subway
                    legDetail.icon = "🚇"
                case "train", "railway":
                    legDetail.type = .train
                    legDetail.icon = "🚆"
                default:
                    legDetail.type = .bus
                    legDetail.icon = "🚌"
                }
            }
            
            // 解析起点和终点
            if let origin = leg["origin"] as? [String: Any] {
                legDetail.origin = origin["name"] as? String ?? "未知起点"
            }
            
            if let destination = leg["destination"] as? [String: Any] {
                legDetail.destination = destination["name"] as? String ?? "未知终点"
            }
            
            // 解析时间
            if let departure = leg["departure"] as? String {
                legDetail.departureTime = formatTimeString(departure)
            }
            
            if let arrival = leg["arrival"] as? String {
                legDetail.arrivalTime = formatTimeString(arrival)
            }
            
            // 解析经停站
            if let stopovers = leg["stopovers"] as? [[String: Any]] {
                var stopoversList: [StopoverInfo] = []
                for stopover in stopovers {
                    let name = stopover["name"] as? String ?? "未知站点"
                    var time: String? = nil
                    
                    // 优先使用departure时间，如果没有则使用arrival时间
                    if let departure = stopover["departure"] as? String {
                        time = formatTimeString(departure)
                    } else if let arrival = stopover["arrival"] as? String {
                        time = formatTimeString(arrival)
                    }
                    
                    stopoversList.append(StopoverInfo(name: name, time: time))
                }
                legDetail.stopovers = stopoversList
                legDetail.stops = stopoversList.count
            }
            
            details.append(legDetail)
        }
        
        self.legDetails = details
        return true
    }
    
    private func formatTimeString(_ isoString: String) -> String {
        // 尝试多种ISO8601格式
        let formatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            { () -> ISO8601DateFormatter in
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: isoString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                return timeFormatter.string(from: date)
            }
        }
        
        // 如果ISO8601失败，尝试普通DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = dateFormatter.date(from: isoString) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.timeZone = TimeZone.current
            return timeFormatter.string(from: date)
        }
        
        return isoString // 如果都失败，返回原字符串
    }
}

// MARK: - 路线段详情

struct LegDetail {
    var type: TransitType = .unknown
    var icon: String = "🚌"
    var lineName: String = ""
    var origin: String = ""
    var destination: String = ""
    var departureTime: String?
    var arrivalTime: String?
    var distance: String?
    var duration: String?
    var stops: Int = 0
    var stopovers: [StopoverInfo] = []  // 添加经停站数组
}

// MARK: - 路线段卡片（支持展开/折叠）

struct RouteSegmentCard: View {
    let legDetail: LegDetail
    let isFirst: Bool
    let isLast: Bool
    let journeyData: [String: Any]
    let legIndex: Int
    let onTap: () -> Void  // 新增：点击回调
    
    @State private var isExpanded = false
    @State private var stopovers: [StopoverInfo] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片主体（可点击）
            Button(action: {
                // 先触发地图缩放
                onTap()
                
                // 只有在有经停站数据时才允许展开
                if !legDetail.stopovers.isEmpty || hasStoredStopovers() {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                        if isExpanded && stopovers.isEmpty {
                            loadStopovers()
                        }
                    }
                }
            }) {
                HStack {
                    // 左侧图标和线路信息
                    HStack(spacing: 12) {
                        Text(legDetail.icon)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(legDetail.lineName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                // 起点时间和站名
                                if let time = legDetail.departureTime {
                                    HStack(spacing: 4) {
                                        Text(isFirst ? "📍" : "⏹")
                                            .font(.system(size: 10))
                                        Text(time)
                                            .font(.system(size: 11))
                                        Text(legDetail.origin)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                // 终点站名
                                HStack(spacing: 4) {
                                    Text(isLast ? "🎯" : "⏹")
                                        .font(.system(size: 10))
                                    Text(legDetail.destination)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                            
                            // 附加信息
                            if let distance = legDetail.distance,
                               let duration = legDetail.duration {
                                Text("\(distance) · \(duration)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            } else if legDetail.stops > 0 {
                                Text("途经 \(legDetail.stops) 站")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 展开/折叠指示器（只在有经停站数据时显示）
                    if !legDetail.stopovers.isEmpty || hasStoredStopovers() {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.trailing, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(legDetail.type.color.opacity(0.9))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的经停站列表
            if isExpanded && !stopovers.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(stopovers.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            // 连接线
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(legDetail.type.color.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(height: index == 0 ? 10 : 20)
                                
                                Circle()
                                    .fill(legDetail.type.color.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                
                                if index < stopovers.count - 1 {
                                    Rectangle()
                                        .fill(legDetail.type.color.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(height: 20)
                                }
                            }
                            .padding(.leading, 20)
                            
                            // 站点信息
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stopovers[index].name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                
                                if let time = stopovers[index].time {
                                    Text(time)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            
            // 段间连接器（不是最后一段时显示）
            if !isLast {
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
    
    private func loadStopovers() {
        // 如果已经有经停站数据，直接使用
        if !legDetail.stopovers.isEmpty {
            self.stopovers = legDetail.stopovers
            return
        }
        
        // 尝试从journey数据中获取对应leg的经停站信息
        if let legs = journeyData["legs"] as? [[String: Any]], 
           legIndex < legs.count,
           let stopoversData = legs[legIndex]["stopovers"] as? [[String: Any]] {
            var stops: [StopoverInfo] = []
            for stopover in stopoversData {
                let name = stopover["name"] as? String ?? "未知站点"
                var time: String? = nil
                
                if let departure = stopover["departure"] as? String {
                    time = formatTime(departure)
                } else if let arrival = stopover["arrival"] as? String {
                    time = formatTime(arrival)
                }
                
                stops.append(StopoverInfo(name: name, time: time))
            }
            self.stopovers = stops
        }
        
        // 没有经停站数据就保持为空
    }
    
    private func hasStoredStopovers() -> Bool {
        // 检查journey数据中是否有对应leg的经停站信息
        if let legs = journeyData["legs"] as? [[String: Any]], 
           legIndex < legs.count,
           let stopoversData = legs[legIndex]["stopovers"] as? [[String: Any]],
           !stopoversData.isEmpty {
            return true
        }
        return false
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        return ""
    }
}

// MARK: - 经停站信息

struct StopoverInfo {
    let name: String
    var time: String?
}

