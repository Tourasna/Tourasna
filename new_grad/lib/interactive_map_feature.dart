// lib/features/interactive_map/interactive_map_feature.dart
library interactive_map_feature;

/// Screens
export 'pages/interactive_map_screen.dart';

/// Providers
export 'provider/map_provider.dart';

/// Widgets
export 'widgets/custom_marker.dart';
export 'widgets/place_info_card.dart';
export 'widgets/trip_day_bottomsheet.dart';

/// Models
export 'models/place_map.dart';
export 'models/trip.dart';
export 'models/place_location.dart'; // ← NEW

/// Data
export 'data/repositories/trip_repository.dart';
export 'data/repositories/places_repository.dart'; // ← NEW
export 'data/remote/recommendation_service.dart';
export 'data/remote/directions_service.dart';
export 'data/remote/places_api_service.dart'; // ← NEW

/// Utils
export 'utils/haversine.dart';
export 'utils/polyline_decoder.dart';

export 'pages/navigation_screen.dart';
export 'pages/trip_calendar_screen.dart';
export 'pages/active_trip_screen.dart';

// Models
export 'models/trip_history.dart';

// Services
export 'services/trip_history_service.dart';

// Screens
export 'pages/trip_history_screen.dart';

export '../../core/widgets/enhanced_animations.dart';

export 'widgets/transport_options_dialog.dart';

export 'widgets/place_search_dialog.dart';

export 'services/google_tts_service.dart';
