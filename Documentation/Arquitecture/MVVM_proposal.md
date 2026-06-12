#Español
# 📂 Estructura del Proyecto

Patrón de diseño **MVVM** (Model-View-ViewModel) 

```text
Busnap/
├── App/                  (Archivos de configuración y punto de entrada)
│   ├── BusnapApp.swift   (Punto de entrada principal de SwiftUI)
│   └── Info.plist        (Configuraciones, permisos de GPS, etc.)
│
├── Core/                 (Componentes transversales y reutilizables)
│   ├── Extensions/       (Extensiones de Swift, ej: Double+Formatting.swift)
│   ├── Utilities/        (Helpers genéricos, ej: HapticManager.swift)
│   ├── UIComponents/     (Vistas reutilizables)
│   │   ├── PrimaryButton.swift
│   │   └── GlassmorphismView.swift
│   └── Theme/            (Colores, tipografías, constantes)
│       ├── Color+Theme.swift
│       └── AppConstants.swift
│
├── Services/             (Lógica de negocio externa, APIs, hardware)
│   ├── Location/         (Todo lo relacionado con el GPS)
│   │   ├── LocationManager.swift     (El servicio central que usa CoreLocation)
│   │   └── LocationError.swift
│   ├── Notifications/    (Alertas al usuario)
│   │   └── NotificationManager.swift
│   └── Storage/          (Si guardas rutas favoritas)
│       └── UserDefaultsManager.swift
│
├── Models/               (Entidades de datos puras)
│   ├── Destination.swift (struct con lat, lng, nombre)
│   └── AlarmStatus.swift (enum con los estados de la alarma)
│
├── Features/             (Los módulos funcionales de tu app usando MVVM)
│   │
│   ├── MapDashboard/     (La pantalla principal)
│   │   ├── Views/
│   │   │   ├── MapDashboardView.swift   (La vista SwiftUI)
│   │   │   └── Components/              (Sub-vistas específicas de esta pantalla)
│   │   │       ├── BottomSheetView.swift
│   │   │       └── SearchBarView.swift
│   │   └── MapDashboardViewModel.swift  (El cerebro de la pantalla)
│   │
│   ├── SearchLocation/   (Pantalla para buscar direcciones)
│   │   ├── SearchLocationView.swift
│   │   └── SearchLocationViewModel.swift
│   │
│   └── Settings/         (Pantalla de configuración)
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
└── Resources/            (Assets visuales y archivos locales)
    ├── Assets.xcassets   (Imágenes, iconos y colores del sistema)
    └── Localizable.strings (Traducciones, si tienes)
