package com.winlator;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.FeatureInfo;
import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Debug;
import android.os.PowerManager;
import android.os.Process;
import android.os.SystemClock;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.view.InputDevice;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;
import android.database.Cursor;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ImageView;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.preference.PreferenceManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Locale;
import java.util.Set;

public class WinCoreCompatibilityCenterActivity extends AppCompatActivity {
    private static final int PICK_EXE = 4101;
    private static final int PICK_GAME_FOLDER = 4102;
    private static final int EXPORT_PROFILE = 4103;
    private static final int IMPORT_PROFILE = 4104;
    private static final int EXPORT_BACKUP = 4105;
    private static final int IMPORT_BACKUP = 4106;
    private static final int EXPORT_REPORT = 4107;
    private static final int PICK_COVER = 4108;
    private static final String PREFS = "wincore_compatibility_center";
    private static final int MAX_EXE_BYTES = 64 * 1024 * 1024;

    private SharedPreferences store;
    private EditText gameName;
    private EditText launchArguments;
    private EditText environmentVariables;
    private EditText notes;
    private Spinner profileType;
    private Spinner box64Preset;
    private Spinner graphicsWrapper;
    private Spinner rating;
    private TextView executableLabel;
    private TextView folderLabel;
    private TextView output;
    private Uri executableUri;
    private Uri gameFolderUri;
    private JSONObject executableAnalysis = new JSONObject();
    private String pendingExport;
    private String pendingExportName = "WinCore-report.txt";
    private EditText customRules;
    private EditText gameCategory;
    private Spinner rendererProfile;
    private Spinner resolutionProfile;
    private ImageView gameCover;
    private Uri coverUri;
    private long v5CpuSampleTime;
    private long v5CpuSampleValue;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = getSharedPreferences(PREFS, MODE_PRIVATE);
        v5CpuSampleTime = SystemClock.elapsedRealtime();
        v5CpuSampleValue = Process.getElapsedCpuTime();
        long uiStart = SystemClock.elapsedRealtime();
        buildInterface();
        loadProfile();
        store.edit().putLong("last_center_startup_ms", Math.max(0L, SystemClock.elapsedRealtime() - uiStart)).apply();
        appendOutput("WinCore 6.0.0 Compatibility Center ready. Configuration recommendations remain separate from active Winlator runtime settings.");
    }

    private void buildInterface() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(store.getBoolean("compact_dashboard", false) ? 10 : 16);
        page.setPadding(pad, pad, pad, pad);
        scroll.addView(page);
        setContentView(scroll);

        TextView title = text("WinCore Compatibility Center", 23, true);
        page.addView(title);
        page.addView(text("Executable analysis • GTA IV diagnostics • device checks • profiles • reports", 13, false));
        page.addView(text("Existing Winlator containers, shortcuts, graphics controls, and controller settings remain the source of runtime configuration.", 13, false));

        gameCover = new ImageView(this);
        gameCover.setScaleType(ImageView.ScaleType.FIT_CENTER);
        gameCover.setAdjustViewBounds(true);
        page.addView(gameCover, new LinearLayout.LayoutParams(dp(140), dp(140)));
        addButton(page, "Choose game cover image", this::chooseGameCover);

        gameName = edit("Game name");
        gameCategory = edit("Game category");
        page.addView(gameCategory);
        page.addView(gameName);
        executableLabel = text("Executable: not selected", 12, false);
        page.addView(executableLabel);
        addButton(page, "Choose Windows executable", this::chooseExecutable);
        folderLabel = text("Game folder: not selected", 12, false);
        page.addView(folderLabel);
        addButton(page, "Choose game folder", this::chooseGameFolder);

        page.addView(text("Compatibility profile", 15, true));
        profileType = spinner(new String[]{"Automatic / inspect first", "Stability-first recommendation", "Balanced recommendation", "Performance recommendation", "GTA IV (DirectX 9) diagnostic profile"});
        page.addView(profileType);
        page.addView(text("Box64 recommendation (advisory)", 13, false));
        box64Preset = spinner(new String[]{"Automatic", "Stability", "Conservative", "Intermediate", "Performance"});
        page.addView(box64Preset);
        page.addView(text("Graphics wrapper recommendation (advisory)", 13, false));
        graphicsWrapper = spinner(new String[]{"Automatic", "DXVK", "WineD3D", "VKD3D"});
        page.addView(graphicsWrapper);
        page.addView(text("Renderer profile (advisory)", 13, false));
        rendererProfile = spinner(new String[]{"Automatic", "Turnip / Vulkan", "VirGL", "Zink", "WineD3D / OpenGL"});
        page.addView(rendererProfile);
        page.addView(text("Resolution profile (advisory)", 13, false));
        resolutionProfile = spinner(new String[]{"Default", "960 x 540", "1280 x 720", "1600 x 900", "1920 x 1080"});
        page.addView(resolutionProfile);
        page.addView(text("Launch arguments", 13, false));
        launchArguments = edit("Optional executable arguments");
        page.addView(launchArguments);
        page.addView(text("Environment variables (one KEY=VALUE per line)", 13, false));
        environmentVariables = edit("Example: DXVK_LOG_LEVEL=none");
        environmentVariables.setMinLines(3);
        environmentVariables.setGravity(Gravity.TOP | Gravity.START);
        page.addView(environmentVariables);
        page.addView(text("Audio, controller, and troubleshooting notes", 13, false));
        notes = edit("Notes for this game");
        notes.setMinLines(3);
        notes.setGravity(Gravity.TOP | Gravity.START);
        page.addView(notes);
        page.addView(text("Custom compatibility rules (one phrase per line; checked against captured logs)", 13, false));
        customRules = edit("Example: failed to create device");
        customRules.setMinLines(2);
        customRules.setGravity(Gravity.TOP | Gravity.START);
        page.addView(customRules);
        page.addView(text("Manual compatibility rating (your own test result)", 13, false));
        rating = spinner(new String[]{"Not tested", "1 / 5", "2 / 5", "3 / 5", "4 / 5", "5 / 5"});
        page.addView(rating);

        addSection(page, "GAME ANALYSIS");
        addButton(page, "Analyze executable (PE headers / imports / DirectX)", this::analyzeExecutable);
        addButton(page, "Scan game folder", this::scanGameFolder);
        addButton(page, "Run GTA IV diagnostic checks", this::runGtaIvChecks);
        addButton(page, "Check profile conflicts", this::checkProfileConflicts);

        addSection(page, "DEVICE AND SESSION");
        addButton(page, "Run device and launch-readiness check", this::runDeviceCheck);
        addButton(page, "Show session history and last-session summary", this::showSessionHistory);
        addButton(page, "Capture and filter WinCore / Winlator logs", this::captureLogs);
        addButton(page, "Build compatibility report", this::buildAndShowReport);
        addButton(page, "Share latest report", this::shareLatestReport);

        addSection(page, "PROFILE AND BACKUP");
        addButton(page, "Save game profile and version snapshot", this::saveProfile);
        addButton(page, "Compare with previous profile version", this::compareProfileVersions);
        addButton(page, "Roll back to previous profile version", this::rollbackProfile);
        addButton(page, "Export game profile JSON", this::exportProfile);
        addButton(page, "Import game profile JSON", this::importProfile);
        addButton(page, "Back up WinCore / Winlator preferences", this::exportSettingsBackup);
        addButton(page, "Restore preferences from backup", this::importSettingsBackup);
        addButton(page, "Show compatibility troubleshooting guide", this::showTroubleshooting);


        addSection(page, "WINCORE 5.0.0 — EXISTING COMPATIBILITY TOOLS (RETAINED)");
        addButton(page, "01  Automatic game detection", this::detectGameExecutables);
        addButton(page, "02  Executable analyzer", this::analyzeExecutable);
        addButton(page, "03  Per-game profile manager", this::saveProfile);
        addButton(page, "04  Local compatibility database", this::showCompatibilityDatabase);
        addButton(page, "05  Automatic profile matching", this::matchCompatibilityProfile);
        addButton(page, "06  Wine version advisor", this::wineVersionAdvisor);
        addButton(page, "07  Box64 preset advisor", this::box64PresetAdvisor);
        addButton(page, "08  DirectX requirement detection", this::analyzeExecutable);
        addButton(page, "09  Graphics wrapper checker", this::checkGraphicsWrapper);
        addButton(page, "10  Launch argument manager", this::showLaunchArguments);
        addButton(page, "11  RAM pressure monitor", this::showMemoryPressure);
        addButton(page, "12  Low-memory warning system", this::warnLowMemory);
        addButton(page, "13  CPU load snapshot", this::cpuSnapshot);
        addButton(page, "14  Thermal awareness", this::runDeviceCheck);
        addButton(page, "15  Battery performance recommendations", this::batteryPerformanceAdvisor);
        addButton(page, "16  Background process awareness", this::backgroundProcessWarning);
        addButton(page, "17  Per-game performance preferences", this::saveProfile);
        addButton(page, "18  Resolution advisor", this::resolutionAdvisor);
        addButton(page, "19  Frame-pacing diagnostics status", this::framePacingStatus);
        addButton(page, "20  Session performance report", this::showSessionHistory);
        addButton(page, "21  GTA IV dedicated profile", this::createGtaIvProfile);
        addButton(page, "22  GTA IV executable detection", this::detectGameExecutables);
        addButton(page, "23  GTA IV DirectX 9 check", this::runGtaIvChecks);
        addButton(page, "24  GTA IV component presence check", this::checkGtaComponents);
        addButton(page, "25  Controller diagnostics", this::checkControllerDevices);
        addButton(page, "26  Audio device diagnostics", this::checkAudioOutput);
        addButton(page, "27  GTA IV save-data clue check", this::checkGtaSaveData);
        addButton(page, "28  GTA IV profile backup", this::exportProfile);
        addButton(page, "29  Crash / failure log report", this::captureLogs);
        addButton(page, "30  GTA IV compatibility summary", this::runGtaIvChecks);
        addButton(page, "31  Wine log viewer", () -> showFilteredLogs("wine"));
        addButton(page, "32  Box64 log viewer", () -> showFilteredLogs("box64"));
        addButton(page, "33  Missing DLL log detector", this::detectMissingDlls);
        addButton(page, "34  Graphics initialization diagnostics", this::diagnoseGraphicsInitialization);
        addButton(page, "35  Vulkan capability checker", this::showVulkanCapabilities);
        addButton(page, "36  Selected game-folder health report", this::showFolderHealthReport);
        addButton(page, "37  Configuration conflict detector", this::checkProfileConflicts);
        addButton(page, "38  WinCore settings backup", this::exportSettingsBackup);
        addButton(page, "39  Previous profile rollback", this::rollbackProfile);
        addButton(page, "40  Diagnostic report export", this::buildAndShowReport);
        addButton(page, "41  Shared profile import / export", () -> {
            appendOutput("Use the Import game profile JSON or Export game profile JSON controls in Profile and Backup.");
        });
        addButton(page, "42  Local shared-profile library", this::showLocalProfileLibrary);
        addButton(page, "43  Profile version history", this::showProfileVersionHistory);
        addButton(page, "44  Container backup checklist", this::showContainerBackupChecklist);
        addButton(page, "45  Container migration assistant", this::showContainerMigrationAssistant);
        addButton(page, "46  Launch history", this::showSessionHistory);
        addButton(page, "47  Compatibility rating", this::saveProfile);
        addButton(page, "48  Custom compatibility rules", this::evaluateCustomRules);
        addButton(page, "49  Profile comparison", this::compareProfileVersions);
        addButton(page, "50  Compatibility dashboard summary", this::showDashboardSummary);


        addSection(page, "WINCORE 6.0.0 — AUTOMATION & STABILITY (50 FEATURES)");
        addButton(page, "01  Automatic game profiles", this::createOrRefreshAutomaticProfile);
        addButton(page, "02  Game version and file metadata", this::detectGameVersionMetadata);
        addButton(page, "03  Multi-executable game detection", this::detectGameExecutables);
        addButton(page, "04  Per-game settings presets", this::showPerGamePresets);
        addButton(page, "05  Automatic profile selection", this::matchCompatibilityProfile);
        addButton(page, "06  Game configuration comparison", this::compareProfileVersions);
        addButton(page, "07  Profile change history", this::showProfileVersionHistory);
        addButton(page, "08  One-tap profile restore", this::rollbackProfile);
        addButton(page, "09  Game-specific environment variables", this::showEnvironmentVariables);
        addButton(page, "10  Launch argument manager", this::showLaunchArguments);
        addButton(page, "11  Graphics compatibility scanner", this::runGraphicsCompatibilityScan);
        addButton(page, "12  Vulkan capability details", this::showVulkanCapabilities);
        addButton(page, "13  OpenGL capability details", this::showOpenGlCapabilities);
        addButton(page, "14  DXVK configuration manager", this::showDxvkManager);
        addButton(page, "15  VKD3D configuration manager", this::showVkd3dManager);
        addButton(page, "16  Graphics wrapper compatibility checks", this::checkGraphicsWrapper);
        addButton(page, "17  Renderer selection profiles", this::showRendererProfiles);
        addButton(page, "18  Resolution profiles", this::showResolutionProfiles);
        addButton(page, "19  Fullscreen compatibility checks", this::checkFullscreenSettings);
        addButton(page, "20  Graphics error analyzer", this::diagnoseGraphicsInitialization);
        addButton(page, "21  Memory pressure history", this::recordMemorySample);
        addButton(page, "22  Thermal history", this::recordThermalSample);
        addButton(page, "23  Battery impact report", this::showBatteryImpactReport);
        addButton(page, "24  Background application warning", this::backgroundProcessWarning);
        addButton(page, "25  Launch resource estimator", this::estimateLaunchResources);
        addButton(page, "26  CPU profile comparison", this::compareCpuProfiles);
        addButton(page, "27  Session stability tracker", this::showStabilityTracker);
        addButton(page, "28  Startup time history", this::showStartupTimeHistory);
        addButton(page, "29  Low-storage warnings", this::checkLowStorage);
        addButton(page, "30  Performance report export", this::exportSessionPerformanceReport);
        addButton(page, "31  Crash report timeline", this::showCrashTimeline);
        addButton(page, "32  Diagnostic bundle export", this::exportDiagnosticBundle);
        addButton(page, "33  Wine error categorization", this::categorizeWineErrors);
        addButton(page, "34  Box64 error categorization", this::categorizeBox64Errors);
        addButton(page, "35  Missing component suggestions", this::suggestMissingComponents);
        addButton(page, "36  Selected folder integrity comparison", this::compareContainerIntegrity);
        addButton(page, "37  Configuration conflict detection", this::checkProfileConflicts);
        addButton(page, "38  Pre-launch configuration backup", this::preLaunchBackup);
        addButton(page, "39  Recovery mode", this::enterRecoveryMode);
        addButton(page, "40  Diagnostic report comparison", this::compareDiagnosticReports);
        addButton(page, "41  Game library categories", this::assignGameCategory);
        addButton(page, "42  Game cover images", this::chooseGameCover);
        addButton(page, "43  Custom game notes", this::showGameNotes);
        addButton(page, "44  Favorite games", this::toggleFavorite);
        addButton(page, "45  Recent game activity", this::showRecentActivity);
        addButton(page, "46  Profile import validation", this::validateImportedProfile);
        addButton(page, "47  Profile export validation", this::validateExportedProfile);
        addButton(page, "48  Settings migration assistant", this::showContainerMigrationAssistant);
        addButton(page, "49  Custom dashboard layout", this::toggleDashboardLayout);
        addButton(page, "50  Compatibility Center 2.0 dashboard", this::showDashboardSummary);

        output = text("Results will appear here.", 12, false);
        output.setTextIsSelectable(true);
        output.setPadding(dp(12), dp(12), dp(12), dp(12));
        page.addView(output);
    }

    private TextView text(String value, int size, boolean bold) {
        TextView v = new TextView(this);
        v.setText(value);
        v.setTextSize(size);
        if (bold) v.setTypeface(null, android.graphics.Typeface.BOLD);
        v.setPadding(0, dp(5), 0, dp(5));
        return v;
    }

    private EditText edit(String hint) {
        EditText v = new EditText(this);
        v.setHint(hint);
        v.setTextColor(0xffffffff);
        v.setHintTextColor(0xffb8c0c8);
        v.setSingleLine(false);
        v.setTextSize(14);
        v.setPadding(dp(10), dp(8), dp(10), dp(8));
        return v;
    }

    private Spinner spinner(String[] values) {
        Spinner v = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, values);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        v.setAdapter(adapter);
        return v;
    }

    private void addButton(LinearLayout parent, String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setOnClickListener(v -> action.run());
        parent.addView(button, new LinearLayout.LayoutParams(-1, -2));
    }

    private void addSection(LinearLayout parent, String label) {
        TextView heading = text(label, 16, true);
        heading.setPadding(0, dp(18), 0, dp(4));
        parent.addView(heading);
        View divider = new View(this);
        divider.setBackgroundColor(0xff777777);
        parent.addView(divider, new LinearLayout.LayoutParams(-1, dp(1)));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String gameKey() {
        String name = gameName.getText().toString().trim().toLowerCase(Locale.ROOT);
        if (name.isEmpty()) name = "default";
        return name.replaceAll("[^a-z0-9._-]+", "_");
    }

    private JSONObject readFormProfile() {
        JSONObject profile = new JSONObject();
        try {
            profile.put("format", "wincore-game-profile-v1");
            profile.put("gameName", gameName.getText().toString().trim());
            profile.put("category", gameCategory.getText().toString().trim());
            profile.put("coverUri", coverUri == null ? "" : coverUri.toString());
            profile.put("rendererProfile", rendererProfile.getSelectedItem().toString());
            profile.put("resolutionProfile", resolutionProfile.getSelectedItem().toString());
            profile.put("executableUri", executableUri == null ? "" : executableUri.toString());
            profile.put("folderUri", gameFolderUri == null ? "" : gameFolderUri.toString());
            profile.put("profileType", profileType.getSelectedItem().toString());
            profile.put("box64Recommendation", box64Preset.getSelectedItem().toString());
            profile.put("graphicsWrapperRecommendation", graphicsWrapper.getSelectedItem().toString());
            profile.put("launchArguments", launchArguments.getText().toString());
            profile.put("environmentVariables", environmentVariables.getText().toString());
            profile.put("notes", notes.getText().toString());
            profile.put("rating", rating.getSelectedItem().toString());
            profile.put("updatedAt", System.currentTimeMillis());
            profile.put("analysis", executableAnalysis);
        } catch (JSONException ignored) { }
        return profile;
    }

    private void loadProfile() {
        String key = gameKey();
        String raw = store.getString("profile_" + key, null);
        if (raw == null) return;
        try {
            applyProfile(new JSONObject(raw));
        } catch (JSONException e) {
            appendOutput("Saved profile could not be read. The original data has been left untouched.");
        }
    }

    private void applyProfile(JSONObject profile) {
        gameName.setText(profile.optString("gameName", ""));
        gameCategory.setText(profile.optString("category", ""));
        String cover = profile.optString("coverUri", store.getString("cover_" + gameKey(), ""));
        coverUri = cover.isEmpty() ? null : Uri.parse(cover);
        if (gameCover != null && coverUri != null) gameCover.setImageURI(coverUri);
        select(rendererProfile, profile.optString("rendererProfile", "Automatic"));
        select(resolutionProfile, profile.optString("resolutionProfile", "Default"));
        String exe = profile.optString("executableUri", "");
        String folder = profile.optString("folderUri", "");
        executableUri = exe.isEmpty() ? null : Uri.parse(exe);
        gameFolderUri = folder.isEmpty() ? null : Uri.parse(folder);
        executableLabel.setText(exe.isEmpty() ? "Executable: not selected" : "Executable: " + displayName(executableUri));
        folderLabel.setText(folder.isEmpty() ? "Game folder: not selected" : "Game folder: selected");
        select(profileType, profile.optString("profileType", ""));
        select(box64Preset, profile.optString("box64Recommendation", ""));
        select(graphicsWrapper, profile.optString("graphicsWrapperRecommendation", ""));
        launchArguments.setText(profile.optString("launchArguments", ""));
        environmentVariables.setText(profile.optString("environmentVariables", ""));
        notes.setText(profile.optString("notes", ""));
        select(rating, profile.optString("rating", "Not tested"));
        executableAnalysis = profile.optJSONObject("analysis") == null ? new JSONObject() : profile.optJSONObject("analysis");
    }

    private void select(Spinner spinner, String value) {
        if (value == null || value.isEmpty()) return;
        for (int i = 0; i < spinner.getCount(); i++) {
            if (value.equals(spinner.getItemAtPosition(i).toString())) {
                spinner.setSelection(i);
                return;
            }
        }
    }

    private void chooseExecutable() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("*/*");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, PICK_EXE);
    }

    private void chooseGameCover() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("image/*");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try { startActivityForResult(intent, PICK_COVER); }
        catch (ActivityNotFoundException e) { appendOutput("No image picker is available."); }
    }

    private void chooseGameFolder() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, PICK_GAME_FOLDER);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        try {
            getContentResolver().takePersistableUriPermission(uri, data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION));
        } catch (Exception ignored) { }

        if (requestCode == PICK_COVER) {
            coverUri = uri;
            store.edit().putString("cover_" + gameKey(), uri.toString()).apply();
            if (gameCover != null) gameCover.setImageURI(uri);
            appendOutput("Game cover image selected. It is stored as a document URI for this game profile.");
        } else if (requestCode == PICK_EXE) {
            executableUri = uri;
            executableLabel.setText("Executable: " + displayName(uri));
            analyzeExecutable();
        } else if (requestCode == PICK_GAME_FOLDER) {
            gameFolderUri = uri;
            folderLabel.setText("Game folder: selected");
            appendOutput("Game folder permission saved. Use Scan game folder to inspect its top-level and nearby files.");
        } else if (requestCode == EXPORT_PROFILE || requestCode == EXPORT_BACKUP || requestCode == EXPORT_REPORT) {
            writeExport(uri);
        } else if (requestCode == IMPORT_PROFILE || requestCode == IMPORT_BACKUP) {
            readImport(uri, requestCode == IMPORT_BACKUP);
        }
    }

    private String displayName(Uri uri) {
        if (uri == null) return "Unknown";
        Cursor cursor = null;
        try {
            cursor = getContentResolver().query(uri, new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null);
            if (cursor != null && cursor.moveToFirst()) return cursor.getString(0);
        } catch (Exception ignored) { }
        finally { if (cursor != null) cursor.close(); }
        return uri.getLastPathSegment() == null ? "Selected file" : uri.getLastPathSegment();
    }

    private void analyzeExecutable() {
        if (executableUri == null) {
            appendOutput("Select a Windows .exe file first.");
            return;
        }
        try (InputStream input = getContentResolver().openInputStream(executableUri)) {
            if (input == null) throw new IOException("The selected file could not be opened.");
            byte[] data = readBounded(input, MAX_EXE_BYTES);
            JSONObject result = analyzePe(data);
            result.put("fileName", displayName(executableUri));
            result.put("truncatedAt64MiB", data.length >= MAX_EXE_BYTES);
            executableAnalysis = result;
            appendOutput("EXECUTABLE ANALYSIS\n" + result.toString(2));
            String detected = result.optString("directX", "Unknown");
            if ("DirectX 9".equals(detected)) {
                select(profileType, "GTA IV (DirectX 9) diagnostic profile");
                select(graphicsWrapper, "DXVK");
            }
        } catch (Exception e) {
            appendOutput("Executable analysis failed safely: " + e.getMessage());
        }
    }

    private byte[] readBounded(InputStream input, int limit) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int total = 0;
        int count;
        while ((count = input.read(buffer)) != -1 && total < limit) {
            int allowed = Math.min(count, limit - total);
            output.write(buffer, 0, allowed);
            total += allowed;
        }
        return output.toByteArray();
    }

    private JSONObject analyzePe(byte[] bytes) throws JSONException {
        JSONObject result = new JSONObject();
        JSONArray imports = new JSONArray();
        result.put("format", "unknown");
        result.put("architecture", "Unknown");
        result.put("directX", "Not detected");
        if (bytes.length < 0x40 || u16(bytes, 0) != 0x5a4d) {
            result.put("error", "The file does not have a valid DOS MZ header.");
            return result;
        }
        int peOffset = i32(bytes, 0x3c);
        if (!valid(bytes, peOffset, 24) || i32(bytes, peOffset) != 0x00004550) {
            result.put("error", "The PE signature is missing or outside the scanned file range.");
            return result;
        }
        int machine = u16(bytes, peOffset + 4);
        String arch = machine == 0x14c ? "x86" : machine == 0x8664 ? "x86-64" : machine == 0x1c0 ? "ARM" : machine == 0xaa64 ? "ARM64" : "Unknown (0x" + Integer.toHexString(machine) + ")";
        result.put("format", "Portable Executable");
        result.put("architecture", arch);
        int sections = u16(bytes, peOffset + 6);
        int optionalSize = u16(bytes, peOffset + 20);
        int optional = peOffset + 24;
        if (!valid(bytes, optional, optionalSize) || optionalSize < 96) {
            result.put("error", "The PE optional header is incomplete.");
            return result;
        }
        int magic = u16(bytes, optional);
        boolean pe32Plus = magic == 0x20b;
        int directories = optional + (pe32Plus ? 112 : 96);
        int sizeOfHeaders = i32(bytes, optional + 60);
        int importRva = valid(bytes, directories, 16) ? i32(bytes, directories + 8) : 0;
        int sectionTable = optional + optionalSize;
        int[] virtualAddress = new int[Math.max(0, Math.min(sections, 96))];
        int[] virtualSize = new int[virtualAddress.length];
        int[] rawPointer = new int[virtualAddress.length];
        int[] rawSize = new int[virtualAddress.length];
        for (int i = 0; i < virtualAddress.length; i++) {
            int offset = sectionTable + i * 40;
            if (!valid(bytes, offset, 40)) break;
            virtualSize[i] = i32(bytes, offset + 8);
            virtualAddress[i] = i32(bytes, offset + 12);
            rawSize[i] = i32(bytes, offset + 16);
            rawPointer[i] = i32(bytes, offset + 20);
        }
        if (importRva > 0) {
            int importOffset = rvaOffset(importRva, sizeOfHeaders, virtualAddress, virtualSize, rawPointer, rawSize);
            for (int i = 0; i < 512 && valid(bytes, importOffset + i * 20, 20); i++) {
                int descriptor = importOffset + i * 20;
                int nameRva = i32(bytes, descriptor + 12);
                if (nameRva == 0) break;
                int nameOffset = rvaOffset(nameRva, sizeOfHeaders, virtualAddress, virtualSize, rawPointer, rawSize);
                String dll = readCString(bytes, nameOffset, 128);
                if (!dll.isEmpty()) imports.put(dll.toLowerCase(Locale.ROOT));
            }
        }
        result.put("imports", imports);
        result.put("directX", detectDirectX(imports));
        result.put("importCount", imports.length());
        result.put("pe32Plus", pe32Plus);
        return result;
    }

    private int rvaOffset(int rva, int headersSize, int[] va, int[] vs, int[] raw, int[] rawLen) {
        if (rva >= 0 && rva < headersSize) return rva;
        for (int i = 0; i < va.length; i++) {
            long span = Math.max(vs[i], rawLen[i]);
            if (rva >= va[i] && (long)rva < (long)va[i] + span) return raw[i] + rva - va[i];
        }
        return -1;
    }

    private String detectDirectX(JSONArray imports) {
        boolean d3d9 = false, d3d10 = false, d3d11 = false, d3d12 = false, d3d8 = false;
        for (int i = 0; i < imports.length(); i++) {
            String name = imports.optString(i, "").toLowerCase(Locale.ROOT);
            d3d8 |= name.equals("d3d8.dll");
            d3d9 |= name.equals("d3d9.dll") || name.equals("d3d9d.dll");
            d3d10 |= name.equals("d3d10.dll") || name.equals("d3d10_1.dll");
            d3d11 |= name.equals("d3d11.dll");
            d3d12 |= name.equals("d3d12.dll");
        }
        if (d3d12) return "DirectX 12";
        if (d3d11) return "DirectX 11";
        if (d3d10) return "DirectX 10";
        if (d3d9) return "DirectX 9";
        if (d3d8) return "DirectX 8";
        return "No Direct3D import detected";
    }

    private static boolean valid(byte[] bytes, int offset, int length) {
        return offset >= 0 && length >= 0 && (long)offset + length <= bytes.length;
    }

    private static int u16(byte[] b, int o) {
        if (!valid(b, o, 2)) return 0;
        return (b[o] & 255) | ((b[o + 1] & 255) << 8);
    }

    private static int i32(byte[] b, int o) {
        if (!valid(b, o, 4)) return 0;
        return (b[o] & 255) | ((b[o + 1] & 255) << 8) | ((b[o + 2] & 255) << 16) | (b[o + 3] << 24);
    }

    private static String readCString(byte[] b, int offset, int max) {
        if (!valid(b, offset, 1)) return "";
        int end = offset;
        while (end < b.length && end - offset < max && b[end] != 0) end++;
        return new String(b, offset, end - offset, StandardCharsets.US_ASCII);
    }

    private void scanGameFolder() {
        if (gameFolderUri == null) {
            appendOutput("Select a game folder first.");
            return;
        }
        try {
            Set<String> files = scanTree(gameFolderUri);
            ArrayList<String> sorted = new ArrayList<>(files);
            Collections.sort(sorted);
            StringBuilder result = new StringBuilder("GAME FOLDER SCAN\nFiles inspected: ").append(files.size()).append("\n");
            for (String file : sorted) {
                if (file.endsWith(".exe") || file.endsWith(".dll") || file.endsWith(".rpf") || file.equals("settings.dat")) result.append(" • ").append(file).append("\n");
            }
            if (sorted.size() > 0) {
                result.append("\nGTA IV indicators:\n");
                result.append("GTAIV.exe: ").append(files.contains("gtaiv.exe") ? "present" : "not found").append("\n");
                result.append("PlayGTAIV.exe: ").append(files.contains("playgtaiv.exe") ? "present" : "not found").append("\n");
                result.append("common.rpf: ").append(files.contains("common.rpf") ? "present" : "not found").append("\n");
            }
            appendOutput(result.toString());
        } catch (Exception e) {
            appendOutput("Folder scan could not complete: " + e.getMessage());
        }
    }

    private Set<String> scanTree(Uri treeUri) throws Exception {
        HashSet<String> names = new HashSet<>();
        ArrayDeque<TreeNode> queue = new ArrayDeque<>();
        String rootId = DocumentsContract.getTreeDocumentId(treeUri);
        queue.add(new TreeNode(rootId, 0));
        int inspected = 0;
        while (!queue.isEmpty() && inspected < 3000) {
            TreeNode node = queue.removeFirst();
            Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, node.id);
            try (Cursor cursor = getContentResolver().query(children,
                    new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE},
                    null, null, null)) {
                if (cursor == null) continue;
                while (cursor.moveToNext() && inspected < 3000) {
                    inspected++;
                    String id = cursor.getString(0);
                    String name = cursor.getString(1);
                    String mime = cursor.getString(2);
                    if (name != null) names.add(name.toLowerCase(Locale.ROOT));
                    if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mime) && node.depth < 3) queue.addLast(new TreeNode(id, node.depth + 1));
                }
            }
        }
        return names;
    }

    private static class TreeNode {
        final String id;
        final int depth;
        TreeNode(String id, int depth) { this.id = id; this.depth = depth; }
    }

    private void runGtaIvChecks() {
        StringBuilder result = new StringBuilder("GTA IV COMPATIBILITY CHECK\n");
        result.append("Expected graphics API: Direct3D 9. The selected executable import scan says: ")
                .append(executableAnalysis.optString("directX", "not analyzed")).append("\n");
        result.append("Executable selected: ").append(executableUri != null).append("\n");
        result.append("Game folder selected: ").append(gameFolderUri != null).append("\n");
        if (gameFolderUri != null) {
            try {
                Set<String> files = scanTree(gameFolderUri);
                result.append("GTAIV.exe: ").append(files.contains("gtaiv.exe") ? "present" : "missing/not found").append("\n");
                result.append("PlayGTAIV.exe: ").append(files.contains("playgtaiv.exe") ? "present" : "not found").append("\n");
                result.append("common.rpf: ").append(files.contains("common.rpf") ? "present" : "not found").append("\n");
                result.append("Save-data clue: ").append(files.contains("settings.dat") ? "settings.dat found in selected tree" : "no settings.dat found in scanned depth").append("\n");
            } catch (Exception e) {
                result.append("Folder scan error: ").append(e.getMessage()).append("\n");
            }
        } else {
            result.append("Select the game folder to run the file-presence checks.\n");
        }
        result.append("\nSuggested starting point: preserve your current container; record one change at a time; compare Wine, Box64, and graphics-wrapper logs. No setting here guarantees GTA IV will launch.");
        appendOutput(result.toString());
    }

    private void checkProfileConflicts() {
        String dx = executableAnalysis.optString("directX", "");
        String wrapper = graphicsWrapper.getSelectedItem().toString();
        StringBuilder result = new StringBuilder("PROFILE VALIDATION\n");
        if (dx.contains("12") && wrapper.equals("DXVK")) result.append("Potential mismatch: DirectX 12 imports normally call for a VKD3D-Proton evaluation, not a DXVK-only recommendation.\n");
        else if (dx.contains("8") || dx.contains("9") || dx.contains("10") || dx.contains("11")) result.append("Direct3D import detected. Compare DXVK and WineD3D in a duplicate container; selection is not automatically applied.\n");
        else result.append("No clear Direct3D import was detected. Keep the wrapper on Automatic until you confirm the game's API.\n");
        String env = environmentVariables.getText().toString().trim();
        if (!env.isEmpty()) {
            for (String line : env.split("\\R")) {
                String trimmed = line.trim();
                if (!trimmed.isEmpty() && (!trimmed.contains("=") || trimmed.startsWith("="))) result.append("Invalid environment-variable line: ").append(trimmed).append("\n");
            }
        }
        result.append("Box64 setting: ").append(box64Preset.getSelectedItem()).append(" (profile recommendation only).");
        appendOutput(result.toString());
    }

    private void runDeviceCheck() {
        StringBuilder result = new StringBuilder("DEVICE / LAUNCH READINESS\n");
        result.append("Android: ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
        result.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
        result.append("CPU cores: ").append(Runtime.getRuntime().availableProcessors()).append("\n");
        result.append("Supported ABIs: ");
        for (int i = 0; i < Build.SUPPORTED_ABIS.length; i++) result.append(i == 0 ? "" : ", ").append(Build.SUPPORTED_ABIS[i]);
        result.append("\n");
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        ActivityManager manager = (ActivityManager)getSystemService(ACTIVITY_SERVICE);
        manager.getMemoryInfo(memory);
        result.append("RAM available: ").append(memory.availMem / (1024 * 1024)).append(" MiB / ").append(memory.totalMem / (1024 * 1024)).append(" MiB\n");
        result.append("Android low-memory state: ").append(memory.lowMemory ? "yes" : "no").append("\n");
        result.append("App PSS: ").append(Debug.getPss()).append(" KiB\n");
        result.append("Battery temperature: ").append(readBatteryTemperature()).append("\n");
        result.append("Thermal status: ").append(readThermalStatus()).append("\n");
        result.append("Vulkan support: ").append(readVulkanFeature()).append("\n");
        result.append("OpenGL ES requirement: ").append(readGlesFeature()).append("\n");
        result.append("Readiness: ").append(memory.lowMemory ? "low memory; close unused apps and avoid a heavy launch" : "Android does not currently report low memory").append("\n");
        result.append("CPU tuning: ").append(Runtime.getRuntime().availableProcessors() >= 8 ? "an 8+ logical-core CPU is exposed; this does not prove all cores are fast cores" : "limited logical-core count; prioritize stable settings").append("\n");
        result.append("No GPU utilization or in-game FPS is inferred by this report.");
        appendOutput(result.toString());
    }

    private String readBatteryTemperature() {
        try {
            Intent intent = registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (intent == null) return "unavailable";
            int tenths = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Integer.MIN_VALUE);
            return tenths == Integer.MIN_VALUE ? "unavailable" : String.format(Locale.ROOT, "%.1f °C", tenths / 10.0);
        } catch (Exception e) { return "unavailable"; }
    }

    private String readThermalStatus() {
        if (Build.VERSION.SDK_INT < 29) return "not exposed on this Android version";
        try {
            PowerManager pm = (PowerManager)getSystemService(POWER_SERVICE);
            int status = pm.getCurrentThermalStatus();
            String[] names = {"None", "Light", "Moderate", "Severe", "Critical", "Emergency", "Shutdown"};
            return status >= 0 && status < names.length ? names[status] : "unknown (" + status + ")";
        } catch (Exception e) { return "unavailable"; }
    }

    private String readVulkanFeature() {
        try {
            for (FeatureInfo feature : getPackageManager().getSystemAvailableFeatures()) {
                if (feature.name == null) continue;
                if (feature.name.equals("android.hardware.vulkan.version")) return "version 0x" + Integer.toHexString(feature.version);
                if (feature.name.equals("android.hardware.vulkan.level")) return "hardware level " + feature.version;
            }
        } catch (Exception ignored) { }
        return "not reported by PackageManager";
    }

    private String readGlesFeature() {
        try {
            for (FeatureInfo feature : getPackageManager().getSystemAvailableFeatures()) {
                if (feature.reqGlEsVersion > 0) return String.format(Locale.ROOT, "%d.%d", (feature.reqGlEsVersion >> 16) & 0xffff, feature.reqGlEsVersion & 0xffff);
            }
        } catch (Exception ignored) { }
        return "not reported";
    }

    private void saveProfile() {
        JSONObject next = readFormProfile();
        String key = gameKey();
        String prefKey = "profile_" + key;
        String previous = store.getString(prefKey, null);
        JSONArray history = historyFor(key);
        if (previous != null) history.put(previous);
        while (history.length() > 10) history.remove(0);
        store.edit().putString(prefKey, next.toString()).putString("history_" + key, history.toString()).apply();
        recordRecentGame();
        appendOutput("Profile saved locally. Version snapshots kept: " + history.length() + ".");
    }

    private JSONArray historyFor(String key) {
        try { return new JSONArray(store.getString("history_" + key, "[]")); }
        catch (JSONException e) { return new JSONArray(); }
    }

    private void compareProfileVersions() {
        JSONArray history = historyFor(gameKey());
        if (history.length() == 0) {
            appendOutput("No previous saved version exists yet.");
            return;
        }
        try {
            JSONObject old = new JSONObject(history.getString(history.length() - 1));
            JSONObject current = readFormProfile();
            StringBuilder diff = new StringBuilder("PROFILE DIFF (previous -> current)\n");
            JSONArray keys = current.names();
            if (keys != null) for (int i = 0; i < keys.length(); i++) {
                String key = keys.optString(i);
                String before = old.optString(key, "<not saved>");
                String after = current.optString(key, "");
                if (!before.equals(after)) diff.append(key).append(": ").append(before).append(" -> ").append(after).append("\n");
            }
            appendOutput(diff.toString());
        } catch (JSONException e) { appendOutput("Previous profile version is unreadable."); }
    }

    private void rollbackProfile() {
        JSONArray history = historyFor(gameKey());
        if (history.length() == 0) {
            appendOutput("There is no previous version to restore.");
            return;
        }
        try {
            JSONObject previous = new JSONObject(history.getString(history.length() - 1));
            history.remove(history.length() - 1);
            applyProfile(previous);
            store.edit().putString("profile_" + gameKey(), previous.toString()).putString("history_" + gameKey(), history.toString()).apply();
            appendOutput("Previous saved game-profile version restored. This does not revert Wine/container files.");
        } catch (JSONException e) { appendOutput("Rollback could not read the previous profile."); }
    }

    private void exportProfile() {
        pendingExport = readFormProfile().toString();
        pendingExportName = gameKey() + "-wincore-profile.json";
        createExportIntent("application/json", pendingExportName, EXPORT_PROFILE);
    }

    private void importProfile() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("application/json");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(intent, IMPORT_PROFILE);
    }

    private void exportSettingsBackup() {
        try {
            JSONObject root = new JSONObject();
            root.put("format", "wincore-preferences-backup-v1");
            root.put("createdAt", System.currentTimeMillis());
            JSONObject values = new JSONObject();
            SharedPreferences all = PreferenceManager.getDefaultSharedPreferences(this);
            for (String key : all.getAll().keySet()) {
                Object value = all.getAll().get(key);
                if (value instanceof Set) {
                    JSONArray array = new JSONArray();
                    for (Object item : (Set<?>)value) array.put(String.valueOf(item));
                    values.put(key, array);
                } else if (value instanceof String || value instanceof Number || value instanceof Boolean) values.put(key, value);
            }
            root.put("preferences", values);
            pendingExport = root.toString(2);
            pendingExportName = "wincore-preferences-backup.json";
            createExportIntent("application/json", pendingExportName, EXPORT_BACKUP);
        } catch (JSONException e) { appendOutput("Could not serialize preferences backup."); }
    }

    private void importSettingsBackup() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("application/json");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(intent, IMPORT_BACKUP);
    }

    private void createExportIntent(String mime, String name, int request) {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(mime);
        intent.putExtra(Intent.EXTRA_TITLE, name);
        startActivityForResult(intent, request);
    }

    private void writeExport(Uri uri) {
        if (pendingExport == null) return;
        try (OutputStream stream = getContentResolver().openOutputStream(uri)) {
            if (stream == null) throw new IOException("The document provider did not open the destination.");
            stream.write(pendingExport.getBytes(StandardCharsets.UTF_8));
            appendOutput("Exported: " + pendingExportName);
        } catch (Exception e) { appendOutput("Export failed: " + e.getMessage()); }
        pendingExport = null;
    }

    private void readImport(Uri uri, boolean settingsBackup) {
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            if (input == null) throw new IOException("The selected document could not be opened.");
            byte[] bytes = readBounded(input, 4 * 1024 * 1024);
            JSONObject root = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
            if (settingsBackup) {
                if (!"wincore-preferences-backup-v1".equals(root.optString("format"))) throw new JSONException("Not a WinCore preferences backup.");
                JSONObject values = root.getJSONObject("preferences");
                SharedPreferences.Editor editor = PreferenceManager.getDefaultSharedPreferences(this).edit();
                Iterator<String> keys = values.keys();
                while (keys.hasNext()) {
                    String key = keys.next();
                    Object value = values.get(key);
                    if (value instanceof Boolean) editor.putBoolean(key, (Boolean)value);
                    else if (value instanceof Integer) editor.putInt(key, (Integer)value);
                    else if (value instanceof Long) editor.putLong(key, (Long)value);
                    else if (value instanceof Double) editor.putFloat(key, ((Double)value).floatValue());
                    else if (value instanceof String) editor.putString(key, (String)value);
                    else if (value instanceof JSONArray) {
                        HashSet<String> set = new HashSet<>();
                        JSONArray array = (JSONArray)value;
                        for (int i = 0; i < array.length(); i++) set.add(array.optString(i));
                        editor.putStringSet(key, set);
                    }
                }
                editor.apply();
                appendOutput("Preferences merged from backup. Restart WinCore to refresh settings screens.");
            } else {
                if (!"wincore-game-profile-v1".equals(root.optString("format"))) throw new JSONException("Not a WinCore game profile.");
                validateProfileObject(root);
                backupCurrentProfileBeforeChange("before-import");
                applyProfile(root);
                store.edit().putString("profile_" + gameKey(), root.toString()).apply();
                appendOutput("Imported game profile: " + gameName.getText());
            }
        } catch (Exception e) { appendOutput("Import failed safely: " + e.getMessage()); }
    }

    private void captureLogs() {
        appendOutput("Collecting recent diagnostic log entries…");
        new Thread(() -> {
            StringBuilder filtered = new StringBuilder();
            try {
                java.lang.Process process = new ProcessBuilder("logcat", "-d", "-v", "time", "-t", "1200").redirectErrorStream(true).start();
                byte[] raw = readBounded(process.getInputStream(), 512 * 1024);
                process.waitFor();
                String all = new String(raw, StandardCharsets.UTF_8);
                for (String line : all.split("\\R")) {
                    String lower = line.toLowerCase(Locale.ROOT);
                    if (lower.contains("com.wincore") || lower.contains("com.winlator") || lower.contains("box64") ||
                            lower.contains("wine") || lower.contains("fatal exception") || lower.contains("androidruntime") ||
                            lower.contains("vulkan") || lower.contains("dxvk")) {
                        filtered.append(redact(line)).append("\n");
                    }
                    if (filtered.length() > 180000) break;
                }
                if (filtered.length() == 0) filtered.append("No matching lines were returned. Android may restrict logcat access for this build.");
            } catch (Exception e) {
                filtered.append("Log capture unavailable: ").append(e.getMessage());
            }
            final String result = filtered.toString();
            runOnUiThread(() -> {
                store.edit().putString("last_logs", result).apply();
                appendOutput("FILTERED LOG CAPTURE\n" + result);
            });
        }, "WinCoreLogCapture").start();
    }

    private String redact(String line) {
        return line.replaceAll("(?i)(/storage/emulated/0/)[^ ]+", "$1[redacted]")
                .replaceAll("(?i)(/data/user/0/)[^ ]+", "$1[redacted]")
                .replaceAll("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[email redacted]");
    }

    private void buildAndShowReport() {
        StringBuilder report = new StringBuilder();
        report.append("WinCore 6.0.0 Compatibility Report\n");
        report.append("Generated: ").append(new java.util.Date()).append("\n\n");
        report.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
        report.append("Android: ").append(Build.VERSION.RELEASE).append(" / API ").append(Build.VERSION.SDK_INT).append("\n");
        report.append("CPU cores: ").append(Runtime.getRuntime().availableProcessors()).append("\n");
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        ((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(memory);
        report.append("RAM: ").append(memory.availMem / (1024 * 1024)).append(" MiB available / ").append(memory.totalMem / (1024 * 1024)).append(" MiB total; low memory=").append(memory.lowMemory).append("\n");
        report.append("App PSS: ").append(Debug.getPss()).append(" KiB\n");
        report.append("Battery temperature: ").append(readBatteryTemperature()).append("\n");
        report.append("Thermal status: ").append(readThermalStatus()).append("\n");
        report.append("Vulkan: ").append(readVulkanFeature()).append("\n");
        report.append("OpenGL ES: ").append(readGlesFeature()).append("\n");
        report.append("Selected game: ").append(gameName.getText()).append("\n");
        report.append("Executable: ").append(executableUri == null ? "not selected" : displayName(executableUri)).append("\n");
        report.append("Executable analysis: ").append(executableAnalysis.toString()).append("\n");
        report.append("Recommended profile: ").append(profileType.getSelectedItem()).append("\n");
        report.append("Box64 recommendation: ").append(box64Preset.getSelectedItem()).append("\n");
        report.append("Graphics wrapper recommendation: ").append(graphicsWrapper.getSelectedItem()).append("\n");
        report.append("Manual rating: ").append(rating.getSelectedItem()).append("\n");
        report.append("Notes: ").append(notes.getText()).append("\n\n");
        report.append("Recent filtered logs:\n").append(store.getString("last_logs", "Not captured.")).append("\n");
        report.append("Limits: static PE import inspection and Android-reported telemetry only; no game launch, GPU benchmark, FPS measurement, or driver compatibility guarantee is performed.");
        String finalReport = report.toString();
        String priorReport = store.getString("last_report", null);
        SharedPreferences.Editor reportEditor = store.edit().putString("last_report", finalReport);
        if (priorReport != null) reportEditor.putString("previous_report", priorReport);
        reportEditor.apply();
        appendOutput(finalReport);
    }

    private void shareLatestReport() {
        String report = store.getString("last_report", null);
        if (report == null) {
            appendOutput("Build a compatibility report first.");
            return;
        }
        Intent share = new Intent(Intent.ACTION_SEND);
        share.setType("text/plain");
        share.putExtra(Intent.EXTRA_SUBJECT, "WinCore compatibility report");
        share.putExtra(Intent.EXTRA_TEXT, report);
        try { startActivity(Intent.createChooser(share, "Share WinCore report")); }
        catch (ActivityNotFoundException e) { appendOutput("No compatible sharing app is available."); }
    }

    private void showSessionHistory() {
        appendOutput("SESSION HISTORY\n" + WinCoreSessionTracker.readHistory(this));
    }

    private void showTroubleshooting() {
        appendOutput("TROUBLESHOOTING\n" +
                "1. Confirm the executable and game data are complete.\n" +
                "2. Keep a backup of the original container before changing Wine, Box64, DXVK, WineD3D, or VKD3D.\n" +
                "3. Match the wrapper to the detected Direct3D version; import inspection is a clue, not proof of the API used at runtime.\n" +
                "4. If the game reports a missing DLL, compare its imports with the game directory and the container's Windows system folders.\n" +
                "5. Check Vulkan support and logs before selecting a Vulkan-backed wrapper.\n" +
                "6. Low memory or severe thermal status can destabilize long sessions. Close unused apps and allow the device to cool.\n" +
                "7. For GTA IV, begin with a conservative DX9 configuration in a duplicate container, then change one setting at a time.\n" +
                "8. Do not delete prefixes, registry files, or save data as a first troubleshooting step.\n" +
                "9. Restore the previous saved profile when a recommendation makes the result worse.\n" +
                "10. Remove private paths, usernames, and personal data before sharing logs.");
    }


    private void detectGameExecutables() {
        if (gameFolderUri == null) {
            appendOutput("Select a game folder first. The scan is bounded to 3 levels and 3,000 entries.");
            return;
        }
        try {
            Set<String> files = scanTree(gameFolderUri);
            ArrayList<String> executables = new ArrayList<>();
            for (String file : files) if (file.endsWith(".exe")) executables.add(file);
            Collections.sort(executables);
            StringBuilder out = new StringBuilder("AUTOMATIC GAME DETECTION\n");
            out.append("Executable candidates: ").append(executables.size()).append("\n");
            for (int i = 0; i < executables.size() && i < 60; i++) out.append(" • ").append(executables.get(i)).append("\n");
            if (executables.isEmpty()) out.append("No executable names found in the scanned folder depth.\n");
            out.append("Detection is based on filenames, not executable trust or launch success.");
            appendOutput(out.toString());
        } catch (Exception e) { appendOutput("Game detection failed: " + e.getMessage()); }
    }

    private void showCompatibilityDatabase() {
        StringBuilder out = new StringBuilder("LOCAL COMPATIBILITY DATABASE\n");
        int count = 0;
        for (String key : store.getAll().keySet()) {
            if (!key.startsWith("profile_")) continue;
            try {
                JSONObject profile = new JSONObject(store.getString(key, "{}"));
                out.append("• ").append(profile.optString("gameName", key.substring(8)))
                        .append(" — ").append(profile.optString("rating", "Not rated"))
                        .append(" — ").append(new java.util.Date(profile.optLong("updatedAt"))).append("\n");
                count++;
            } catch (Exception ignored) { out.append("• ").append(key).append(" (unreadable)\n"); }
        }
        out.append("Records: ").append(count).append(". Stored locally; this is not an online or crowd-verified database.");
        appendOutput(out.toString());
    }

    private void matchCompatibilityProfile() {
        String name = gameName.getText().toString().toLowerCase(Locale.ROOT);
        String dx = executableAnalysis.optString("directX", "");
        String suggestion;
        if (name.contains("gta iv") || name.contains("gta4") || name.contains("gtaiv")) {
            select(profileType, "GTA IV (DirectX 9) diagnostic profile");
            suggestion = "GTA IV / Direct3D 9 diagnostic profile";
        } else if (dx.contains("12")) {
            select(graphicsWrapper, "VKD3D");
            suggestion = "Inspect VKD3D support and Vulkan capability";
        } else if (dx.contains("9") || dx.contains("10") || dx.contains("11")) {
            suggestion = "Compare DXVK and WineD3D in a duplicate container";
        } else {
            suggestion = "Automatic / inspect first";
        }
        appendOutput("AUTOMATIC PROFILE MATCH\nSuggestion: " + suggestion +
                "\nBasis: game name and static executable indicators. This does not test game launch success.");
    }

    private void wineVersionAdvisor() {
        appendOutput("WINE VERSION ADVISOR\nUse a Wine build already present in the selected Winlator container. Record the current version, duplicate the container before testing another installed version, and compare logs. WinCore does not download, install, or silently replace Wine builds.");
    }

    private void box64PresetAdvisor() {
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        ((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(memory);
        int cores = Runtime.getRuntime().availableProcessors();
        String preset = memory.lowMemory || memory.availMem < 1024L * 1024L * 1024L ?
                "Stability / Conservative" : (cores >= 8 ? "Intermediate as a starting point" : "Stability / Conservative as a starting point");
        appendOutput("BOX64 PRESET ADVISOR\nSuggested starting point: " + preset +
                "\nInputs: " + cores + " logical CPUs exposed; " + (memory.availMem / (1024 * 1024)) +
                " MiB available RAM. This heuristic is not benchmark-verified and does not change the selected container.");
    }

    private void checkGraphicsWrapper() {
        String dx = executableAnalysis.optString("directX", "not analyzed");
        String vulkan = readVulkanFeature();
        String advice = dx.contains("12") ? "Review VKD3D and Vulkan availability." :
                (dx.contains("9") || dx.contains("10") || dx.contains("11") || dx.contains("8") ?
                        "Compare DXVK and WineD3D in a duplicate container." :
                        "Keep Automatic until the game's actual graphics API is known.");
        appendOutput("GRAPHICS WRAPPER CHECK\nSelected advisory: " + graphicsWrapper.getSelectedItem() +
                "\nDetected clue: " + dx + "\nVulkan: " + vulkan + "\n" + advice +
                "\nNo wrapper was switched or runtime-tested.");
    }

    private void showLaunchArguments() {
        appendOutput("LAUNCH ARGUMENT MANAGER\nCurrent per-game launch arguments:\n" +
                launchArguments.getText().toString() +
                "\nSave the profile to keep these arguments as WinCore notes. They are not automatically injected into existing Winlator shortcuts.");
    }

    private ActivityManager.MemoryInfo memoryInfoV5() {
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        ((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(memory);
        return memory;
    }

    private void showMemoryPressure() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        appendOutput("RAM PRESSURE MONITOR\nAvailable: " + (memory.availMem / (1024 * 1024)) +
                " MiB / " + (memory.totalMem / (1024 * 1024)) +
                " MiB\nAndroid low-memory flag: " + memory.lowMemory +
                "\nThis reports Android system memory, not memory available to a particular Windows game.");
    }

    private void warnLowMemory() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        long available = memory.availMem / (1024 * 1024);
        boolean warning = memory.lowMemory || available < 1024;
        appendOutput("LOW-MEMORY WARNING\nAvailable system RAM: " + available + " MiB\n" +
                (warning ? "Memory pressure is elevated. Close unused apps and avoid starting a demanding game until memory improves." :
                        "Android is not currently reporting low memory."));
    }

    private void cpuSnapshot() {
        long now = SystemClock.elapsedRealtime();
        long cpu = Process.getElapsedCpuTime();
        long elapsed = Math.max(1L, now - v5CpuSampleTime);
        long cpuDelta = Math.max(0L, cpu - v5CpuSampleValue);
        double percent = Math.min(100.0, cpuDelta * 100.0 / elapsed);
        v5CpuSampleTime = now;
        v5CpuSampleValue = cpu;
        appendOutput(String.format(Locale.ROOT,
                "CPU LOAD SNAPSHOT\nWinCore app-process CPU time over the previous sample window: %.1f%% of one logical CPU.\nThis is not whole-device CPU usage or isolated game-process utilization.",
                percent));
    }

    private void batteryPerformanceAdvisor() {
        String temperature = readBatteryTemperature();
        int level = -1;
        try {
            Intent battery = registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (battery != null) level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        } catch (Exception ignored) { }
        appendOutput("BATTERY PERFORMANCE ADVICE\nBattery level: " + level + "%\nBattery temperature: " +
                temperature + "\nProfile: " + profileType.getSelectedItem() +
                "\nThese are recommendations only. WinCore does not lock CPU clocks or override Android power management.");
    }

    private void backgroundProcessWarning() {
        ActivityManager manager = (ActivityManager)getSystemService(ACTIVITY_SERVICE);
        int visible = 0;
        try {
            java.util.List<ActivityManager.RunningAppProcessInfo> processes = manager.getRunningAppProcesses();
            if (processes != null) for (ActivityManager.RunningAppProcessInfo process : processes) {
                if (process != null && process.pid != Process.myPid()) visible++;
            }
        } catch (Exception ignored) { }
        appendOutput("BACKGROUND PROCESS AWARENESS\nOther visible processes: " + visible +
                "\nAndroid may restrict this list. A zero count does not prove there are no background applications.");
    }

    private void resolutionAdvisor() {
        android.util.DisplayMetrics metrics = getResources().getDisplayMetrics();
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        String advice = memory.lowMemory || memory.availMem < 1536L * 1024L * 1024L ?
                "Start conservatively around 960x540 or 1280x720." :
                "Try 1280x720 first; increase only after testing.";
        appendOutput("RESOLUTION ADVISOR\nAndroid display: " + metrics.widthPixels + "x" + metrics.heightPixels +
                "\nSuggested starting point: " + advice +
                "\nThis does not change the game's resolution setting.");
    }

    private void framePacingStatus() {
        appendOutput("FRAME-PACING DIAGNOSTICS\nReliable per-game frame-time data is not exposed by the current WinCore integration. No FPS or frame-pacing score is fabricated. Use an external benchmark only when it can measure the actual game process.");
    }

    private void createGtaIvProfile() {
        String currentName = gameName.getText().toString();
        gameName.setText("GTA IV");
        select(profileType, "GTA IV (DirectX 9) diagnostic profile");
        select(graphicsWrapper, "DXVK");
        select(box64Preset, "Stability");
        saveProfile();
        if (!currentName.toLowerCase(Locale.ROOT).contains("gta")) gameName.setText(currentName);
        appendOutput("Created a GTA IV diagnostic profile. The selections are saved recommendations; they are not applied to the active container.");
    }

    private void checkGtaComponents() {
        if (gameFolderUri == null) { appendOutput("Select the GTA IV game folder first."); return; }
        try {
            Set<String> files = scanTree(gameFolderUri);
            String[] names = {"gtaiv.exe", "playgtaiv.exe", "xlive.dll", "d3d9.dll", "dsound.dll", "xinput1_3.dll", "common.rpf"};
            StringBuilder out = new StringBuilder("GTA IV COMPONENT PRESENCE CHECK\n");
            for (String name : names) out.append(name).append(": ").append(files.contains(name) ? "present" : "not found in scanned depth").append("\n");
            out.append("Presence does not prove version correctness or successful loading.");
            appendOutput(out.toString());
        } catch (Exception e) { appendOutput("Component check failed: " + e.getMessage()); }
    }

    private void checkControllerDevices() {
        int[] ids = InputDevice.getDeviceIds();
        StringBuilder out = new StringBuilder("CONTROLLER DEVICE CHECK\n");
        int found = 0;
        for (int id : ids) {
            InputDevice device = InputDevice.getDevice(id);
            if (device == null) continue;
            int sources = device.getSources();
            boolean controller = (sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
                    (sources & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK;
            out.append(device.getName()).append(": ").append(controller ? "gamepad/joystick input source" : "input device").append("\n");
            found++;
        }
        out.append("Visible devices: ").append(found).append(". Detection does not validate game-specific button mapping.");
        appendOutput(out.toString());
    }

    private void checkAudioOutput() {
        StringBuilder out = new StringBuilder("ANDROID AUDIO OUTPUT CHECK\n");
        try {
            AudioManager manager = (AudioManager)getSystemService(AUDIO_SERVICE);
            AudioDeviceInfo[] devices = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
            for (AudioDeviceInfo device : devices) out.append(device.getProductName()).append(" (type ").append(device.getType()).append(")\n");
            if (devices.length == 0) out.append("Android reports no output device at this moment.");
        } catch (Exception e) { out.append("Output device list unavailable: ").append(e.getMessage()); }
        out.append("\nThis does not test Wine or in-game audio playback.");
        appendOutput(out.toString());
    }

    private void checkGtaSaveData() {
        if (gameFolderUri == null) { appendOutput("Select the game folder first."); return; }
        try {
            Set<String> files = scanTree(gameFolderUri);
            StringBuilder out = new StringBuilder("GTA IV SAVE-DATA CLUES\n");
            boolean found = false;
            for (String file : files) if (file.contains("settings.dat") || file.contains("save") || file.contains("sgta")) {
                out.append(" • ").append(file).append("\n"); found = true;
            }
            if (!found) out.append("No obvious save/config filename was found in the scanned depth. Save data may be stored elsewhere.");
            appendOutput(out.toString());
        } catch (Exception e) { appendOutput("Save-data clue scan failed: " + e.getMessage()); }
    }

    private void showFilteredLogs(String category) {
        String logs = store.getString("last_logs", "");
        if (logs.isEmpty()) { appendOutput("Capture diagnostic logs first, then reopen this filter."); return; }
        StringBuilder out = new StringBuilder(category.toUpperCase(Locale.ROOT)).append(" LOG VIEWER\n");
        int count = 0;
        for (String line : logs.split("\\R")) {
            String lower = line.toLowerCase(Locale.ROOT);
            boolean match = "wine".equals(category) ? lower.contains("wine") || lower.contains("wined3d") :
                    lower.contains("box64") || lower.contains("box86");
            if (match) { out.append(line).append("\n"); if (++count >= 100) break; }
        }
        if (count == 0) out.append("No matching lines in the latest captured logs.");
        appendOutput(out.toString());
    }

    private void detectMissingDlls() {
        String logs = store.getString("last_logs", "");
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile(
                "(?i)(?:library|dll)\\s+['\\\"]?([a-z0-9_.-]+\\.dll)['\\\"]?\\s+(?:not found|missing)").matcher(logs);
        java.util.HashSet<String> names = new java.util.HashSet<>();
        while (matcher.find()) names.add(matcher.group(1));
        StringBuilder out = new StringBuilder("MISSING DLL LOG DETECTOR\n");
        if (names.isEmpty()) out.append("No matching missing-DLL pattern was found. Capture logs after reproducing the launch failure.");
        else for (String name : names) out.append(" • ").append(name).append("\n");
        out.append("Avoid downloading DLLs from untrusted sources; verify legitimate component source and architecture.");
        appendOutput(out.toString());
    }

    private void diagnoseGraphicsInitialization() {
        String logs = store.getString("last_logs", "");
        StringBuilder out = new StringBuilder("GRAPHICS INITIALIZATION DIAGNOSTICS\n");
        int count = 0;
        for (String line : logs.split("\\R")) {
            String lower = line.toLowerCase(Locale.ROOT);
            if (lower.contains("vulkan") || lower.contains("dxvk") || lower.contains("vkd3d") ||
                    lower.contains("wined3d") || lower.contains("renderer") || lower.contains("d3d")) {
                out.append(line).append("\n");
                if (++count >= 60) break;
            }
        }
        if (count == 0) out.append("No graphics initialization lines found in the latest log snapshot. Capture logs after an attempted launch.");
        appendOutput(out.toString());
    }

    private void showVulkanCapabilities() {
        appendOutput("VULKAN CAPABILITY CHECK\n" + readVulkanFeature() +
                "\nAndroid feature metadata does not prove that a selected driver or game render path works.");
    }

    private void showFolderHealthReport() {
        if (gameFolderUri == null) { appendOutput("Select a game folder first."); return; }
        try {
            Set<String> files = scanTree(gameFolderUri);
            int exe = 0, dll = 0;
            for (String name : files) { if (name.endsWith(".exe")) exe++; if (name.endsWith(".dll")) dll++; }
            appendOutput("SELECTED GAME-FOLDER HEALTH REPORT\nEntries scanned: " + files.size() +
                    "\nEXE filenames: " + exe + "\nDLL filenames: " + dll +
                    "\nThis checks folder names and traversal only; it does not hash or validate game contents.");
        } catch (Exception e) { appendOutput("Folder health report failed: " + e.getMessage()); }
    }

    private void showLocalProfileLibrary() {
        showCompatibilityDatabase();
        appendOutput("Shared profiles are exchanged through the existing JSON import/export controls. No remote community server is connected.");
    }

    private void showProfileVersionHistory() {
        JSONArray history = historyFor(gameKey());
        StringBuilder out = new StringBuilder("PROFILE VERSION HISTORY\n");
        for (int i = history.length() - 1; i >= 0; i--) {
            try {
                JSONObject item = new JSONObject(history.getString(i));
                out.append(" • ").append(new java.util.Date(item.optLong("updatedAt")))
                        .append(" — ").append(item.optString("rating", "Not rated")).append("\n");
            } catch (Exception ignored) { }
        }
        if (history.length() == 0) out.append("No previous snapshots. Save a profile more than once to create history.");
        appendOutput(out.toString());
    }

    private void showContainerBackupChecklist() {
        appendOutput("CONTAINER BACKUP CHECKLIST\n1. Stop the active Windows session.\n2. Copy the complete container and Wine prefix using a file manager to safe storage.\n3. Back up game saves stored outside that folder.\n4. Keep the original copy until a restore has been verified.\n5. WinCore's JSON backup covers preferences/profile data only; it does NOT archive RootFS, Wine prefixes, container directories, or game files.");
    }

    private void showContainerMigrationAssistant() {
        appendOutput("CONTAINER MIGRATION ASSISTANT\nExport WinCore profiles and preferences, copy the complete container folder separately with a file manager, then import the JSON on the destination device. Confirm Wine, Box64, and graphics components on the destination before launching. WinCore does not copy container filesystem data itself.");
    }

    private void evaluateCustomRules() {
        String logs = store.getString("last_logs", "");
        StringBuilder out = new StringBuilder("CUSTOM COMPATIBILITY RULES\n");
        String[] rules = customRules.getText().toString().split("\\R");
        int count = 0;
        for (String rule : rules) {
            String phrase = rule.trim();
            if (phrase.isEmpty()) continue;
            out.append(phrase).append(": ").append(logs.toLowerCase(Locale.ROOT).contains(phrase.toLowerCase(Locale.ROOT)) ?
                    "matched latest captured logs" : "not matched in latest captured logs").append("\n");
            count++;
        }
        if (count == 0) out.append("Enter one plain-text phrase per line in the Custom compatibility rules field.");
        appendOutput(out.toString());
    }

    private void showDashboardSummaryLegacy() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        StringBuilder out = new StringBuilder("WINCORE 5.0.0 COMPATIBILITY DASHBOARD\n");
        out.append("Saved game profile: ").append(store.contains("profile_" + gameKey())).append("\n");
        out.append("Selected game: ").append(gameName.getText()).append("\n");
        out.append("Executable: ").append(executableUri == null ? "not selected" : displayName(executableUri)).append("\n");
        out.append("Available RAM: ").append(memory.availMem / (1024 * 1024)).append(" MiB\n");
        out.append("Low-memory flag: ").append(memory.lowMemory).append("\n");
        out.append("Battery temperature: ").append(readBatteryTemperature()).append("\n");
        out.append("Thermal status: ").append(readThermalStatus()).append("\n");
        out.append("Vulkan: ").append(readVulkanFeature()).append("\n");
        out.append("Session history:\n").append(WinCoreSessionTracker.readHistory(this));
        out.append("\nNo game runtime compatibility is inferred by this summary.");
        appendOutput(out.toString());
    }


    private void createOrRefreshAutomaticProfile() {
        String key = gameKey();
        String saved = store.getString("profile_" + key, null);
        if (saved != null) {
            loadProfile();
            appendOutput("Loaded the saved per-game profile for " + gameName.getText() + ".");
            return;
        }
        matchCompatibilityProfile();
        saveProfile();
        appendOutput("Created an initial advisory profile. Review it before using equivalent settings in Winlator.");
    }

    private void detectGameVersionMetadata() {
        if (executableUri == null) { appendOutput("Select a game executable first."); return; }
        Cursor cursor = null;
        try {
            cursor = getContentResolver().query(executableUri,
                    new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED},
                    null, null, null);
            if (cursor == null || !cursor.moveToFirst()) { appendOutput("The document provider did not expose file metadata."); return; }
            String name = cursor.getString(0);
            long size = cursor.isNull(1) ? -1L : cursor.getLong(1);
            int modifiedIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED);
            long modified = modifiedIndex >= 0 && !cursor.isNull(modifiedIndex) ? cursor.getLong(modifiedIndex) : -1L;
            appendOutput("GAME FILE METADATA\nName: " + name + "\nSize: " +
                    (size < 0 ? "not provided" : size + " bytes") + "\nLast modified: " +
                    (modified < 0 ? "not provided" : new java.util.Date(modified)) +
                    "\nThis does not extract the embedded Windows product version from PE resources.");
        } catch (Exception e) { appendOutput("File metadata unavailable: " + e.getMessage()); }
        finally { if (cursor != null) cursor.close(); }
    }

    private void showPerGamePresets() {
        appendOutput("PER-GAME SETTINGS PRESETS\nGame: " + gameName.getText() +
                "\nCompatibility: " + profileType.getSelectedItem() +
                "\nBox64: " + box64Preset.getSelectedItem() +
                "\nWrapper: " + graphicsWrapper.getSelectedItem() +
                "\nRenderer: " + rendererProfile.getSelectedItem() +
                "\nResolution: " + resolutionProfile.getSelectedItem() +
                "\nUse Save game profile to store this named preset. These values remain advisory and are not silently applied to the active container.");
    }

    private void showEnvironmentVariables() {
        String values = environmentVariables.getText().toString();
        int validCount = 0, invalidCount = 0;
        for (String line : values.split("\\R")) {
            String item = line.trim();
            if (item.isEmpty()) continue;
            int equals = item.indexOf('=');
            if (equals > 0 && item.substring(0, equals).matches("[A-Za-z_][A-Za-z0-9_]*")) validCount++;
            else invalidCount++;
        }
        appendOutput("GAME-SPECIFIC ENVIRONMENT VARIABLES\n" + values +
                "\nValid KEY=VALUE lines: " + validCount + "\nInvalid lines: " + invalidCount +
                "\nThese are saved in the WinCore profile; they are not injected into existing Winlator shortcuts.");
    }

    private void runGraphicsCompatibilityScan() {
        String imports = executableAnalysis.optJSONArray("imports") == null ? "not analyzed" : executableAnalysis.optJSONArray("imports").toString();
        appendOutput("GRAPHICS COMPATIBILITY SCAN\nDirectX clue: " + executableAnalysis.optString("directX", "not analyzed") +
                "\nVulkan: " + readVulkanFeature() + "\nOpenGL ES: " + readGlesFeature() +
                "\nRenderer profile: " + rendererProfile.getSelectedItem() +
                "\nWrapper: " + graphicsWrapper.getSelectedItem() +
                "\nImported library clues: " + imports +
                "\nStatic imports and Android feature metadata are not proof of runtime rendering compatibility.");
    }

    private void showOpenGlCapabilities() {
        appendOutput("OPENGL CAPABILITY DETAILS\nAndroid PackageManager requirement: " + readGlesFeature() +
                "\nDevice: " + Build.MANUFACTURER + " " + Build.MODEL +
                "\nThe reported GLES feature is a platform requirement/capability indicator, not a live query of the renderer selected inside Winlator.");
    }

    private void showDxvkManager() {
        appendWrapperVariables("DXVK", "DXVK_");
    }

    private void showVkd3dManager() {
        appendWrapperVariables("VKD3D", "VKD3D_");
    }

    private void appendWrapperVariables(String title, String prefix) {
        StringBuilder out = new StringBuilder(title + " CONFIGURATION MANAGER\n");
        int found = 0;
        for (String line : environmentVariables.getText().toString().split("\\R")) {
            if (line.trim().toUpperCase(Locale.ROOT).startsWith(prefix)) { out.append(line.trim()).append("\n"); found++; }
        }
        if (found == 0) out.append("No ").append(prefix).append(" variables are configured in this profile.\n");
        out.append("Edit the environment-variable field and save the profile to keep changes as notes. WinCore does not write these values into the live container.");
        appendOutput(out.toString());
    }

    private void showRendererProfiles() {
        appendOutput("RENDERER PROFILE\nSelected advisory: " + rendererProfile.getSelectedItem() +
                "\nAndroid Vulkan: " + readVulkanFeature() + "\nAndroid GLES: " + readGlesFeature() +
                "\nRenderer selection is stored in this WinCore profile only; change the actual renderer through the existing Winlator container controls.");
    }

    private void showResolutionProfiles() {
        appendOutput("RESOLUTION PROFILE\nSelected advisory: " + resolutionProfile.getSelectedItem() +
                "\nAndroid display: " + getResources().getDisplayMetrics().widthPixels + "x" +
                getResources().getDisplayMetrics().heightPixels +
                "\nChoose the corresponding resolution in the Winlator container/game settings. This profile field does not change the runtime resolution.");
    }

    private void checkFullscreenSettings() {
        String env = environmentVariables.getText().toString().toLowerCase(Locale.ROOT);
        String notesText = notes.getText().toString().toLowerCase(Locale.ROOT);
        appendOutput("FULLSCREEN CONFIGURATION CHECK\nFullscreen-related environment entries: " +
                (env.contains("fullscreen") || env.contains("virtual_desktop") ? "found" : "none found") +
                "\nNotes mention borderless/windowed: " + (notesText.contains("borderless") || notesText.contains("windowed")) +
                "\nWinCore cannot inspect the game's live display mode from this screen.");
    }

    private int sampleCount(String key) {
        try { return new JSONArray(store.getString(key, "[]")).length(); }
        catch (Exception e) { return 0; }
    }

    private void appendSample(String key, JSONObject value) {
        JSONArray history;
        try { history = new JSONArray(store.getString(key, "[]")); }
        catch (Exception e) { history = new JSONArray(); }
        history.put(value);
        while (history.length() > 30) history.remove(0);
        store.edit().putString(key, history.toString()).apply();
    }

    private void recordMemorySample() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        JSONObject sample = new JSONObject();
        try {
            sample.put("time", System.currentTimeMillis());
            sample.put("availableMiB", memory.availMem / (1024 * 1024));
            sample.put("totalMiB", memory.totalMem / (1024 * 1024));
            sample.put("lowMemory", memory.lowMemory);
            sample.put("appPssKiB", Debug.getPss());
        } catch (JSONException ignored) { }
        appendSample("memory_samples", sample);
        appendOutput("MEMORY PRESSURE SAMPLE\nAvailable RAM: " + memory.availMem / (1024 * 1024) +
                " MiB\nApp PSS: " + Debug.getPss() + " KiB\nSamples saved: " +
                sampleCount("memory_samples") +
                "\nThese are Android system/app measurements, not per-game memory telemetry.");
    }

    private void recordThermalSample() {
        JSONObject sample = new JSONObject();
        String status = readThermalStatus();
        String temperature = readBatteryTemperature();
        try {
            sample.put("time", System.currentTimeMillis());
            sample.put("thermalStatus", status);
            sample.put("batteryTemperature", temperature);
        } catch (JSONException ignored) { }
        appendSample("thermal_samples", sample);
        appendOutput("THERMAL HISTORY SAMPLE\nThermal status: " + status +
                "\nBattery temperature: " + temperature +
                "\nSamples saved: " + sampleCount("thermal_samples"));
    }

    private int currentBatteryLevel() {
        try {
            Intent battery = registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            return battery == null ? -1 : battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        } catch (Exception e) { return -1; }
    }

    private void showBatteryImpactReport() {
        int level = currentBatteryLevel();
        String temperature = readBatteryTemperature();
        if (!store.contains("battery_baseline_level")) {
            store.edit().putInt("battery_baseline_level", level)
                    .putString("battery_baseline_temperature", temperature)
                    .putLong("battery_baseline_time", System.currentTimeMillis()).apply();
            appendOutput("BATTERY IMPACT BASELINE SAVED\nBattery: " + level + "%\nTemperature: " + temperature +
                    "\nUse this action again after a session to compare. Android battery percentage is coarse and is not a direct power meter.");
            return;
        }
        int baseline = store.getInt("battery_baseline_level", -1);
        appendOutput("BATTERY IMPACT REPORT\nBaseline: " + baseline + "%\nCurrent: " + level +
                "%\nChange: " + (baseline < 0 || level < 0 ? "unavailable" : (level - baseline) + " percentage points") +
                "\nBaseline temperature: " + store.getString("battery_baseline_temperature", "unknown") +
                "\nCurrent temperature: " + temperature);
    }

    private void estimateLaunchResources() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        android.os.StatFs storage = new android.os.StatFs(getFilesDir().getAbsolutePath());
        long freeBytes = storage.getAvailableBytes();
        boolean low = memory.lowMemory || memory.availMem < 1024L * 1024L * 1024L || freeBytes < 1024L * 1024L * 1024L;
        appendOutput("LAUNCH RESOURCE ESTIMATE\nAvailable RAM: " + memory.availMem / (1024 * 1024) + " MiB\n" +
                "Available app-storage volume: " + freeBytes / (1024 * 1024) + " MiB\n" +
                "Assessment: " + (low ? "resource pressure detected; postpone a demanding launch or free resources" : "no immediate low-RAM/low-storage flag detected") +
                "\nThis is a coarse readiness estimate, not a prediction that the selected game will launch.");
    }

    private void compareCpuProfiles() {
        int cores = Runtime.getRuntime().availableProcessors();
        String choice = box64Preset.getSelectedItem().toString();
        appendOutput("CPU PROFILE COMPARISON\nCurrent saved recommendation: " + choice +
                "\nStability: conservative baseline; may reduce peak throughput.\n" +
                "Intermediate: balanced starting point; still needs game-specific testing.\n" +
                "Performance: may increase resource demand or instability; not automatically faster.\n" +
                "Logical CPUs exposed to Android: " + cores +
                "\nNo benchmark has been run and no Box64 profile is changed by this comparison.");
    }

    private void showStabilityTracker() {
        String logs = store.getString("last_logs", "").toLowerCase(Locale.ROOT);
        int fatal = countOccurrences(logs, "fatal exception");
        int segv = countOccurrences(logs, "sigsegv") + countOccurrences(logs, "signal 11");
        int aborts = countOccurrences(logs, "abort message") + countOccurrences(logs, "process aborted");
        appendOutput("SESSION STABILITY TRACKER\nCompleted XServer sessions:\n" +
                WinCoreSessionTracker.readHistory(this) +
                "\nCrash indicators in latest captured log: fatal exceptions=" + fatal +
                ", segmentation-fault clues=" + segv + ", abort clues=" + aborts +
                "\nLog indicators are not a complete crash counter.");
    }

    private int countOccurrences(String haystack, String needle) {
        if (haystack == null || needle == null || needle.isEmpty()) return 0;
        int count = 0, at = 0;
        while ((at = haystack.indexOf(needle, at)) >= 0) { count++; at += needle.length(); }
        return count;
    }

    private void showStartupTimeHistory() {
        appendOutput("STARTUP TIME HISTORY\nLast Compatibility Center UI initialization: " +
                store.getLong("last_center_startup_ms", -1L) + " ms\n" +
                "This records this Android screen's initialization only. The current Winlator integration does not expose reliable per-game process startup timing.");
    }

    private void checkLowStorage() {
        android.os.StatFs storage = new android.os.StatFs(getFilesDir().getAbsolutePath());
        long free = storage.getAvailableBytes();
        appendOutput("LOW-STORAGE CHECK\nAvailable bytes on app storage volume: " + free +
                "\nAvailable MiB: " + free / (1024 * 1024) +
                "\n" + (free < 1024L * 1024L * 1024L ? "Warning: less than 1 GiB is available on this volume." : "No low-storage threshold warning for this volume.") +
                "\nThis does not measure free space in every external game/container folder.");
    }

    private void exportSessionPerformanceReport() {
        pendingExport = "WINCORE SESSION PERFORMANCE REPORT\nGenerated: " + new java.util.Date() +
                "\n\n" + WinCoreSessionTracker.readHistory(this) +
                "\nLatest RAM samples:\n" + store.getString("memory_samples", "[]") +
                "\nThermal samples:\n" + store.getString("thermal_samples", "[]");
        pendingExportName = "wincore-session-performance.txt";
        createExportIntent("text/plain", pendingExportName, EXPORT_REPORT);
    }

    private void showCrashTimeline() {
        String logs = store.getString("last_logs", "");
        StringBuilder out = new StringBuilder("CRASH REPORT TIMELINE (latest captured log)\n");
        int matched = 0;
        for (String line : logs.split("\\R")) {
            String lower = line.toLowerCase(Locale.ROOT);
            if (lower.contains("fatal exception") || lower.contains("sigsegv") ||
                    lower.contains("signal 11") || lower.contains("abort message") ||
                    lower.contains("process died") || lower.contains("crash")) {
                out.append(line).append("\n");
                if (++matched >= 100) break;
            }
        }
        if (matched == 0) out.append("No obvious crash markers found in the latest captured log.");
        appendOutput(out.toString());
    }

    private void exportDiagnosticBundle() {
        JSONObject bundle = new JSONObject();
        try {
            bundle.put("format", "wincore-diagnostic-bundle-v1");
            bundle.put("createdAt", System.currentTimeMillis());
            bundle.put("device", Build.MANUFACTURER + " " + Build.MODEL);
            bundle.put("android", Build.VERSION.RELEASE + " / API " + Build.VERSION.SDK_INT);
            bundle.put("gameProfile", readFormProfile());
            bundle.put("lastReport", store.getString("last_report", ""));
            bundle.put("capturedLogs", store.getString("last_logs", ""));
            bundle.put("sessionHistory", WinCoreSessionTracker.readHistory(this));
            bundle.put("memorySamples", store.getString("memory_samples", "[]"));
            bundle.put("thermalSamples", store.getString("thermal_samples", "[]"));
        } catch (JSONException ignored) { }
        pendingExport = bundle.toString();
        pendingExportName = gameKey() + "-wincore-diagnostic-bundle.json";
        createExportIntent("application/json", pendingExportName, EXPORT_REPORT);
    }

    private void categorizeWineErrors() {
        String logs = store.getString("last_logs", "").toLowerCase(Locale.ROOT);
        appendOutput("WINE ERROR CATEGORIES\nImport/library errors: " + countOccurrences(logs, "import_dll") +
                "\nHeap/exception errors: " + (countOccurrences(logs, "seh") + countOccurrences(logs, "exception")) +
                "\nService/process errors: " + (countOccurrences(logs, "service") + countOccurrences(logs, "process")) +
                "\nGraphics-related Wine errors: " + (countOccurrences(logs, "wined3d") + countOccurrences(logs, "d3d")) +
                "\nThese are keyword counts from the latest captured log, not a diagnosis by themselves.");
    }

    private void categorizeBox64Errors() {
        String logs = store.getString("last_logs", "").toLowerCase(Locale.ROOT);
        appendOutput("BOX64 ERROR CATEGORIES\nDynarec clues: " + countOccurrences(logs, "dynarec") +
                "\nUnsupported instruction clues: " + countOccurrences(logs, "unsupported") +
                "\nMemory/segmentation clues: " + (countOccurrences(logs, "sigsegv") + countOccurrences(logs, "segmentation")) +
                "\nELF/library clues: " + (countOccurrences(logs, "wrong elf") + countOccurrences(logs, "cannot open shared object")) +
                "\nThese counts only reflect the latest captured log.");
    }

    private void suggestMissingComponents() {
        String logs = store.getString("last_logs", "").toLowerCase(Locale.ROOT);
        StringBuilder out = new StringBuilder("MISSING COMPONENT SUGGESTIONS\n");
        if (logs.contains("err:module:import_dll") || logs.contains("dll not found")) {
            out.append("• Check the exact missing DLL name, architecture, and whether it belongs with the game or the selected Wine prefix.\n");
        }
        if (logs.contains("vulkan") && (logs.contains("failed") || logs.contains("not found"))) {
            out.append("• Inspect Android Vulkan availability and the container's selected graphics driver/wrapper.\n");
        }
        if (logs.contains("xinput") || logs.contains("dinput")) {
            out.append("• Inspect the game's controller API requirements and existing Wine input components.\n");
        }
        if (logs.contains("msvcp") || logs.contains("vcruntime")) {
            out.append("• Check the game's required Microsoft Visual C++ runtime version and architecture.\n");
        }
        if (out.toString().endsWith("\n")) out.append("No matching known component pattern was found. Capture logs after reproducing the issue.\n");
        out.append("Do not download individual DLL files from untrusted websites.");
        appendOutput(out.toString());
    }

    private void compareContainerIntegrity() {
        if (gameFolderUri == null) { appendOutput("Select a game folder first. This compares the selected folder only, not a private Winlator container root."); return; }
        try {
            ArrayList<String> names = new ArrayList<>(scanTree(gameFolderUri));
            Collections.sort(names);
            String fingerprint = Integer.toHexString(names.toString().hashCode());
            String key = "folder_fingerprint_" + gameKey();
            String previous = store.getString(key, null);
            store.edit().putString(key, fingerprint).apply();
            appendOutput("SELECTED FOLDER INTEGRITY COMPARISON\nCurrent filename fingerprint: " + fingerprint +
                    "\nPrevious snapshot: " + (previous == null ? "not available (baseline created)" : previous) +
                    "\nResult: " + (previous == null ? "baseline stored" : previous.equals(fingerprint) ? "scanned filenames unchanged" : "scanned filenames changed") +
                    "\nThis compares names only; it does not hash file contents or inspect container internals.");
        } catch (Exception e) { appendOutput("Folder comparison failed: " + e.getMessage()); }
    }

    private void backupCurrentProfileBeforeChange(String reason) {
        store.edit().putString("backup_" + reason + "_" + gameKey(), readFormProfile().toString()).apply();
    }

    private void preLaunchBackup() {
        backupCurrentProfileBeforeChange("prelaunch");
        appendOutput("PRE-LAUNCH CONFIGURATION BACKUP SAVED\nSaved the current WinCore profile before any proposed profile change. This does not back up the entire Winlator container, Wine prefix, or game data.");
    }

    private void enterRecoveryMode() {
        preLaunchBackup();
        select(profileType, "Stability-first recommendation");
        select(box64Preset, "Stability");
        select(graphicsWrapper, "Automatic");
        select(rendererProfile, "Automatic");
        select(resolutionProfile, "960 x 540");
        saveProfile();
        appendOutput("RECOVERY MODE PROFILE PREPARED\nA conservative diagnostic profile was saved. It does not change the active Winlator container; apply equivalent values manually and test one change at a time.");
    }

    private void compareDiagnosticReports() {
        String previous = store.getString("previous_report", null);
        String current = store.getString("last_report", null);
        if (previous == null || current == null) { appendOutput("Build at least two compatibility reports to compare them."); return; }
        Set<String> before = new HashSet<>(java.util.Arrays.asList(previous.split("\\R")));
        Set<String> after = new HashSet<>(java.util.Arrays.asList(current.split("\\R")));
        StringBuilder out = new StringBuilder("DIAGNOSTIC REPORT COMPARISON\n");
        for (String line : after) if (!before.contains(line)) out.append("+ ").append(line).append("\n");
        for (String line : before) if (!after.contains(line)) out.append("- ").append(line).append("\n");
        appendOutput(out.toString());
    }

    private void assignGameCategory() {
        String category = gameCategory.getText().toString().trim();
        if (category.isEmpty()) { appendOutput("Enter a category in the Game category field first."); return; }
        saveProfile();
        appendOutput("Game category saved: " + category + ". Use the local profile database to review saved game records.");
    }

    private void showGameNotes() {
        String value = notes.getText().toString().trim();
        appendOutput("GAME NOTES — " + gameName.getText() + "\n" + (value.isEmpty() ? "No notes entered." : value));
    }

    private void toggleFavorite() {
        String key = "favorite_" + gameKey();
        boolean favorite = !store.getBoolean(key, false);
        store.edit().putBoolean(key, favorite).apply();
        appendOutput(gameName.getText() + (favorite ? " added to" : " removed from") + " Favorites.");
    }

    private void showRecentActivity() {
        StringBuilder out = new StringBuilder("RECENT GAME ACTIVITY\n");
        try {
            JSONArray recent = new JSONArray(store.getString("recent_games", "[]"));
            for (int i = recent.length() - 1; i >= 0; i--) {
                JSONObject item = recent.getJSONObject(i);
                out.append("• ").append(item.optString("name")).append(" — ")
                        .append(new java.util.Date(item.optLong("time"))).append("\n");
            }
            if (recent.length() == 0) out.append("No saved profile activity yet.");
        } catch (Exception e) { out.append("Recent activity data is unreadable."); }
        appendOutput(out.toString());
    }

    private void recordRecentGame() {
        JSONArray recent;
        try { recent = new JSONArray(store.getString("recent_games", "[]")); }
        catch (Exception e) { recent = new JSONArray(); }
        JSONObject item = new JSONObject();
        try { item.put("name", gameName.getText().toString().trim()); item.put("time", System.currentTimeMillis()); }
        catch (JSONException ignored) { }
        recent.put(item);
        while (recent.length() > 30) recent.remove(0);
        store.edit().putString("recent_games", recent.toString()).apply();
    }

    private boolean validateProfileObject(JSONObject profile) throws JSONException {
        String name = profile.optString("gameName", "").trim();
        if (name.isEmpty() || name.length() > 120) throw new JSONException("Game name is empty or too long.");
        if (profile.optString("format", "").equals("wincore-game-profile-v1") == false) throw new JSONException("Unsupported profile format.");
        if (profile.optString("launchArguments", "").length() > 4096) throw new JSONException("Launch arguments exceed 4 KiB.");
        if (profile.optString("environmentVariables", "").length() > 8192) throw new JSONException("Environment variables exceed 8 KiB.");
        return true;
    }

    private void validateImportedProfile() {
        try {
            JSONObject profile = readFormProfile();
            validateProfileObject(profile);
            appendOutput("PROFILE IMPORT VALIDATION\nThe currently loaded profile meets required format and field-size checks. JSON files are validated again during import before they are applied.");
        } catch (Exception e) { appendOutput("Profile validation failed: " + e.getMessage()); }
    }

    private void validateExportedProfile() {
        try {
            JSONObject profile = readFormProfile();
            validateProfileObject(profile);
            String json = profile.toString();
            if (json.length() > 256 * 1024) throw new JSONException("Profile exceeds 256 KiB.");
            appendOutput("PROFILE EXPORT VALIDATION\nProfile format and required fields are valid. Serialized size: " + json.length() + " characters.");
            exportProfile();
        } catch (Exception e) { appendOutput("Profile export blocked: " + e.getMessage()); }
    }

    private void toggleDashboardLayout() {
        boolean compact = !store.getBoolean("compact_dashboard", false);
        store.edit().putBoolean("compact_dashboard", compact).apply();
        Toast.makeText(this, "Dashboard layout: " + (compact ? "Compact" : "Standard"), Toast.LENGTH_SHORT).show();
        recreate();
    }

    private void showDashboardSummary() {
        ActivityManager.MemoryInfo memory = memoryInfoV5();
        StringBuilder out = new StringBuilder("WINCORE 6.0.0 COMPATIBILITY CENTER 2.0\n");
        out.append("Saved game profile: ").append(store.contains("profile_" + gameKey())).append("\n");
        out.append("Favorite: ").append(store.getBoolean("favorite_" + gameKey(), false)).append("\n");
        out.append("Category: ").append(gameCategory.getText()).append("\n");
        out.append("Selected game: ").append(gameName.getText()).append("\n");
        out.append("Executable: ").append(executableUri == null ? "not selected" : displayName(executableUri)).append("\n");
        out.append("Available RAM: ").append(memory.availMem / (1024 * 1024)).append(" MiB\n");
        out.append("Low-memory flag: ").append(memory.lowMemory).append("\n");
        out.append("Battery temperature: ").append(readBatteryTemperature()).append("\n");
        out.append("Thermal status: ").append(readThermalStatus()).append("\n");
        out.append("Vulkan: ").append(readVulkanFeature()).append("\n");
        out.append("OpenGL ES: ").append(readGlesFeature()).append("\n");
        out.append("Renderer profile: ").append(rendererProfile.getSelectedItem()).append("\n");
        out.append("Resolution profile: ").append(resolutionProfile.getSelectedItem()).append("\n");
        out.append("Session history:\n").append(WinCoreSessionTracker.readHistory(this));
        out.append("\nDashboard layout: ").append(store.getBoolean("compact_dashboard", false) ? "Compact" : "Standard");
        out.append("\nNo game runtime compatibility is inferred by this summary.");
        appendOutput(out.toString());
    }

    private void appendOutput(String message) {
        if (output == null) return;
        output.setText(message + "\n\n" + output.getText());
    }
}
