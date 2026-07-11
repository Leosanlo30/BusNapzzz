import SwiftUI

struct MapDashboardView: View {
    @State private var viewModel = MapDashboardViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map placeholder — replaced with MKMapView in a future sprint
            Color(UIColor.systemGray5)
                .ignoresSafeArea()

            Text("Map Placeholder")
                .font(.title3)
                .foregroundStyle(.secondary)

            BottomSheetView(viewModel: viewModel)
        }
    }
}

#Preview {
    MapDashboardView()
}
