//
//  LocationService.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation
import CoreLocation

// MARK: - 位置服务

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoadingLocation = false
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    // 预定义地址
    private let predefinedLocations: [String: (lat: Double, lon: Double)] = [
        "家": (48.107662, 11.5338275),
        "home": (48.107662, 11.5338275),
        "学校": (48.1493705, 11.5690651),
        "school": (48.1493705, 11.5690651),
        "大学": (48.1493705, 11.5690651),
        "university": (48.1493705, 11.5690651)
    ]
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 检查初始授权状态
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - 公共方法
    
    /// 请求位置权限
    func requestLocationPermission() {
        #if os(macOS)
        // macOS使用不同的权限请求方法
        locationManager.requestAlwaysAuthorization()
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
    }
    
    /// 获取当前位置
    func getCurrentLocation() async throws -> CLLocation {
        // 检查权限
        switch authorizationStatus {
        case .notDetermined:
            // 请求权限
            requestLocationPermission()
            // 等待权限更新
            try await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
            
            // 在macOS上只有.authorized和.authorizedAlways
            #if os(macOS)
            if authorizationStatus == .authorized || authorizationStatus == .authorizedAlways {
                break
            } else {
                throw LocationError.permissionDenied
            }
            #else
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                break
            } else {
                throw LocationError.permissionDenied
            }
            #endif
            
        case .restricted, .denied:
            throw LocationError.permissionDenied
            
        #if os(macOS)
        case .authorized, .authorizedAlways:
            break
        #else
        case .authorizedWhenInUse, .authorizedAlways:
            break
        #endif
            
        @unknown default:
            throw LocationError.unknownError
        }
        
        // 开始获取位置
        await MainActor.run {
            isLoadingLocation = true
            locationError = nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    /// 根据地址描述获取坐标
    func getCoordinates(for addressDescription: String) -> (lat: Double, lon: Double)? {
        // 转换为小写以便匹配
        let lowercased = addressDescription.lowercased()
        
        // 检查是否包含预定义地址关键词
        for (keyword, coordinates) in predefinedLocations {
            if lowercased.contains(keyword) {
                print("识别到预定义地址: \(keyword) -> (\(coordinates.lat), \(coordinates.lon))")
                return coordinates
            }
        }
        
        // 检查是否包含"当前位置"等关键词
        let currentLocationKeywords = ["当前位置", "我的位置", "现在的位置", "目前位置", "current location", "my location"]
        for keyword in currentLocationKeywords {
            if lowercased.contains(keyword) {
                // 返回特殊标记，表示需要获取当前位置
                return (-999, -999)
            }
        }
        
        return nil
    }
    
    /// 解析位置描述并返回坐标
    func parseLocationDescription(_ description: String) async throws -> (lat: Double, lon: Double) {
        // 首先检查预定义地址
        if let coords = getCoordinates(for: description) {
            if coords.lat == -999 && coords.lon == -999 {
                // 需要获取当前位置
                let location = try await getCurrentLocation()
                return (location.coordinate.latitude, location.coordinate.longitude)
            } else {
                // 返回预定义坐标
                return coords
            }
        }
        
        // 如果不是预定义地址，尝试解析为坐标
        // 支持格式：48.1351,11.5820 或 纬度48.1351 经度11.5820
        let pattern = #"(\d+\.?\d*)[,\s]+(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
            
            if let latRange = Range(match.range(at: 1), in: description),
               let lonRange = Range(match.range(at: 2), in: description),
               let lat = Double(description[latRange]),
               let lon = Double(description[lonRange]) {
                return (lat, lon)
            }
        }
        
        throw LocationError.invalidAddress(description)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            print("位置权限状态变更: \(authorizationStatus.rawValue)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location
            isLoadingLocation = false
            
            // 完成异步请求
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
            
            print("获取到当前位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoadingLocation = false
            
            let errorMessage = "获取位置失败: \(error.localizedDescription)"
            locationError = errorMessage
            
            // 完成异步请求
            locationContinuation?.resume(throwing: LocationError.locationFailed(error.localizedDescription))
            locationContinuation = nil
            
            print(errorMessage)
        }
    }
}

// MARK: - 错误定义

enum LocationError: LocalizedError {
    case permissionDenied
    case locationFailed(String)
    case invalidAddress(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置权限被拒绝，请在设置中开启位置权限"
        case .locationFailed(let reason):
            return "获取位置失败: \(reason)"
        case .invalidAddress(let address):
            return "无法识别的地址: \(address)"
        case .unknownError:
            return "未知的位置错误"
        }
    }
}