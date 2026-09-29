import SwiftUI

/// Apple Maps-inspired bottom sheet.
///
/// Five states driven by `TripUIState`:
/// search (initial) → configure → active / paused → arrived (finished).
struct BottomSheetContent: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(ThemeManager.self) private var theme
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isNameFocused: Bool
    @State private var isSaved = false

    var body: some View {
        Group {
            switch viewModel.tripUIState {
            case .initial:
                initialState
            case .configuring:
                configuringState
            case .active, .paused:
                activeState
            case .finished:
                finishedState
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .animation(.busnapSpring, value: viewModel.tripUIState)
        .presentationBackground(sheetBackground)
        .fullScreenCover(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
                .environment(theme)
        }
    }

    private var sheetBackground: AnyShapeStyle {
        switch theme.mode {
        case .liquidGlass: AnyShapeStyle(.ultraThinMaterial)
        case .light, .dark: AnyShapeStyle(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Initial State (Search)

    private var initialState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                searchBar

                if let message = viewModel.errorMessage {
                    ErrorBanner(message: message, needsSettings: viewModel.errorNeedsSettings)
                }

                if viewModel.searchText.isEmpty {
                    if !viewModel.savedFavorites.isEmpty {
                        favoritesSection
                    }
                    if !viewModel.recentDestinations.isEmpty {
                        recentsSection
                    }
                    if viewModel.savedFavorites.isEmpty && viewModel.recentDestinations.isEmpty {
                        emptyHint
                    }
                } else if !viewModel.searchSuggestions.isEmpty {
                    searchSuggestionsList
                        .transition(.opacity)
                } else if !viewModel.isSearching {
                    Text("Pulsa Buscar para ver más resultados")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.busnapSpring, value: viewModel.searchSuggestions.isEmpty)
        .onChange(of: isSearchFocused) { _, focused in
            if focused { viewModel.selectedDetent = .large }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("¿A dónde vas?", text: $viewModel.searchText)
                .font(.body)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await viewModel.performLocalSearch() }
                }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .innerClearContainer(cornerRadius: 14)
        .themeCard(cornerRadius: 14)
        .animation(.busnapSnap, value: viewModel.searchText.isEmpty)
    }

    private var searchSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.searchSuggestions) { suggestion in
                Button {
                    isSearchFocused = false
                    Task { await viewModel.selectSuggestion(suggestion) }
                } label: {
                    switch suggestion {
                    case .completion(let item):
                        PlaceRow(icon: "mappin.circle.fill", title: item.title,
                                 subtitle: item.subtitle.isEmpty ? nil : item.subtitle, tint: .red)
                    case .place(let place):
                        PlaceRow(icon: "mappin.circle.fill", title: place.name,
                                 subtitle: place.subtitle.isEmpty ? nil : place.subtitle, tint: .red)
                    case .favorite(let dest):
                        PlaceRow(icon: dest.icon ?? "star.fill", title: dest.name ?? "Favorito",
                                 subtitle: "Favorito", tint: .yellow)
                    }
                }
                .buttonStyle(.hapticLight)

                if suggestion.id != viewModel.searchSuggestions.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, 4)
        .themeCard(cornerRadius: 14)
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Favoritos")

            // Cuadrícula de 4 columnas que ocupa todo el ancho y crece hacia abajo.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                      alignment: .center, spacing: 16) {
                ForEach(viewModel.savedFavorites, id: \.self) { fav in
                    Button {
                        viewModel.selectFavorite(fav)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: fav.icon ?? "star.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(AppConstants.Colors.primaryAccent.gradient, in: Circle())
                            Text(fav.name ?? "Favorito")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.hapticLight)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeFavorite(fav)
                        } label: {
                            Label("Eliminar favorito", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Viajes recientes")
                Spacer()
                Button("Borrar") { viewModel.clearRecents() }
                    .font(.subheadline)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.recentDestinations, id: \.self) { recent in
                    Button {
                        viewModel.updateDestination(recent)
                    } label: {
                        PlaceRow(icon: "clock.arrow.circlepath", title: recent.name ?? "Destino",
                                 subtitle: nil, tint: .secondary)
                    }
                    .buttonStyle(.hapticLight)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeRecent(recent)
                        } label: {
                            Label("Quitar de recientes", systemImage: "trash")
                        }
                    }

                    if recent != viewModel.recentDestinations.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
            .themeCard(cornerRadius: 14)
        }
    }

    private var emptyHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.title2)
                .foregroundStyle(AppConstants.Colors.primaryAccent)
            Text("Busca tu parada o toca el mapa en el punto donde quieres bajar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(cornerRadius: 14)
    }

    // MARK: - Configuring State

    private var configuringState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    destinationNameField
                    starMenu
                    cancelPinButton
                }

                if let message = viewModel.errorMessage {
                    ErrorBanner(message: message, needsSettings: viewModel.errorNeedsSettings)
                }

                travelModePicker

                routeSummary

                LeadTimePickerView(viewModel: viewModel)

                Label {
                    Text("La alarma sonará al entrar en el círculo, a unos \(viewModel.settings.formattedDistance(viewModel.alarmRadius)) de tu destino.")
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(AppConstants.Colors.primaryAccent)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                PrimaryButton(title: "Iniciar viaje", icon: "bell.and.waves.left.and.right.fill") {
                    isNameFocused = false
                    viewModel.confirmDestinationName()
                    viewModel.activateTrip()
                }
                .disabled(viewModel.selectedDestination == nil)
                .opacity(viewModel.selectedDestination == nil ? 0.5 : 1.0)
            }
        }
        .onAppear { isSaved = viewModel.isCurrentDestinationFavorite() }
        .onChange(of: viewModel.selectedDestination) { _, _ in
            isSaved = viewModel.isCurrentDestinationFavorite()
        }
    }

    /// Selector "¿Cómo viajas?": recalcula la ruta y el radio de alarma.
    private var travelModePicker: some View {
        HStack(spacing: 8) {
            ForEach(TravelMode.allCases) { mode in
                let isSelected = viewModel.settings.travelMode == mode
                Button {
                    viewModel.updateTravelMode(mode)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.body.weight(.semibold))
                        Text(mode.shortLabel)
                            .font(.caption.weight(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(AppConstants.Colors.primaryAccent) : AnyShapeStyle(Color.clear))
                    }
                    .innerClearContainer(cornerRadius: 12)
                }
                .buttonStyle(.hapticLight)
                .accessibilityLabel(mode.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(.busnapSpring, value: isSelected)
            }
        }
    }

    @ViewBuilder
    private var routeSummary: some View {
        if viewModel.isLoadingETA {
            HStack(spacing: 8) {
                ProgressView()
                Text("Calculando ruta…")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .themeCard(cornerRadius: 14)
            .transition(.opacity)
        } else if let eta = viewModel.simulatedETA {
            HStack(spacing: 0) {
                TripStat(value: formattedMinutes(eta), label: "tiempo aprox.")
                Divider().frame(height: 32)
                TripStat(value: viewModel.routeDistance.map(viewModel.settings.formattedDistance) ?? "—",
                         label: "distancia")
                Divider().frame(height: 32)
                TripStat(value: viewModel.estimatedArrival?.formatted(date: .omitted, time: .shortened) ?? "—",
                         label: "llegada")
            }
            .padding(.vertical, 12)
            .themeCard(cornerRadius: 14)
            .transition(.opacity)

            if viewModel.isETAApproximate {
                Label("Apple Maps no tiene horarios de transporte público en esta zona; el tiempo es una estimación según la distancia.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cancelPinButton: some View {
        Button {
            viewModel.clearDestination()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .floatingMapControl()
        }
        .buttonStyle(.hapticLight)
        .accessibilityLabel("Quitar destino")
    }

    private var destinationNameField: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.red)
            TextField("Nombre del destino", text: $viewModel.destinationName)
                .fontWeight(.semibold)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.confirmDestinationName() }
        }
        .padding(12)
        .innerClearContainer(cornerRadius: 14)
        .themeCard(cornerRadius: 14)
        .frame(maxWidth: .infinity)
    }

    private var starMenu: some View {
        Menu {
            Section("Guardar como favorito") {
                favoriteAction("Casa", icon: "house.fill")
                favoriteAction("Trabajo", icon: "briefcase.fill")
                favoriteAction("Escuela", icon: "graduationcap.fill")
                favoriteAction("Gimnasio", icon: "dumbbell.fill")
                favoriteAction("Compras", icon: "bag.fill")
                favoriteAction("Médico", icon: "cross.fill")
                favoriteAction("Otro", icon: "star.fill")
            }
            if isSaved {
                Button(role: .destructive) {
                    viewModel.removeFavorite()
                    isSaved = false
                } label: {
                    Label("Eliminar favorito", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: isSaved ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(isSaved ? .yellow : AppConstants.Colors.primaryAccent)
                .floatingMapControl()
        }
        .accessibilityLabel(isSaved ? "Favorito guardado" : "Guardar favorito")
        .animation(.busnapSnap, value: isSaved)
    }

    private func favoriteAction(_ label: String, icon: String) -> some View {
        Button {
            viewModel.confirmDestinationName()
            viewModel.saveFavorite(icon: icon)
            isSaved = true
        } label: {
            Label(label, systemImage: icon)
        }
    }

    // MARK: - Active / Paused State

    private var activeState: some View {
        let isPaused = viewModel.tripUIState == .paused

        return VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(remainingDistanceText)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                        .foregroundStyle(viewModel.isApproachingStop ? AppConstants.Colors.warning : .primary)
                    Text(viewModel.selectedDestination?.name ?? "Destino")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let arrival = viewModel.estimatedArrival {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(arrival.formatted(date: .omitted, time: .shortened))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("llegada")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.busnapSpring, value: viewModel.distanceToStop)

            statusRow(isPaused: isPaused)

            if viewModel.notificationPermission == .denied {
                ErrorBanner(
                    message: "Notificaciones desactivadas: la alarma sonará, pero no verás el aviso en la pantalla bloqueada.",
                    needsSettings: true,
                    style: .warning
                )
            }

            HStack(spacing: 12) {
                Button {
                    isPaused ? viewModel.resumeTrip() : viewModel.pauseTrip()
                } label: {
                    controlLabel(icon: isPaused ? "play.fill" : "pause.fill",
                                 title: isPaused ? "Reanudar" : "Pausar",
                                 tint: isPaused ? AppConstants.Colors.success : AppConstants.Colors.primaryAccent)
                }
                .buttonStyle(.hapticMedium)

                Button(role: .destructive) {
                    viewModel.cancelTrip()
                } label: {
                    controlLabel(icon: "xmark", title: "Terminar", tint: AppConstants.Colors.destructive)
                }
                .buttonStyle(.hapticHeavy)
            }
        }
    }

    private var remainingDistanceText: String {
        if let distance = viewModel.distanceToStop ?? viewModel.routeDistance {
            return viewModel.settings.formattedDistance(distance)
        }
        return "En camino"
    }

    private func statusRow(isPaused: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isPaused ? "pause.circle.fill" : "bell.and.waves.left.and.right.fill")
                .foregroundStyle(isPaused ? Color.secondary : AppConstants.Colors.primaryAccent)
                .symbolEffect(.pulse, isActive: !isPaused)
            Text(isPaused
                 ? "Actualización de ruta en pausa. La alarma sigue activa."
                 : "Alarma activa · sonará \(viewModel.leadTime.minutes) min antes de llegar")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .themeCard(cornerRadius: 14)
    }

    private func controlLabel(icon: String, title: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.Layout.smallButtonHeight + 6)
            .background(tint, in: RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius, style: .continuous))
    }

    // MARK: - Finished State

    private var finishedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppConstants.Colors.primaryAccent)
                .symbolEffect(.bounce, options: .repeating)

            VStack(spacing: 4) {
                Text("¡Has llegado!")
                    .font(.title.weight(.bold))
                Text("Estás cerca de \(viewModel.selectedDestination?.name ?? "tu parada"). Prepárate para bajar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.dismissFinished()
            } label: {
                Label("Detener alarma", systemImage: "stop.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(AppConstants.Colors.destructive,
                                in: RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius, style: .continuous))
            }
            .buttonStyle(.hapticHeavy)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func formattedMinutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}

// MARK: - Reusable Pieces

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct PlaceRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
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
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

private struct TripStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Aviso con acción opcional para abrir Ajustes cuando falta un permiso.
struct ErrorBanner: View {
    enum Style { case error, warning }

    let message: String
    let needsSettings: Bool
    var style: Style = .error

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style == .error ? "exclamationmark.triangle.fill" : "bell.slash.fill")
                .foregroundStyle(style == .error ? AppConstants.Colors.destructive : AppConstants.Colors.warning)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if needsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Abrir Ajustes") { openURL(url) }
                        .font(.footnote.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .themeCard(cornerRadius: 14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
