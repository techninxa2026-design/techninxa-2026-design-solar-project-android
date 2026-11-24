package com.techninxa.idcolda_ms;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import java.util.HashMap;
import java.util.Map;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** One foreground location reading, explicitly requested by the client form. */
public class MainActivity extends FlutterActivity {
    private static final int LOCATION_REQUEST = 801;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private MethodChannel.Result pending;
    private LocationManager manager;
    private LocationListener listener;
    private Runnable timeout;
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "idcolda/location")
            .setMethodCallHandler((call, result) -> {
                if (!"currentLocation".equals(call.method)) { result.notImplemented(); return; }
                if (pending != null) { result.error("busy", "Location is already being requested.", null); return; }
                pending = result;
                if (!permitted()) {
                    requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION}, LOCATION_REQUEST);
                } else beginReading();
            });
    }
    private boolean permitted() {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
               checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }
    @Override public void onRequestPermissionsResult(int code, String[] permissions, int[] grants) {
        super.onRequestPermissionsResult(code, permissions, grants);
        if (code != LOCATION_REQUEST || pending == null) return;
        if (permitted()) beginReading();
        else finish(null, "Location permission denied. You can paste a Maps URL instead.");
    }
    @SuppressWarnings("MissingPermission")
    private void beginReading() {
        manager = (LocationManager)getSystemService(Context.LOCATION_SERVICE);
        if (manager == null || !permitted()) { finish(null, "Location unavailable."); return; }
        listener = new LocationListener() {
            @Override public void onLocationChanged(Location location) {
                double lat = location.getLatitude(), lon = location.getLongitude();
                if (!Double.isFinite(lat) || !Double.isFinite(lon) || Math.abs(lat)>90 || Math.abs(lon)>180) return;
                Map<String,Double> coords = new HashMap<>();
                coords.put("latitude",lat); coords.put("longitude",lon);
                finish(coords,null);
            }
            @Override public void onProviderEnabled(String provider) {}
            @Override public void onProviderDisabled(String provider) {}
            @Override public void onStatusChanged(String provider,int status,Bundle extras) {}
        };
        timeout = () -> finish(null, "Location unavailable. Check GPS or enter a Maps URL.");
        handler.postDelayed(timeout, 15000);
        boolean started = false;
        for (String provider : new String[]{LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER}) {
            try {
                if (manager.isProviderEnabled(provider)) {
                    manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper());
                    started = true;
                }
            } catch (IllegalArgumentException | SecurityException ignored) {}
        }
        if (!started) finish(null, "Turn on device location or enter a Maps URL.");
    }
    private void finish(Map<String,Double> coords,String error) {
        if (timeout != null) handler.removeCallbacks(timeout);
        if (manager != null && listener != null) {
            try { manager.removeUpdates(listener); } catch (SecurityException ignored) {}
        }
        timeout = null; listener = null; manager = null;
        MethodChannel.Result result = pending; pending = null;
        if (result == null) return;
        if (coords != null) result.success(coords);
        else result.error("location_unavailable", error, null);
    }
    @Override protected void onStop() {
        if (listener != null) finish(null,"Location request cancelled.");
        super.onStop();
    }
    @Override protected void onDestroy() {
        if (pending != null) finish(null,"Location request cancelled.");
        super.onDestroy();
    }
}
