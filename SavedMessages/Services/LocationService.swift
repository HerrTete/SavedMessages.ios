import CoreLocation

class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private(set) var currentAddress: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        // requestWhenInUseAuthorization triggers the dialog when not yet determined.
        // locationManagerDidChangeAuthorization fires with the current status and
        // triggers requestLocation() when authorized.
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            // Geocoding errors are intentionally ignored; location is a best-effort feature.
            guard let address = placemarks?.first.flatMap({ Self.format($0) }) else { return }
            DispatchQueue.main.async { self?.currentAddress = address }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Best-effort: silently ignore location errors
    }

    private static func format(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let locality = placemark.locality { parts.append(locality) }
        if let adminArea = placemark.administrativeArea { parts.append(adminArea) }
        if let country = placemark.country { parts.append(country) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
