package com.techninxa.idcolda_ms;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

final class AndroidUpdater {
    private static final class ReleaseChangedException extends IOException {}
    private static final long LIMIT = 200L * 1024 * 1024;
    private static final AtomicBoolean BUSY = new AtomicBoolean(false);
    private static final String BASE = "https://idcoldrs.com/app/download/";
    private static long version(PackageInfo p) {
        return Build.VERSION.SDK_INT >= 28 ? p.getLongVersionCode() : p.versionCode;
    }
    @SuppressWarnings("deprecation")
    static void register(Activity activity, BinaryMessenger messenger) {
        MethodChannel channel = new MethodChannel(messenger, "idcolda/updates");
        channel.setMethodCallHandler((call, result) -> {
            if ("installedVersion".equals(call.method)) {
                try {
                    PackageInfo p = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
                    Map<String,Object> info = new HashMap<>();
                    info.put("code", version(p)); info.put("name", p.versionName);
                    result.success(info);
                } catch (Exception e) { result.error("version", "Cannot read app version.", null); }
                return;
            }
            if (!"install".equals(call.method)) { result.notImplemented(); return; }
            Number code = call.argument("code"), size = call.argument("bytes");
            String hash = call.argument("sha256");
            if (code == null || size == null || hash == null || code.longValue() <= 0 ||
                code.longValue() > Integer.MAX_VALUE || size.longValue() <= 0 ||
                size.longValue() > LIMIT || !hash.matches("[a-f0-9]{64}")) {
                result.error("invalid", "Invalid update information.", null); return;
            }
            try {
                if (code.longValue() <= version(activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0))) {
                    result.error("version", "You already have this version.", null); return;
                }
                if (Build.VERSION.SDK_INT >= 26 && !activity.getPackageManager().canRequestPackageInstalls()) {
                    activity.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName())));
                    result.success("permission"); return;
                }
            } catch (Exception e) { result.error("permission", "Unable to open installation settings.", null); return; }
            if (!BUSY.compareAndSet(false, true)) { result.error("busy", "An update is already downloading.", null); return; }
            new Thread(() -> {
                File target = null;
                try {
                    File dir = new File(activity.getCacheDir(), "idcolda-updates");
                    if (!dir.isDirectory() && !dir.mkdirs()) throw new IOException("cache");
                    File[] old = dir.listFiles();
                    if (old != null) for (File file : old) if (file.isFile()) file.delete();
                    target = new File(dir, "IDCOLDA-" + code.longValue() + ".apk");
                    HttpsURLConnection conn = (HttpsURLConnection)new URL(BASE + code.longValue()).openConnection();
                    conn.setConnectTimeout(15000); conn.setReadTimeout(30000); conn.setInstanceFollowRedirects(false);
                    conn.setRequestProperty("Accept-Encoding", "identity");
                    MessageDigest digest = MessageDigest.getInstance("SHA-256");
                    try {
                        int status = conn.getResponseCode();
                        if (status == 404 || status == 410) throw new ReleaseChangedException();
                        if (status != 200) throw new IOException("download");
                        long declared = conn.getContentLengthLong();
                        if (declared >= 0 && declared != size.longValue()) throw new IOException("length");
                        try (InputStream input = conn.getInputStream(); FileOutputStream output = new FileOutputStream(target)) {
                            byte[] buffer = new byte[65536]; long total = 0; int n, last = -1;
                            while ((n = input.read(buffer)) != -1) {
                                total += n;
                                if (total > size.longValue() || total > LIMIT) throw new IOException("size");
                                output.write(buffer, 0, n); digest.update(buffer, 0, n);
                                int percent = (int)(total * 100 / size.longValue());
                                if (percent != last) { last = percent; activity.runOnUiThread(() -> channel.invokeMethod("progress", percent)); }
                            }
                            if (total != size.longValue()) throw new IOException("incomplete");
                            output.getFD().sync();
                        }
                    } finally { conn.disconnect(); }
                    StringBuilder actual = new StringBuilder();
                    for (byte b : digest.digest()) actual.append(String.format(java.util.Locale.ROOT, "%02x", b & 255));
                    if (!actual.toString().equals(hash)) throw new SecurityException("integrity");
                    PackageManager pm = activity.getPackageManager();
                    PackageInfo installed = pm.getPackageInfo(activity.getPackageName(), PackageManager.GET_SIGNATURES);
                    PackageInfo candidate = pm.getPackageArchiveInfo(target.getAbsolutePath(), PackageManager.GET_SIGNATURES);
                    if (candidate == null || !activity.getPackageName().equals(candidate.packageName) ||
                        version(candidate) != code.longValue() || version(candidate) <= version(installed) ||
                        installed.signatures == null || candidate.signatures == null ||
                        installed.signatures.length != 1 || candidate.signatures.length != 1 ||
                        !installed.signatures[0].equals(candidate.signatures[0])) throw new SecurityException("signer");
                    final File verified = target;
                    activity.runOnUiThread(() -> {
                        try {
                            if (activity.isFinishing() || activity.isDestroyed()) throw new IllegalStateException("closed");
                            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName()+".updates", verified);
                            Intent intent = new Intent(Intent.ACTION_VIEW);
                            intent.setDataAndType(uri, "application/vnd.android.package-archive");
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                            activity.startActivity(intent);
                            result.success("installer");
                        } catch (Exception e) { result.error("installer", "Unable to open Android installer.", null); }
                        finally { BUSY.set(false); }
                    });
                } catch (Exception e) {
                    if (target != null) target.delete();
                    final boolean invalid = e instanceof SecurityException;
                    final boolean replaced = e instanceof ReleaseChangedException;
                    activity.runOnUiThread(() -> {
                        BUSY.set(false);
                        result.error(replaced?"release_changed":invalid?"verification":"download",
                            replaced?"A newer release is available. Checking again.":invalid?"The APK does not match the installed IDCOLDA app.":"Download failed. Check your connection and try again.",null);
                    });
                }
            }, "idcolda-apk-update").start();
        });
    }
}
