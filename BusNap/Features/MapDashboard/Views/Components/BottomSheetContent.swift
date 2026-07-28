import SwiftUI

struct BottomSheetContent: View {
    @Bindable var viewModel: MapDashboardViewModel
    @FocusState private var isNameFocused: Bool
    @State private var isSaved = false

    var body: some View {
        Group {
            switch viewModel.tripUIState {
            case .initial:
                initialState
            case .configuring:
                configuringState
            case .active:
                activeState
            case .paused:
                pausedState
            case .finished:
                finishedState
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.tripUIState)
        .presentationBackground(sheetBackground)
        .fullScreenCover(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    // Fondo de la lámina (sheet) según el tema activo.
    // Liquid Glass: .ultraThinMaterial para máxima transparencia.
    // Dark: negro puro para OLED true black.
    private var sheetBackground: AnyShapeStyle {
        switch viewModel.selectedTheme {
        case .liquidGlass:
            AnyShapeStyle(Material.ultraThinMaterial)
        case .dark:
            AnyShapeStyle(Color.black)
        default:
            AnyShapeStyle(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Initial State

    private var initialState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                searchBar
                    .padding(.bottom, 20)

                // (DESACTIVADO) Filtro de ruta de paraderos
//                if viewModel.selectedRoute != nil {
//                    routeFilterBar
//                        .padding(.bottom, 16)
//                }

                if !viewModel.searchSuggestions.isEmpty {
                    searchSuggestionsList
                        .padding(.bottom, 16)
                }

                if !viewModel.savedFavorites.isEmpty {
                    favoritesSection
                        .padding(.bottom, 16)
                }

                settingsButton
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Buscar lugar…", text: $viewModel.searchText)
                .font(.body)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.performLocalSearch() }
                }
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = ""; viewModel.searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .themeCard(cornerRadius: 12)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var searchSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.searchSuggestions) { suggestion in
                switch suggestion {
                // (DESACTIVADO) Sugerencias de rutas de paraderos
//                case .route(let name):
//                    Button(action: { viewModel.selectRoute(name) }) {
//                        ...
//                    }
//                    .buttonStyle(.plain)
//
//                case .stop(let stop):
//                    Button(action: { viewModel.selectStop(stop) }) {
//                        ...
//                    }
//                    .buttonStyle(.plain)

                case .place(let place):
                    Button(action: { viewModel.selectPlace(place) }) {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name)
                                    .font(.subheadline)
                                    .foregroundColor(AppConstants.Colors.primaryText)
                                    .lineLimit(1)
                                Text(place.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "location.circle")
                                .font(.caption)
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                case .favorite(let dest):
                    Button(action: { viewModel.selectFavorite(dest) }) {
                        HStack(spacing: 10) {
                            Image(systemName: dest.icon ?? "heart.fill")
                                .font(.caption)
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                                .frame(width: 24)
                            Text(dest.name ?? "Favorito")
                                .font(.subheadline)
                                .foregroundColor(AppConstants.Colors.primaryText)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "location.circle")
                                .font(.caption)
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }

                if suggestion.id != viewModel.searchSuggestions.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .themeCard(cornerRadius: 12)
    }

    // (DESACTIVADO) Barra de filtro de ruta de paraderos
//    private var routeFilterBar: some View {
//        HStack(spacing: 8) {
//            Image(systemName: "line.3.horizontal.decrease.circle.fill")
//                .foregroundColor(AppConstants.Colors.primaryAccent)
//            Text(viewModel.selectedRoute ?? "")
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .lineLimit(1)
//            Spacer()
//            Text("\(viewModel.filteredBusStops.count) paradas")
//                .font(.caption)
//                .foregroundColor(.secondary)
//            Button(action: { viewModel.clearRouteFilter() }) {
//                Image(systemName: "xmark.circle.fill")
//                    .foregroundColor(.secondary)
//                    .font(.title3)
//            }
//            .buttonStyle(.hapticLight)
//        }
//        .padding(12)
//        .background(viewModel.selectedTheme.cardBackgroundStyle)
//        .cornerRadius(12)
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(viewModel.selectedTheme.cardBorderColor, lineWidth: viewModel.selectedTheme.cardBorderWidth)
//        )
//    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favoritos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppConstants.Colors.secondaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(viewModel.savedFavorites, id: \.self) { fav in
                    Button(action: { viewModel.selectFavorite(fav) }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppConstants.Colors.primaryAccent.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                    .background(viewModel.selectedTheme.cardBackgroundStyle)
                                    .clipShape(Circle())
                                Image(systemName: fav.icon ?? "heart.fill")
                                    .font(.title3)
                                    .foregroundColor(AppConstants.Colors.primaryAccent)
                            }
                            Text(fav.name ?? "Favorito")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(AppConstants.Colors.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.hapticLight)
                }
            }
        }
    }

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.showSettings = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppConstants.Colors.primaryAccent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                }
                Text("Configuración")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppConstants.Colors.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .themeCard(cornerRadius: 12)
        }
        .buttonStyle(.hapticLight)
    }

    // MARK: - Configuring State

    private var configuringState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    cancelPinButton
                    Spacer()
                    destinationNameField
                    Spacer()
                    starMenu
                }

                if viewModel.isLoadingETA {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Calculando ruta…")
                            .foregroundColor(AppConstants.Colors.secondaryText)
                        Spacer()
                    }
                } else if let eta = viewModel.simulatedETA {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppConstants.Colors.success)
                        let minutes = max(1, Int(ceil(eta / 60)))
                        Text("Tiempo de ruta: \(minutes) min")
                            .fontWeight(.semibold)
                            .foregroundColor(minutes <= viewModel.leadTime.minutes ? AppConstants.Colors.destructive : AppConstants.Colors.primaryText)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                LeadTimePickerView(viewModel: viewModel)

                PrimaryButton(title: "Iniciar Viaje", icon: "arrow.triangle.turn.up.right.circle.fill") {
                    viewModel.confirmDestinationName()
                    viewModel.activateTrip()
                }
                .opacity(viewModel.selectedDestination == nil || viewModel.isLoadingETA ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil || viewModel.isLoadingETA)
            }
        }
        .onAppear { isSaved = viewModel.isCurrentDestinationFavorite() }
    }

    private var cancelPinButton: some View {
        Button(action: { viewModel.clearDestination() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 36, height: 36)
                .themeCard(cornerRadius: 10)
        }
        .buttonStyle(.hapticLight)
    }

    private var starMenu: some View {
        Menu {
            if isSaved {
                Button(role: .destructive, action: {
                    viewModel.removeFavorite()
                    isSaved = false
                }) {
                    Label("Eliminar favorito", systemImage: "trash")
                }
            }
            Button(action: {
                viewModel.saveFavorite(icon: "house.fill")
                isSaved = true
            }) {
                Label("Casa", systemImage: "house.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "briefcase.fill")
                isSaved = true
            }) {
                Label("Trabajo", systemImage: "briefcase.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "heart.fill")
                isSaved = true
            }) {
                Label("Corazón", systemImage: "heart.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "star.fill")
                isSaved = true
            }) {
                Label("Estrella", systemImage: "star.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "flag.fill")
                isSaved = true
            }) {
                Label("Bandera", systemImage: "flag.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "location.fill")
                isSaved = true
            }) {
                Label("Ubicación", systemImage: "location.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "building.fill")
                isSaved = true
            }) {
                Label("Edificio", systemImage: "building.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "bag.fill")
                isSaved = true
            }) {
                Label("Bolsa", systemImage: "bag.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "cart.fill")
                isSaved = true
            }) {
                Label("Carrito", systemImage: "cart.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "cross.fill")
                isSaved = true
            }) {
                Label("Médico", systemImage: "cross.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "book.fill")
                isSaved = true
            }) {
                Label("Libro", systemImage: "book.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "clock.fill")
                isSaved = true
            }) {
                Label("Reloj", systemImage: "clock.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "sun.max.fill")
                isSaved = true
            }) {
                Label("Sol", systemImage: "sun.max.fill")
            }
            Button(action: {
                viewModel.saveFavorite(icon: "moon.fill")
                isSaved = true
            }) {
                Label("Luna", systemImage: "moon.fill")
            }
        } label: {
            Image(systemName: isSaved ? "star.fill" : "star")
                .font(.title3)
                .foregroundColor(AppConstants.Colors.primaryAccent)
                .frame(width: 36, height: 36)
                .background(AppConstants.Colors.primaryAccent.opacity(0.12))
                .cornerRadius(10)
        }
        .buttonStyle(.hapticLight)
    }

    private var destinationNameField: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(AppConstants.Colors.primaryAccent)
            TextField("Nombre del destino", text: $viewModel.destinationName)
                .fontWeight(.medium)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.confirmDestinationName() }
            if !viewModel.destinationName.isEmpty {
                Button(action: { viewModel.destinationName = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .themeCard(cornerRadius: 10)
    }

    // MARK: - Active State

    private var activeState: some View {
        VStack(spacing: 16) {
            destinationInfo
            routeTimeRow

            HStack(spacing: 12) {
                Button(action: { viewModel.pauseTrip() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title3)
                        Text("Pausar")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppConstants.Layout.buttonHeight)
                    .background(AppConstants.Colors.primaryAccent)
                    .foregroundColor(.white)
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                }
                .buttonStyle(.hapticMedium)

                Button(action: { viewModel.cancelTrip() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppConstants.Colors.destructive)
                        .frame(width: AppConstants.Layout.buttonHeight, height: AppConstants.Layout.buttonHeight)
                        .background(AppConstants.Colors.destructive.opacity(0.1))
                        .cornerRadius(AppConstants.Layout.cornerRadius)
                }
                .buttonStyle(.hapticHeavy)
            }
        }
    }

    // MARK: - Paused State

    private var pausedState: some View {
        VStack(spacing: 16) {
            destinationInfo
            routeTimeRow

            HStack(spacing: 12) {
                Button(action: { viewModel.resumeTrip() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Reanudar")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppConstants.Layout.buttonHeight)
                    .background(AppConstants.Colors.success)
                    .foregroundColor(.white)
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                }
                .buttonStyle(.hapticMedium)

                Button(action: { viewModel.cancelTrip() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppConstants.Colors.destructive)
                        .frame(width: AppConstants.Layout.buttonHeight, height: AppConstants.Layout.buttonHeight)
                        .background(AppConstants.Colors.destructive.opacity(0.1))
                        .cornerRadius(AppConstants.Layout.cornerRadius)
                }
                .buttonStyle(.hapticHeavy)
            }
        }
    }

    // MARK: - Finished State

    private var finishedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppConstants.Colors.success)
                .transition(.scale.combined(with: .opacity))

            VStack(spacing: 4) {
                Text("¡Has llegado!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Es hora de bajar del autobús.")
                    .font(.subheadline)
                    .foregroundColor(AppConstants.Colors.secondaryText)
            }

            Button(action: { viewModel.dismissFinished() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(AppConstants.Colors.secondaryText)
            }
            .buttonStyle(.hapticLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Shared Components

    private var destinationInfo: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(AppConstants.Colors.primaryAccent)
            Text(viewModel.selectedDestination?.name ?? "Destino")
                .fontWeight(.medium)
            Spacer()
        }
    }

    private var routeTimeRow: some View {
        Group {
            if viewModel.isLoadingETA {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Actualizando ruta…")
                        .foregroundColor(AppConstants.Colors.secondaryText)
                    Spacer()
                }
            } else if let eta = viewModel.simulatedETA {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppConstants.Colors.success)
                    let minutes = max(1, Int(ceil(eta / 60)))
                    Text("Tiempo de viaje: \(minutes) min")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
