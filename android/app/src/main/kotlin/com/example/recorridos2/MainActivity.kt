package com.example.recorridos2

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.HashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.flutter.plugins/georuta_background"
    private val EVENT_CHANNEL = "io.flutter.plugins/location_events"
    private val NOTIFICATION_ID = 888
    private val CHANNEL_ID = "georuta_background_channel"
    private var isForegroundServiceRunning = false
    
    private var locationManager: LocationManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Timer de auto-stop nativo (funciona incluso en background)
    private var duracionMinutos: Int = 0
    private var tiempoInicio: Long = 0
    private var autoStopHandler: Handler? = null
    private var autoStopRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        createNotificationChannel()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        // Setup event channel for location updates + control events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    duracionMinutos = call.argument<Int>("duracion") ?: 0
                    tiempoInicio = System.currentTimeMillis()
                    startForegroundService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopForegroundService()
                    result.success(true)
                }
                "actualizarTiempo" -> {
                    val segundos = call.argument<Int>("segundos") ?: 0
                    actualizarNotificacionConTiempo(segundos)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "GeoRuta"
                    val text = call.argument<String>("text") ?: "Grabando ubicación..."
                    updateNotification(title, text)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startForegroundService() {
        if (isForegroundServiceRunning) return
        isForegroundServiceRunning = true
        
        // Show notification with time context
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GeoRuta - Grabando")
            .setContentText("Grabando ubicación en segundo plano...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setFullScreenIntent(pendingIntent, true)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, notification)
        
        // Acquire wake lock - 4 horas para grabaciones largas
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "GeoRuta::LocationWakeLock"
        )
        wakeLock?.acquire(4 * 60 * 60 * 1000L) // 4 horas max
        
        // Start location tracking
        startLocationUpdates()

        // Iniciar auto-stop nativo si hay duración configurada
        if (duracionMinutos > 0) {
            iniciarAutoStop()
        }
    }

    private fun stopForegroundService() {
        if (!isForegroundServiceRunning) return
        isForegroundServiceRunning = false
        
        // Detener auto-stop
        detenerAutoStop()
        
        // Stop location tracking
        stopLocationUpdates()
        
        // Release wake lock
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        
        // Cancel notification
        val manager = getSystemService(NotificationManager::class.java)
        manager?.cancel(NOTIFICATION_ID)
    }

    private fun startLocationUpdates() {
        try {
            val hasPermission = ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasPermission) return

            // GPS provider - 500ms/0m for max tracking in pocket mode
            if (locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    500L,   // 0.5 seconds - max frequency
                    0f,     // 0 meters - capture ALL movement
                    locationListener,
                    Looper.getMainLooper()
                )
            }

            // Network provider as fallback
            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    500L,
                    0f,
                    locationListener,
                    Looper.getMainLooper()
                )
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun stopLocationUpdates() {
        locationManager?.removeUpdates(locationListener)
    }

    // Timer nativo para auto-stop en background
    private fun iniciarAutoStop() {
        detenerAutoStop()
        autoStopHandler = Handler(Looper.getMainLooper())
        autoStopRunnable = Runnable {
            if (isForegroundServiceRunning) {
                // Enviar evento de tiempo expirado a Dart
                val event = HashMap<String, Any>()
                event["type"] = "time_expired"
                try {
                    eventSink?.success(event)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                
                // Actualizar notificación antes de detener
                actualizarNotificacionConTiempo(0)
                
                // Auto-stop: detener servicio nativo
                stopForegroundService()
            }
        }
        // PostDelayed con la duración en milisegundos
        autoStopHandler?.postDelayed(autoStopRunnable!!, duracionMinutos * 60 * 1000L)
    }

    private fun detenerAutoStop() {
        autoStopRunnable?.let { autoStopHandler?.removeCallbacks(it) }
        autoStopRunnable = null
        autoStopHandler = null
    }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            if (location != null && eventSink != null) {
                val locationData = HashMap<String, Any>()
                locationData["type"] = "location"
                locationData["latitude"] = location.latitude
                locationData["longitude"] = location.longitude
                locationData["accuracy"] = location.accuracy
                locationData["altitude"] = location.altitude
                locationData["speed"] = location.speed
                locationData["timestamp"] = location.time
                // Agregar nombre del proveedor para estrategia "mejor precisión gana"
                locationData["provider"] = location.provider ?: "unknown"
                
                try {
                    eventSink?.success(locationData)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    private fun actualizarNotificacionConTiempo(segundosRestantes: Int) {
        if (!isForegroundServiceRunning) return
        
        val tiempoStr = formatearTiempo(segundosRestantes.toLong())
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val contenido = if (segundosRestantes > 0) {
            "Grabando: $tiempoStr restante"
        } else {
            "Tiempo completado! Deteniendo..."
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GeoRuta - Grabando")
            .setContentText(contenido)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setFullScreenIntent(pendingIntent, true)
            .build()
            
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, notification)
    }

    private fun updateNotification(title: String, text: String) {
        if (!isForegroundServiceRunning) return
        
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "GeoRuta Location",
                NotificationManager.IMPORTANCE_HIGH 
            ).apply {
                description = "Used for background location tracking"
                setShowBadge(false)
                enableVibration(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun formatearTiempo(segundos: Long): String {
        val horas = segundos / 3600
        val mins = (segundos % 3600) / 60
        val segs = segundos % 60
        
        return if (horas > 0) {
            String.format("%02d:%02d:%02d", horas, mins, segs)
        } else {
            String.format("%02d:%02d", mins, segs)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        detenerAutoStop()
        stopLocationUpdates()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
    }
}
