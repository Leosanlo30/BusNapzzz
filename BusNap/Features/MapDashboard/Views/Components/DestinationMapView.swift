//
//  DestinationMapView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 09/07/26.
//

import Foundation
import SwiftUI
import MapKit

struct DestinationMapView: View {
    var viewModel: MapDashboardViewModel

    let initialPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.9673, longitude: -89.6236),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        // Envolvemos todo en el MapReader
        MapReader { proxy in
            Map(initialPosition: initialPosition) {
                
                if let destination = viewModel.selectedDestination {
                    let coordinate = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
                    
                    Marker(destination.name ?? "Destino", coordinate: coordinate)
                        .tint(AppConstants.Colors.primaryAccent)
                }
            }
            .mapStyle(.standard)
            
            .onTapGesture(coordinateSpace: .local) { location in
                if let coordinate = proxy.convert(location, from: .local) {
                    
                    let newDestination = Destination(
                        name: "Destino Seleccionado",
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    viewModel.updateDestination(newDestination)
                }
            }
        }
        // Traductor matematico y mapa miden lo mismo (para que el tap no se desplace)
        .ignoresSafeArea()
    }
}

#Preview {
    DestinationMapView(viewModel: MapDashboardViewModel())
}
