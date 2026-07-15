import SwiftUI

struct BottomSheetContent: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(\.theme) private var theme

    @FocusState private var isNameFocused: Bool

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
        .sheetBackground(theme: theme)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.tripUIState)
    }

    // MARK: - Initial State

    private var initialState: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppConstants.Colors.secondaryText)
                Text("Toca el mapa para colocar un pin")
                    .font(.subheadline)
                    .foregroundColor(AppConstants.Colors.secondaryText)
                Spacer()
            }
            .padding(12)
            .background(theme == .liquidGlass ? AnyView(Color.clear) : AnyView(Color(UIColor.tertiarySystemFill)))
            .cornerRadius(10)

            if !viewModel.savedFavorites.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.showFavorites.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("Favoritos")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: viewModel.showFavorites ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                    }
                    .foregroundColor(AppConstants.Colors.primaryAccent)
                }

                if viewModel.showFavorites {
                    favoritesGrid
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var favoritesGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.savedFavorites, id: \.self) { fav in
                    Button(action: { viewModel.selectFavorite(fav) }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppConstants.Colors.primaryAccent.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "heart.fill")
                                    .font(.title3)
                                    .foregroundColor(AppConstants.Colors.primaryAccent)
                            }
                            Text(fav.name ?? "Favorito")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(AppConstants.Colors.primaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                    }
                    .buttonStyle(.hapticLight)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Configuring State

    private var configuringState: some View {
        VStack(spacing: 16) {
            destinationNameField

            if viewModel.isLoadingETA {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculando ruta...")
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

            HStack(spacing: 12) {
                Button(action: { viewModel.saveAsFavorite() }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.savedFavorites.contains(where: { $0.latitude == viewModel.selectedDestination?.latitude && $0.longitude == viewModel.selectedDestination?.longitude }) ? "heart.fill" : "heart")
                            .font(.subheadline)
                        Text("Guardar")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppConstants.Layout.smallButtonHeight)
                    .background(AppConstants.Colors.primaryAccent.opacity(0.12))
                    .foregroundColor(AppConstants.Colors.primaryAccent)
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                }
                .buttonStyle(.hapticLight)

                PrimaryButton(title: "Iniciar Viaje") {
                    viewModel.confirmDestinationName()
                    viewModel.activateTrip()
                }
                .opacity(viewModel.selectedDestination == nil || viewModel.isLoadingETA ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil || viewModel.isLoadingETA)
            }
        }
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
                Button(action: {
                    viewModel.destinationName = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(theme == .liquidGlass ? AnyView(Color.clear) : AnyView(Color(UIColor.tertiarySystemFill)))
        .cornerRadius(10)
    }

    // MARK: - Active State

    private var activeState: some View {
        VStack(spacing: 16) {
            destinationInfo

            routeTimeRow

            HStack(spacing: 12) {
                Button(action: { viewModel.pauseTrip() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.fill")
                            .font(.subheadline)
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
                        Image(systemName: "play.fill")
                            .font(.subheadline)
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
                    Image(systemName: "stop.circle.fill")
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
                    Text("Actualizando ruta...")
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

// MARK: - Theme-aware sheet background modifier

struct SheetBackgroundModifier: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        if theme == .liquidGlass {
            content
                .background(.ultraThinMaterial)
        } else {
            content
                .background(AppConstants.Colors.background)
        }
    }
}

extension View {
    func sheetBackground(theme: AppTheme) -> some View {
        modifier(SheetBackgroundModifier(theme: theme))
    }
}
