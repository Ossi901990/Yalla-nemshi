# 📍 Location APIs: Geocoding & Places

**Date:** January 20, 2026  
**Status:** Geocoding ✅ Implemented | Places 📋 Deferred (Phase 2)

---

## 🎯 Quick Summary

| API | Status | Priority | Use Case | Cost |
|-----|--------|----------|----------|------|
| **Google Geocoding** | ✅ **IMPLEMENTED** | Core | Convert lat/lng → city | Free (40K/mo) |
| **Google Places** | 📋 **PLANNED** | Medium | Address autocomplete | ~$7/1K calls |

---

## ✅ GEOCODING API (Currently Implemented)

### What It Does
Converts GPS coordinates (latitude/longitude) into human-readable location names (city, state, country).

### Where It's Used

**1. App Startup (Automatic)**
```
User opens app
    ↓
main.dart → _detectAndSaveUserCity()
    ↓
GeolocatorPlugin gets user's current GPS location
    ↓
GeocodingService.getCityFromCoordinates(lat, lng)
    ↓
Makes HTTP request to: 
https://maps.googleapis.com/maps/api/geocode/json?latlng=lat,lng&key=API_KEY
    ↓
Extracts city from response (e.g., "Cairo", "Alexandria", "Giza")
    ↓
Saved to SharedPreferences for future use
```

**2. Walk Creation**
```
User creates walk with location picker
    ↓
Selects meeting point on map
    ↓
create_walk_screen.dart → GeocodingService.getCityFromCoordinates()
    ↓
Detects city automatically
    ↓
Walk document saved with city field
    ↓
Used for walk filtering by location
```

### Code Implementation

**Service Layer:**
```dart
// lib/services/geocoding_service.dart
static Future<String?> getCityFromCoordinates({
  required double latitude,
  required double longitude,
}) async {
  // Fetches from Google Geocoding API
  // Extracts locality/administrative_area_level_1
  // Returns city name string
}
```

**Integration Points:**
- `lib/main.dart` - Startup city detection (line 67-95)
- `lib/screens/create_walk_screen.dart` - Walk creation (line 467)
- `lib/providers/auth_provider.dart` - Auth state management

### Configuration

**Required Environment Variable:**
```bash
GOOGLE_GEOCODING_API_KEY=AIzaSy... (from Google Cloud Console)
```

**How to Set:**
```bash
# Option 1: .env file (mobile)
echo "GOOGLE_GEOCODING_API_KEY=YOUR_KEY" >> .env

# Option 2: Flutter run with --dart-define
flutter run --dart-define=GOOGLE_GEOCODING_API_KEY=YOUR_KEY

# Option 3: firebase.json (for Blaze functions)
{
  "functions": {
    "env": ["GOOGLE_GEOCODING_API_KEY=YOUR_KEY"]
  }
}
```

### Performance

- **Response Time:** ~300-500ms average
- **Timeout:** 10 seconds
- **Error Handling:** Graceful fallback to saved city preference
- **Caching:** Results cached in SharedPreferences

### Pricing

- **Free Tier:** 40,000 requests/month (more than enough)
- **Current Usage:** ~10,000 calls/month
- **Cost:** **$0** (within free tier)

### Example API Response

```json
{
  "results": [
    {
      "address_components": [
        {
          "long_name": "Cairo",
          "short_name": "Cairo",
          "types": ["locality", "political"]
        },
        {
          "long_name": "Cairo Governorate",
          "short_name": "Cairo",
          "types": ["administrative_area_level_1", "political"]
        },
        {
          "long_name": "Egypt",
          "short_name": "EG",
          "types": ["country", "political"]
        }
      ]
    }
  ],
  "status": "OK"
}
```

---

## 📋 PLACES API (Planned - Phase 2)

### What It Does
Provides address autocomplete predictions and place details as user types.

### Why We Need It

**Current Limitation:**
- Users must use map picker to select walk location
- No way to type address or search for specific places
- Requires opening map, finding location, clicking - tedious UX

**With Places API:**
```
User types "Ain Shams University"
    ↓
Real-time suggestions appear:
- "Ain Shams University, Cairo"
- "Ain Shams Cairo"
- "Ain Shams district"
    ↓
User selects one
    ↓
Auto-populated with coordinates
    ↓
Creates walk at that location
```

### Use Cases

1. **Walk Creation Flow** (Most Important)
   - Instead of map-picking, user types location
   - Gets suggestions as they type
   - Faster, more accurate location entry

2. **Walk Search/Filter**
   - Filter walks by typed location
   - "Find walks near [location]"
   - Current flow: only search by distance + map bounds

3. **Friend Meeting Points**
   - Suggest popular meeting places
   - Save favorite locations
   - Quick-select for recurring walks

### Implementation Plan

**Option A: Google Places API (Recommended)**
```dart
// Add to pubspec.yaml
google_places_flutter: ^2.0.0

// Implementation
class LocationPickerService {
  Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    // Call Google Places Autocomplete API
    // Returns list of suggestions
  }
  
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    // Get full location info: lat/lng, address, etc.
  }
}
```

**Option B: Nominatim (Free Alternative)**
```dart
// Free OpenStreetMap data
// Lower quality, rate-limited, but no cost
class NominatimService {
  Future<List<Location>> search(String query) async {
    // Search OpenStreetMap database
  }
}
```

### Cost Comparison

| Provider | Cost | Quality | Rate Limit | Notes |
|----------|------|---------|-----------|-------|
| **Google Places** | ~$7/1K calls | ⭐⭐⭐⭐⭐ | 1,000 QPS | Highly accurate |
| **Nominatim** | Free | ⭐⭐⭐ | 1 call/sec | Community run |
| **Mapbox** | Free tier + paid | ⭐⭐⭐⭐ | Tier-based | Good middle ground |

**Estimated Costs for 1,000 DAU:**
- Google Places: ~$3/month (200-300 calls/day)
- Nominatim: $0 (but slower)
- Mapbox: Free tier sufficient (~$2-5/mo if needed)

### Phase 2 Timeline

**Estimated Effort:** 2-3 days
- Day 1: Set up Places API, UI components
- Day 2: Integration with CreateWalkScreen
- Day 3: Testing, error handling, offline fallback

**Phase 2 Roadmap Placement:**
```
Q2 2026 Priority:
1. Offline Maps (HIGH - 3-4 days)
2. Places API (MEDIUM - 2-3 days)  ← We are here
3. Analytics (MEDIUM - 1 day)
```

---

## 🗺️ Location Services Comparison

```
┌─────────────────────────────────────────────────────────────┐
│                    LOCATION SERVICES STACK                   │
├─────────────────────────────────────────────────────────────┤
│ APP LAYER (Flutter UI)                                       │
│ - CreateWalkScreen (map picker + location input)             │
│ - WalkSearchScreen (filter by location)                      │
│ - ProfileScreen (user's city display)                        │
├─────────────────────────────────────────────────────────────┤
│ SERVICE LAYER (Dart)                                         │
│ ✅ GeocodingService (coordinates → city)                     │
│ ✅ GPSTrackingService (active GPS tracking)                  │
│ 📋 PlacesService (address autocomplete) - PHASE 2            │
│ 📋 GeofencingService (location-based triggers) - PHASE 2     │
├─────────────────────────────────────────────────────────────┤
│ PLUGIN LAYER (Native)                                        │
│ ✅ geolocator (GPS, permissions)                             │
│ ✅ google_maps_flutter (map display)                         │
│ 📋 google_places_flutter (autocomplete) - PHASE 2            │
├─────────────────────────────────────────────────────────────┤
│ BACKEND LAYER (Cloud)                                        │
│ ✅ Google Geocoding API (coordinates → address)              │
│ 📋 Google Places API (autocomplete) - PHASE 2                │
│ 📋 Google Maps Platform (offline tiles) - PHASE 2            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Why Places API is Lower Priority

### Current State Works Fine
- Map-based location selection is intuitive
- Most users comfortable with it
- No user complaints reported

### Deferred Reasons
1. **MVP Already Satisfactory**
   - Core feature works
   - Users can create walks successfully
   - Location selection is accurate

2. **Better to Defer Until:**
   - User feedback requests typed location entry
   - Scaling to areas where address is more recognizable
   - Want to improve onboarding flow

3. **Not on Critical Path**
   - Won't block public launch
   - Can add in Phase 2 easily
   - Incremental improvement (not core feature)

---

## 📝 ACTION ITEMS

### Now (Phase 1 - MVP)
- ✅ Geocoding API is working perfectly
- ✅ No action needed
- ✅ Continue using map-picker for location selection

### Later (Phase 2 - Q2 2026)
- [ ] Evaluate Places API vs. Nominatim vs. Mapbox
- [ ] Implement address autocomplete UI component
- [ ] Add PlacesService wrapper
- [ ] Integrate into CreateWalkScreen
- [ ] Add fallback to map-picker if Places fails
- [ ] Monitor API costs

---

## 🔗 Related Documentation

- [API_INVENTORY.md](./API_INVENTORY.md) - Complete API audit
- [FIREBASE_SETUP.md](./FIREBASE_SETUP.md) - Environment config
- [OFFLINE_MAPS_STRATEGY.md](./OFFLINE_MAPS_STRATEGY.md) - Offline map options

---

**Last Updated:** January 20, 2026  
**Next Review:** End of Q1 2026 (before Phase 2 planning)
