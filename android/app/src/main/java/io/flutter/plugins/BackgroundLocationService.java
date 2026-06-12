package io.flutter.plugins;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import com.example.recorridos2.MainActivity;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.HashMap;
import java.util.Map;
import android.util.Log;

public class BackgroundLocationService extends Service implements LocationListener, MethodCallHandler {
    private static final String EVENT_CHANNEL_NAME = "io.flutter.plugins/location_events";
    private static final String CHANNEL_ID = "georuta_background_channel";
    private static final int NOTIFICATION_ID = 888;
    private static final String NOTIFICATION_CHANNEL_NAME = "GeoRuta Location";

    private final IBinder binder = new LocalBinder();
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private boolean isRunning = false;
    private LocationManager locationManager;
    private PowerManager.WakeLock wakeLock;
    private static BackgroundLocationService instance;
    
    private int duracionMinutos = 0;
    private long tiempoInicio = 0;

    public class LocalBinder extends Binder {
        public BackgroundLocationService getService() {
            return BackgroundLocationService.this;
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        createNotificationChannel();
        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (powerManager != null) {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GeoRuta::LocationWakeLock"
            );
        }
    }

    public static BackgroundLocationService getInstance() {
        return instance;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopLocationTracking();
        releaseWakeLock();
        instance = null;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "startForegroundService":
                if (call.hasArgument("duracion")) {
                    duracionMinutos = call.argument("duracion");
                } else {
                    duracionMinutos = 0;
                }
                tiempoInicio = System.currentTimeMillis();
                
                if (!isRunning) {
                    startForegroundService();
                    result.success(true);
                } else {
                    actualizarNotificacion();
                    result.success(true);
                }
                break;
            case "stopForegroundService":
                stopForegroundService();
                result.success(true);
                break;
            case "actualizarTiempo":
                if (call.hasArgument("segundos")) {
                    int segundosRestantes = call.argument("segundos");
                    actualizarNotificacionConTiempo(segundosRestantes);
                    result.success(true);
                } else {
                    result.success(false);
                }
                break;
            default:
                result.notImplemented();
        }
    }

    private void startForegroundService() {
        isRunning = true;
        startForeground(NOTIFICATION_ID, createNotification());
        acquireWakeLock();
        startLocationTracking();
    }

    private void stopForegroundService() {
        isRunning = false;
        stopLocationTracking();
        releaseWakeLock();
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void acquireWakeLock() {
        if (wakeLock != null && !wakeLock.isHeld()) {
            wakeLock.acquire(30 * 60 * 1000L);
        }
    }

    private void releaseWakeLock() {
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
    }

    private void startLocationTracking() {
        if (locationManager == null) {
            return;
        }

        try {
            boolean hasPermission = ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED;

            if (!hasPermission) {
                return;
            }

            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    500,
                    0,
                    this,
                    Looper.getMainLooper()
                );
            }

            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    500,
                    0,
                    this,
                    Looper.getMainLooper()
                );
            }
        } catch (SecurityException e) {
            e.printStackTrace();
        }
    }

    private void stopLocationTracking() {
        if (locationManager != null) {
            try {
                locationManager.removeUpdates(this);
            } catch (SecurityException e) {
                e.printStackTrace();
            }
        }
    }

@Override
    public void onLocationChanged(Location location) {
        if (location != null && eventSink != null) {
            Map<String, Object> locationData = new HashMap<>();
            locationData.put("latitude", location.getLatitude());
            locationData.put("longitude", location.getLongitude());
            locationData.put("accuracy", location.getAccuracy());
            locationData.put("altitude", location.getAltitude());
            locationData.put("speed", location.getSpeed());
            locationData.put("timestamp", location.getTime());
            // Agregar nombre del proveedor para estrategia "mejor precisión gana"
            locationData.put("provider", location.getProvider());
            
            try {
                eventSink.success(locationData);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void onStatusChanged(String provider, int status, android.os.Bundle extras) {}

    @Override
    public void onProviderEnabled(String provider) {}

    @Override
    public void onProviderDisabled(String provider) {}

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Background location tracking");
            channel.setShowBadge(false);
            channel.enableVibration(true);
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification createNotification() {
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );
        
        String contenido = "Grabando recorrido...";
        
        if (duracionMinutos > 0 && tiempoInicio > 0) {
            long tiempoTranscurrido = (System.currentTimeMillis() - tiempoInicio) / 1000;
            long tiempoRestante = (duracionMinutos * 60L) - tiempoTranscurrido;
            if (tiempoRestante > 0) {
                contenido = "Grabando: " + formatearTiempo(tiempoRestante) + " restante";
            } else {
                contenido = "Tiempo completado!";
            }
        } else {
            contenido = "Grabando recorrido (sin límite)";
        }

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GeoRuta - Grabando")
            .setContentText(contenido)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setFullScreenIntent(pendingIntent, true)
            .build();
    }
    
    private void actualizarNotificacion() {
        if (!isRunning) return;
        
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify(NOTIFICATION_ID, createNotification());
        }
    }
    
    private void actualizarNotificacionConTiempo(int segundosRestantes) {
        if (!isRunning) return;
        
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            String tiempoStr = formatearTiempo(segundosRestantes);
            Intent intent = new Intent(this, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
            );

            String contenido = segundosRestantes > 0 
                ? "Grabando: " + tiempoStr + " restante"
                : "Tiempo completado! Deteniendo...";

            Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("GeoRuta - Grabando")
                .setContentText(contenido)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setFullScreenIntent(pendingIntent, true)
                .build();
                
            manager.notify(NOTIFICATION_ID, notification);
        }
    }
    
    private String formatearTiempo(long segundos) {
        long horas = segundos / 3600;
        long mins = (segundos % 3600) / 60;
        long segs = segundos % 60;
        
        if (horas > 0) {
            return String.format("%02d:%02d:%02d", horas, mins, segs);
        } else {
            return String.format("%02d:%02d", mins, segs);
        }
    }
}
