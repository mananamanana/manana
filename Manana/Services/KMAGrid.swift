import Foundation

/// Converts WGS84 lat/lon into the KMA's Lambert Conformal Conic forecast
/// grid (nx, ny) used by every 기상청 단기예보 API endpoint. This is the
/// standard published KMA conversion formula — the constants below are
/// fixed by KMA, not tunable.
enum KMAGrid {
    private static let earthRadius = 6371.00877
    private static let gridSpacing = 5.0
    private static let standardLat1 = 30.0
    private static let standardLat2 = 60.0
    private static let originLon = 126.0
    private static let originLat = 38.0
    private static let originX = 43.0
    private static let originY = 136.0

    static func nxny(latitude: Double, longitude: Double) -> (nx: Int, ny: Int) {
        let degToRad = Double.pi / 180.0
        let re = earthRadius / gridSpacing
        let slat1 = standardLat1 * degToRad
        let slat2 = standardLat2 * degToRad
        let olon = originLon * degToRad
        let olat = originLat * degToRad

        let sn = log(cos(slat1) / cos(slat2)) / log(tan(.pi * 0.25 + slat2 * 0.5) / tan(.pi * 0.25 + slat1 * 0.5))
        let sf = pow(tan(.pi * 0.25 + slat1 * 0.5), sn) * cos(slat1) / sn
        let ro = re * sf / pow(tan(.pi * 0.25 + olat * 0.5), sn)

        let ra = re * sf / pow(tan(.pi * 0.25 + (latitude * degToRad) * 0.5), sn)
        var theta = longitude * degToRad - olon
        if theta > .pi { theta -= 2 * .pi }
        if theta < -.pi { theta += 2 * .pi }
        theta *= sn

        let x = floor(ra * sin(theta) + originX + 0.5)
        let y = floor(ro - ra * cos(theta) + originY + 0.5)
        return (Int(x), Int(y))
    }
}
