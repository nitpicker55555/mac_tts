//
//  MapRouteView.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI
import MapKit

// MARK: - 地图路线视图

struct MapRouteView: View {
    let geoJSON: GeoJSONFeatureCollection
    let routeInfo: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var mapAnnotations: [MapAnnotation] = []
    @State private var routePolyline: MKPolyline?
    
    var body: some View {
        VStack(spacing: 0) {
            // 地图视图
            MapKitView(
                region: $region,
                annotations: mapAnnotations,
                polyline: routePolyline
            )
            .frame(height: 400)
            
            // 路线信息
            ScrollView {
                Text(routeInfo)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 600)
        .onAppear {
            loadGeoJSONData()
        }
    }
    
    private func loadGeoJSONData() {
        var annotations: [MapAnnotation] = []
        var coordinates: [CLLocationCoordinate2D] = []
        
        // 处理每个feature
        for feature in geoJSON.features {
            switch feature.geometry {
            case .point(let coords):
                if coords.count >= 2 {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: coords[1],
                        longitude: coords[0]
                    )
                    
                    let annotation = MapAnnotation(
                        coordinate: coordinate,
                        title: feature.properties["name"] as? String ?? "Unknown",
                        type: feature.properties["type"] as? String ?? "point"
                    )
                    annotations.append(annotation)
                }
                
            case .lineString(let coordsArray):
                for coords in coordsArray {
                    if coords.count >= 2 {
                        let coordinate = CLLocationCoordinate2D(
                            latitude: coords[1],
                            longitude: coords[0]
                        )
                        coordinates.append(coordinate)
                    }
                }
            }
        }
        
        // 设置地图注释
        self.mapAnnotations = annotations
        
        // 创建路线
        if !coordinates.isEmpty {
            self.routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            
            // 计算地图区域以包含所有点
            if let firstCoord = coordinates.first {
                var minLat = firstCoord.latitude
                var maxLat = firstCoord.latitude
                var minLon = firstCoord.longitude
                var maxLon = firstCoord.longitude
                
                for coord in coordinates {
                    minLat = min(minLat, coord.latitude)
                    maxLat = max(maxLat, coord.latitude)
                    minLon = min(minLon, coord.longitude)
                    maxLon = max(maxLon, coord.longitude)
                }
                
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) * 1.5,
                    longitudeDelta: (maxLon - minLon) * 1.5
                )
                
                self.region = MKCoordinateRegion(center: center, span: span)
            }
        }
    }
}

// MARK: - 地图注释模型

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let type: String
    
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

// MARK: - MapKit视图包装器

struct MapKitView: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [MapAnnotation]
    let polyline: MKPolyline?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // 更新区域
        mapView.setRegion(region, animated: true)
        
        // 清除旧的注释和覆盖物
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // 添加新的注释
        for annotation in annotations {
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = annotation.coordinate
            mkAnnotation.title = annotation.title
            mapView.addAnnotation(mkAnnotation)
        }
        
        // 添加路线
        if let polyline = polyline {
            mapView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapKitView
        
        init(_ parent: MapKitView) {
            self.parent = parent
        }
        
        // 自定义注释视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CustomPin"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 根据类型设置颜色
            if let markerView = annotationView as? MKMarkerAnnotationView {
                if let mapAnnotation = parent.annotations.first(where: { 
                    $0.coordinate.latitude == annotation.coordinate.latitude && 
                    $0.coordinate.longitude == annotation.coordinate.longitude 
                }) {
                    markerView.markerTintColor = mapAnnotation.markerColor
                }
            }
            
            return annotationView
        }
        
        // 自定义路线渲染
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 4.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - 预览

struct MapRouteView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleGeoJSON = GeoJSONFeatureCollection(features: [
            GeoJSONFeature(
                geometry: .point(coordinates: [11.5653114, 48.1457899]),
                properties: ["name": "起点", "type": "origin"] as [String: String?]
            ),
            GeoJSONFeature(
                geometry: .point(coordinates: [11.5338275, 48.107662]),
                properties: ["name": "终点", "type": "destination"] as [String: String?]
            )
        ])
        
        MapRouteView(
            geoJSON: sampleGeoJSON,
            routeInfo: "示例路线信息"
        )
    }
}