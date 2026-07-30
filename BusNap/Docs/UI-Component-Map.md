# Mapa de Componentes UI — BusNap

## Árbol de Jerarquía Visual

```
BusNapApp.swift
 |
 +-- WindowGroup
      |
      MapDashboardView  (ZStack .topTrailing)
      |  .ignoresSafeArea(.container, edges: .bottom)
      |  .sheet → BottomSheetContent
      |  .preferredColorScheme(colorScheme)
      |  .environment(\.theme, viewModel.selectedTheme)
      |
      +-- DestinationMapView  (MapReader)
      |    .ignoresSafeArea(edges: .all)
      |    |
      |    +-- Map(position: $cameraPosition)
      |    |   .mapStyle(.standard)
      |    |   .safeAreaPadding(.top, 100)
      |    |   .mapControls { MapUserLocationButton; MapCompass; MapPitchToggle }
      |    |   .onTapGesture
      |    |   .onMapCameraChange(frequency: .onEnd)
      |    |   |
      |    |   +-- UserAnnotation()
      |    |   |
      |    |   +-- ForEach(stopsInSight) → Annotation
      |    |   |    .annotationTitles(.hidden)
      |    |   |    |
      |    |   |    +-- VStack(spacing: 2)
      |    |   |         +-- BusStopAnnotation
      |    |   |         |    ZStack { bg (Circle.fill.white); ring (Circle.stroke); icon (bus.fill) }
      |    |   |         |    .drawingGroup()
      |    |   |         |
      |    |   |         +-- [si seleccionada] StopCallout
      |    |   |              HStack { bus.fill + Text(name) }
      |    |   |              .background(theme.cardBackgroundStyle)
      |    |   |              .cornerRadius(8)
      |    |   |              .overlay(RoundedRectangle.stroke)
      |    |   |
      |    |   +-- [si hay destino] Marker(dest)
      |    |   |    .tint(.blue)
      |    |   |
      |    |   +-- [si hay destino] MapCircle(dest, radius)
      |    |        .foregroundStyle(.blue.opacity(0.15))
      |    |        .stroke(.blue, lineWidth: 2)
      |    |
      |    +-- .overlay(alignment: .topTrailing)  ← settingsButton
      |         .padding(.top, 172)
      |         .padding(.trailing, 8)
      |         |
      |         +-- Button (gearshape.fill 40×40)
      |              .background(theme.cardBackgroundStyle)
      |              .clipShape(Circle)
      |              .overlay(Circle.stroke)
      |              .shadow
      |
      +-- [si isOffline] offlineBanner  (zIndex: 1)
           .animation(.easeInOut)
           |
           +-- VStack
                +-- HStack { wifi.slash + "Sin conexión..." }
                     .frame(maxWidth: .infinity)
                     .padding()
                     .background(Color.red.opacity(0.8))
                     .cornerRadius(12)
                +-- Spacer()
```

```
BottomSheetContent (presentado como .sheet)
.padding(AppConstants.Layout.standardPadding)           // ← 16pt
.presentationBackground(sheetBackground)
.fullScreenCover → SettingsView (cuando showSettings)
 |
 +-- [switch tripUIState]
      |
      +-- initialState  → ScrollView
      |    +-- VStack(spacing: 0)
      |         +-- searchBar  (.padding(.bottom, 20))
      |         |    HStack { magnifyingglass + TextField + (xmark si texto) }
      |         |    .padding(12) .background(cardBackgroundStyle) .cornerRadius(12)
      |         |    .overlay(RoundedRectangle.stroke)
      |         |    .fixedSize(horizontal: false, vertical: true)
      |         |
      |         +-- [si ruta seleccionada] routeFilterBar  (.padding(.bottom, 16))
      |         |    HStack { icon + routeName + "N paradas" + xmark }
      |         |    .padding(12) .background(cardBackgroundStyle) .cornerRadius(12)
      |         |    .overlay(RoundedRectangle.stroke)
      |         |
      |         +-- [si hay sugerencias] searchSuggestionsList  (.padding(.bottom, 16))
      |         |    VStack(alignment: .leading)
      |         |    +-- ForEach(searchSuggestions)
      |         |         switch:
      |         |         - .route → Button { bus.fill + name + arrow }
      |         |         - .stop  → Button { bus.fill + name + routes + location }
      |         |         - .favorite → Button { icon + name + location }
      |         |         - Divider (si no es el último)
      |         |    .background(cardBackgroundStyle) .cornerRadius(12)
      |         |    .overlay(RoundedRectangle.stroke)
      |         |
      |         +-- [si hay favoritos] favoritesSection
      |              VStack(alignment: .leading)
      |              +-- Text("Favoritos")
      |              +-- LazyVGrid(4 columnas)
      |                   ForEach → Button
      |                   VStack(spacing: 6)
      |                   +-- ZStack
      |                   |   Circle(52×52) + background(cardBackgroundStyle) + Image(icon)
      |                   +-- Text(name)
      |
      +-- configuringState → ScrollView
           VStack(spacing: 16)
           +-- HStack(spacing: 8)
           |   +-- cancelPinButton  (xmark 36×36, background + corner + overlay)
           |   +-- Spacer
           |   +-- destinationNameField
           |   |   HStack { mappin + TextField("Nombre del destino") + (xmark si texto) }
           |   |   .padding(12) .background(cardBackgroundStyle) .cornerRadius(10)
           |   |   .overlay(RoundedRectangle.stroke)
           |   +-- Spacer
           |   +-- starMenu (Menu con 14 iconos + "Eliminar favorito" si isSaved)
           |
           +-- [si isLoadingETA] ProgressView + "Calculando ruta..."
           |   [o si hay eta] HStack { clock + "Tiempo de ruta: N min" }
           |
           +-- LeadTimePickerView
           |   VStack(alignment: .leading)
           |   +-- Text("Avisarme antes de llegar:")
           |   +-- HStack(spacing: 12)
           |        ForEach(options) → Button
           |        Text(displayTitle) .frame(maxWidth: .infinity, minHeight: 50)
           |        .background(selected ? accent : cardBackgroundStyle, in: RoundedRectangle)
           |        .overlay(RoundedRectangle.stroke)
           |
           +-- PrimaryButton "Iniciar Viaje"
                .opacity/disabled según selectedDestination y isLoadingETA

      +-- activeState → VStack(spacing: 16)
      |   +-- destinationInfo (HStack { mappin + name })
      |   +-- routeTimeRow (ProgressView o HStack { clock + tiempo })
      |   +-- HStack(spacing: 12)
      |        +-- Button "Pausar" (accent, 56pt alto, cornerRadius 16)
      |        +-- Button xmark (destructive.opacity(0.1), 56×56, cornerRadius 16)
      |
      +-- pausedState → VStack(spacing: 16)
      |   +-- destinationInfo + routeTimeRow (igual que active)
      |   +-- HStack(spacing: 12)
      |        +-- Button "Reanudar" (.success, 56pt)
      |        +-- Button xmark (destructive.opacity(0.1), 56×56)
      |
      +-- finishedState → VStack(spacing: 20)
           +-- checkmark.circle.fill (size 56, .success)
           +-- VStack(spacing: 4) { "¡Has llegado!" + "Es hora de bajar..." }
           +-- Button xmark (dismiss)
```

---

## Localizador de Componentes

| Componente | Archivo:línea | Posición física en pantalla |
|---|---|---|
| **Mapa** | `DestinationMapView.swift:68` | Ocupa toda la pantalla (`ignoresSafeArea`). Capa base del `ZStack`. |
| **Botón Configuración** | `DestinationMapView.swift:137` | Esquina superior derecha, a 172pt del borde superior y 8pt del trailing. Círculo de 40×40 con `ultraThinMaterial` (o sólido según tema). |
| **Anotaciones de parada** | `DestinationMapView.swift:73` | Sobre el mapa, coordenada exacta de cada parada. Círculo blanco 14–20pt con borde azul/naranja + icono bus. |
| **Callout de parada** | `DestinationMapView.swift:80` | Justo debajo de la anotación seleccionada. Fondo material con borde redondeado de 8pt. |
| **Marker destino** | `DestinationMapView.swift:93` | Sobre el mapa, coordenada del destino seleccionado. Pin azul nativo. |
| **Círculo de geocerca** | `DestinationMapView.swift:98` | Alrededor del destino. Radio dinámico, azul semitransparente (15% opacidad) con borde de 2pt. |
| **Banner offline** | `MapDashboardView.swift:13` | Parte superior, ancho completo. Rojo 80% opacidad, texto blanco. Aparece con animación. |
| **Sheet inferior** | `MapDashboardView.swift:18` | Bottom sheet desde la parte inferior. 3 detents: 25%, medium, large. Fondo adaptable al tema. |
| **Barra de búsqueda** | `BottomSheetContent.swift:70` | Primera fila dentro del sheet. HStack con lupa y TextField. Fondo de tarjeta, radius 12. |
| **Filtro de ruta** | `BottomSheetContent.swift:189` | Segunda fila (si hay ruta). Muestra nombre de ruta + conteo de paradas. |
| **Lista de sugerencias** | `BottomSheetContent.swift:101` | Tercera fila (si hay sugerencias). Lista vertical con divisores. Cada item es un botón. |
| **Grid de favoritos** | `BottomSheetContent.swift:217` | Cuarta fila (si hay favoritos guardados). Grid de 4 columnas con íconos circulares de 52pt. |
| **Botón cancelar pin** | `BottomSheetContent.swift:300` | Estado configuración, borde izquierdo. Xmark 36×36. |
| **Campo nombre destino** | `BottomSheetContent.swift:421` | Estado configuración, centro. TextField con icono de mapa. |
| **Menú estrella (favorito)** | `BottomSheetContent.swift:316` | Estado configuración, borde derecho. Estrella rellena/borde. Menú contextual con 14 iconos. |
| **LeadTimePicker** | `LeadTimePickerView.swift:15` | Estado configuración. Tres botones horizontales (3min, 5min, custom). |
| **Botón Iniciar Viaje** | `BottomSheetContent.swift:289` | Estado configuración, fondo. PrimaryButton de ancho completo. |
| **Botones Activo/Pausa** | `BottomSheetContent.swift:448–515` | Estados activo/pausa. Dos botones: acción principal (Pausar/Reanudar) + cancelar (xmark). |
| **Pantalla Finalizado** | `BottomSheetContent.swift:520` | Estado finalizado. Checkmark grande + texto + botón cerrar, centrado verticalmente. |
