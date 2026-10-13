import CoreLocation
import ExpoModulesCore
import NetworkExtension
import UIKit

public final class OpsDeskOfficeWifiModule: Module {
  public func definition() -> ModuleDefinition {
    Name("OpsDeskOfficeWifi")

    AsyncFunction("getCurrentNetwork") { (promise: Promise) in
      guard CLLocationManager.locationServicesEnabled() else {
        promise.resolve([
          "status": "location_disabled",
          "message": "Dịch vụ vị trí đang tắt nên iOS không cung cấp thông tin Wi-Fi."
        ])
        return
      }

      let authorization = CLLocationManager.authorizationStatus()
      if authorization == .denied || authorization == .restricted || authorization == .notDetermined {
        promise.resolve([
          "status": "permission_denied",
          "message": "Cần quyền vị trí chính xác theo điều kiện iOS để đọc mạng Wi-Fi hiện tại."
        ])
        return
      }

      NEHotspotNetwork.fetchCurrent { network in
        guard let network else {
          promise.resolve([
            "status": "unavailable",
            "message": "iOS chưa cung cấp SSID/BSSID hiện tại."
          ])
          return
        }

        promise.resolve([
          "status": "available",
          "ssid": network.ssid,
          "bssid": network.bssid.lowercased(),
          "capturedAtDevice": ISO8601DateFormatter().string(from: Date())
        ])
      }
    }

    AsyncFunction("openPermissionSettings") {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      await UIApplication.shared.open(url)
    }
  }
}
