import SwiftUI

/// Apple Maps-inspired bottom sheet.
///
/// Architecture note: this view observes the shared `MapDashboardViewModel`,
/// but the underlying `DestinationMapView` only reads map-specific
/// properties (`selectedDestination`, `leadTime`), so sheet state changes
/// (Initial → Configuring → Active…) never invalidate or redraw the Map layer.
struct BottomSheetContent: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(ThemeManager.self) private var theme
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
        .animation(.busnapSpring, value: viewModel.tripUIState)
        .presentationBackground(sheetBackground)
        .fullScreenCover(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var sheetBackground: AnyShapeStyle {
        switch theme.mode {
        case .liquidGlass: AnyShapeStyle(.ultraThinMaterial)
        case .light, .dark: AnyShapeStyle(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Initial State

    private var initialState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                searchBar
                    .padding(.bottom, 20)

                if !viewModel.searchSuggestions.isEmpty {
                    searchSuggestionsList
                        .padding(.bottom, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !viewModel.savedFavorites.isEmpty {
                    favoritesSection
                        .padding(.bottom, 16)
                }

                settingsRow
            }
        }
        .animation(.busnapSpring, value: viewModel.searchSuggestions.isEmpty)
    }

    /// Apple Maps-style search pill — glass surface, hierarchical icon,
    /// clear inner container so the map blur passes through.
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            TextField("Buscar lugar…", text: $viewModel.searchText, axis: .vertical)
                .font(.body)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.performLocalSearch() }
                }

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = ""; viewModel.searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .innerClearContainer(cornerRadius: 14)
        .themeCard(cornerRadius: 14)
        .animation(.busnapSnap, value: viewModel.searchText.isEmpty)
    }

    private var searchSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.searchSuggestions) { suggestion in
                switch suggestion {
                case .place(let place):
                    Button(action: { viewModel.selectPlace(place) }) {
                        suggestionRow(
                            icon: "mappin.circle.fill",
                            title: place.name,
                            subtitle: place.subtitle
                        )
                    }
                    .buttonStyle(.hapticLight)

                case .favorite(let dest):
                    Button(action: { viewModel.selectFavorite(dest) }) {
                        suggestionRow(
                            icon: dest.icon ?? "heart.fill",
                            title: dest.name ?? "Favorito",
                            subtitle: nil,
                            tint: AppConstants.Colors.primaryAccent
                        )
                    }
                    .buttonStyle(.hapticLight)
                }

                if suggestion.id != viewModel.searchSuggestions.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 4)
        .themeCard(cornerRadius: 14)
    }

    private func suggestionRow(
        icon: String,
        title: String,
        subtitle: String?,
        tint: Color = AppConstants.Colors.primaryAccent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.left")
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favoritos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(viewModel.savedFavorites, id: \.self) { fav in
                    Button(action: { viewModel.selectFavorite(fav) }) {
                        VStack(spacing: 6) {
                            // Clear inner circle in Liquid Glass: the sheet's
                            // ultraThinMaterial blurs the map through it.
                            ZStack {
                                Circle()
                                    .fill(theme.mode == .liquidGlass ? Color.clear : AppConstants.Colors.primaryAccent.opacity(0.12))
                                if theme.mode == .liquidGlass {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                }
                                Image(systemName: fav.icon ?? "heart.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.multicolor)
                            }
                            .frame(width: 52, height: 52)
                            Text(fav.name ?? "Favorito")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
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

    private var settingsRow: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.showSettings = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppConstants.Colors.primaryAccent.opacity(theme.mode == .liquidGlass ? 0 : 0.15))
                        .frame(width: 36, height: 36)
                    if theme.mode == .liquidGlass {
                        Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            .frame(width: 36, height: 36)
                    }
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppConstants.Colors.primaryAccent)
                }
                Text("Configuración")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .themeCard(cornerRadius: 14)
        }
        .buttonStyle(.hapticLight)
    }

    // MARK: - Configuring State

    private var configuringState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    cancelPinButton
                    destinationNameField
                    starMenu
                }

                if viewModel.isLoadingETA {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Calculando ruta…")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if let eta = viewModel.simulatedETA {
                    etaBanner(minutes: max(1, Int(ceil(eta / 60))), label: "Tiempo de ruta")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                LeadTimePickerView(viewModel: viewModel)

                PrimaryButton(title: "Iniciar Viaje", icon: "location.north.circle.fill") {
                    viewModel.confirmDestinationName()
                    viewModel.activateTrip()
                }
                .opacity(viewModel.selectedDestination == nil || viewModel.isLoadingETA ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil || viewModel.isLoadingETA)
                .animation(.busnapSpring, value: viewModel.isLoadingETA)
            }
        }
        .onAppear { isSaved = viewModel.isCurrentDestinationFavorite() }
    }

    private var cancelPinButton: some View {
        Button(action: { viewModel.clearDestination() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .floatingMapControl()
        }
        .buttonStyle(.hapticLight)
    }

    private var destinationNameField: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(AppConstants.Colors.primaryAccent)
            TextField("Nombre del destino", text: $viewModel.destinationName)
                .fontWeight(.medium)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.confirmDestinationName() }
            if !viewModel.destinationName.isEmpty {
                Button(action: { viewModel.destinationName = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .innerClearContainer(cornerRadius: 14)
        .themeCard(cornerRadius: 14)
        .frame(maxWidth: .infinity)
    }

    private var starMenu: some View {
        Menu {
            favoriteAction("Casa", icon: "house.fill")
            favoriteAction("Trabajo", icon: "briefcase.fill")
            favoriteAction("Corazón", icon: "heart.fill")
            favoriteAction("Estrella", icon: "star.fill")
            favoriteAction("Bandera", icon: "flag.fill")
            favoriteAction("Ubicación", icon: "location.fill")
            favoriteAction("Edificio", icon: "building.fill")
            favoriteAction("Bolsa", icon: "bag.fill")
            favoriteAction("Carrito", icon: "cart.fill")
            favoriteAction("Médico", icon: "cross.fill")
            favoriteAction("Libro", icon: "book.fill")
            favoriteAction("Reloj", icon: "clock.fill")
            favoriteAction("Sol", icon: "sun.max.fill")
            favoriteAction("Luna", icon: "moon.fill")
            if isSaved {
                Button(role: .destructive, action: {
                    viewModel.removeFavorite()
                    isSaved = false
                }) {
                    Label("Eliminar favorito", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: isSaved ? "star.fill" : "star")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSaved ? .yellow : AppConstants.Colors.primaryAccent)
                .floatingMapControl()
        }
        .animation(.busnapSnap, value: isSaved)
    }

    private func favoriteAction(_ label: String, icon: String) -> some View {
        Button(action: {
            viewModel.saveFavorite(icon: icon)
            isSaved = true
        }) {
            Label(label, systemImage: icon)
        }
    }

    // MARK: - Active / Paused States

    private var activeState: some View {
        VStack(spacing: 16) {
            destinationInfo
            routeTimeRow

            HStack(spacing: 12) {
                Button(action: { viewModel.pauseTrip() }) {
                    controlLabel(icon: "pause.circle.fill", title: "Pausar", tint: AppConstants.Colors.primaryAccent)
                }
                .buttonStyle(.hapticMedium)

                cancelButton
            }
        }
    }

    private var pausedState: some View {
        VStack(spacing: 16) {
            destinationInfo
            routeTimeRow

            HStack(spacing: 12) {
                Button(action: { viewModel.resumeTrip() }) {
                    controlLabel(icon: "play.circle.fill", title: "Reanudar", tint: AppConstants.Colors.success)
                }
                .buttonStyle(.hapticMedium)

                cancelButton
            }
        }
    }

    private func controlLabel(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
            Text(title)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: AppConstants.Layout.buttonHeight)
        .background(tint, in: RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius, style: .continuous))
        .shadow(color: tint.opacity(0.35), radius: 10, x: 0, y: 5)
    }

    private var cancelButton: some View {
        Button(action: { viewModel.cancelTrip() }) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppConstants.Colors.destructive)
                .frame(width: AppConstants.Layout.buttonHeight, height: AppConstants.Layout.buttonHeight)
                .background(
                    AppConstants.Colors.destructive.opacity(theme.mode == .dark ? 0.18 : 0.1),
                    in: RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.hapticHeavy)
    }

    // MARK: - Finished State

    private var finishedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.multicolor)
                .transition(.scale.combined(with: .opacity))

            VStack(spacing: 4) {
                Text("¡Has llegado!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Es hora de bajar del autobús.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: { viewModel.dismissFinished() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.hapticLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Shared Components

    private var destinationInfo: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(AppConstants.Colors.primaryAccent)
            Text(viewModel.selectedDestination?.name ?? "Destino")
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
        }
        .padding(14)
        .themeCard(cornerRadius: 14)
    }

    private var routeTimeRow: some View {
        Group {
            if viewModel.isLoadingETA {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Actualizando ruta…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let eta = viewModel.simulatedETA {
                etaBanner(minutes: max(1, Int(ceil(eta / 60))), label: "Tiempo de viaje")
            }
        }
    }

    private func etaBanner(minutes: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: minutes <= viewModel.leadTime.minutes ? "exclamationmark.triangle.fill" : "clock.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(minutes <= viewModel.leadTime.minutes ? AppConstants.Colors.destructive : AppConstants.Colors.success)
            Text("\(label): \(minutes) min")
                .fontWeight(.semibold)
                .foregroundStyle(minutes <= viewModel.leadTime.minutes ? AppConstants.Colors.destructive : .primary)
            Spacer()
        }
        .padding(14)
        .themeCard(cornerRadius: 14)
    }
}
