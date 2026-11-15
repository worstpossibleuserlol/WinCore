package com.winlator;

import android.app.ActivityManager;
import android.content.Context;
import android.os.Debug;
import android.os.Process;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public final class WinCoreSessionTracker {
    private static final String PREFS = "wincore_compatibility_center";
    private static final String KEY_HISTORY = "session_history";
    private static final String KEY_ACTIVE_START = "active_session_start";
    private static final String KEY_ACTIVE_CPU = "active_session_cpu";

    private WinCoreSessionTracker() { }

    public static void onSessionStart(Context context) {
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putLong(KEY_ACTIVE_START, System.currentTimeMillis())
                    .putLong(KEY_ACTIVE_CPU, Process.getElapsedCpuTime())
                    .putLong("active_session_pss", Debug.getPss())
                    .apply();
        } catch (Exception e) {
            Log.w("WinCoreSessionTracker", "Could not save session start.", e);
        }
    }

    public static void onSessionEnd(Context context) {
        try {
            android.content.SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            long start = preferences.getLong(KEY_ACTIVE_START, 0L);
            if (start == 0L) return;
            long end = System.currentTimeMillis();
            long cpuStart = preferences.getLong(KEY_ACTIVE_CPU, 0L);
            long pssStart = preferences.getLong("active_session_pss", 0L);
            ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
            ActivityManager manager = (ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
            manager.getMemoryInfo(memory);

            JSONObject item = new JSONObject();
            item.put("startedAt", start);
            item.put("endedAt", end);
            item.put("durationSeconds", Math.max(0L, (end - start) / 1000L));
            item.put("processCpuSeconds", Math.max(0L, (Process.getElapsedCpuTime() - cpuStart) / 1000L));
            item.put("startPssKiB", pssStart);
            item.put("endPssKiB", Debug.getPss());
            item.put("availableRamMiBAtEnd", memory.availMem / (1024 * 1024));
            JSONArray history;
            try { history = new JSONArray(preferences.getString(KEY_HISTORY, "[]")); }
            catch (JSONException ignored) { history = new JSONArray(); }
            history.put(item);
            while (history.length() > 30) history.remove(0);
            preferences.edit().putString(KEY_HISTORY, history.toString()).remove(KEY_ACTIVE_START).remove(KEY_ACTIVE_CPU).remove("active_session_pss").apply();
        } catch (Exception e) {
            Log.w("WinCoreSessionTracker", "Could not save session end.", e);
        }
    }

    public static String readHistory(Context context) {
        android.content.SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String raw = preferences.getString(KEY_HISTORY, "[]");
        try {
            JSONArray history = new JSONArray(raw);
            StringBuilder result = new StringBuilder();
            for (int i = history.length() - 1; i >= 0; i--) {
                JSONObject item = history.getJSONObject(i);
                result.append("Session ").append(i + 1).append(": ")
                        .append(item.optLong("durationSeconds")).append(" sec; CPU time ")
                        .append(item.optLong("processCpuSeconds")).append(" sec; PSS ")
                        .append(item.optLong("startPssKiB")).append(" -> ")
                        .append(item.optLong("endPssKiB")).append(" KiB; free RAM ")
                        .append(item.optLong("availableRamMiBAtEnd")).append(" MiB\n");
            }
            if (history.length() == 0) result.append("No completed Windows sessions have been recorded yet.");
            if (preferences.getLong(KEY_ACTIVE_START, 0L) != 0L) result.append("\nA previous session appears to have ended unexpectedly or is still active.");
            return result.toString();
        } catch (JSONException e) {
            return "Saved session history is unreadable.";
        }
    }
}
