package expo.modules.opsdeskofficewifi

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.time.Instant

class OpsDeskOfficeWifiModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("OpsDeskOfficeWifi")

    AsyncFunction("getCurrentNetwork") {
      val context = appContext.reactContext
        ?: return@AsyncFunction unavailable("Không thể truy cập Android application context.")

      if (!hasRequiredPermission(context)) {
        return@AsyncFunction mapOf(
          "status" to "permission_denied",
          "message" to "Cần quyền Wi-Fi/location để xác thực mạng văn phòng."
        )
      }

      val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
      if (locationManager != null && !locationManager.isLocationEnabled) {
        return@AsyncFunction mapOf(
          "status" to "location_disabled",
          "message" to "Dịch vụ vị trí đang tắt nên Android không cung cấp SSID/BSSID."
        )
      }

      val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        ?: return@AsyncFunction unavailable("Thiết bị không cung cấp WifiManager.")

      val info = wifiManager.connectionInfo
      val rawSsid = info?.ssid?.trim()?.removeSurrounding("\"")
      val rawBssid = info?.bssid?.lowercase()

      if (info == null || info.networkId == -1) {
        return@AsyncFunction mapOf(
          "status" to "not_wifi",
          "message" to "Thiết bị chưa kết nối Wi-Fi."
        )
      }

      if (
        rawSsid.isNullOrBlank() ||
        rawSsid.equals("<unknown ssid>", ignoreCase = true) ||
        rawBssid.isNullOrBlank() ||
        rawBssid == "02:00:00:00:00:00"
      ) {
        return@AsyncFunction unavailable("Android chưa cung cấp được SSID/BSSID hiện tại.")
      }

      mapOf(
        "status" to "available",
        "ssid" to rawSsid,
        "bssid" to rawBssid,
        "capturedAtDevice" to Instant.now().toString()
      )
    }

    AsyncFunction("openPermissionSettings") {
      val context = appContext.reactContext ?: return@AsyncFunction
      val intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", context.packageName, null)
      ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      context.startActivity(intent)
    }
  }

  private fun hasRequiredPermission(context: Context): Boolean {
    val fineLocationGranted = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    if (!fineLocationGranted) return false

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      return ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.NEARBY_WIFI_DEVICES
      ) == PackageManager.PERMISSION_GRANTED
    }

    return true
  }

  private fun unavailable(message: String): Map<String, String> = mapOf(
    "status" to "unavailable",
    "message" to message
  )
}
