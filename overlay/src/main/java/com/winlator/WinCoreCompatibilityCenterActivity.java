package com.winlator;

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
import android.provider.DocumentsContract;
import android.database.Cursor;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
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

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = getSharedPreferences(PREFS, MODE_PRIVATE);
        buildInterface();
        loadProfile();
        appendOutput("WinCore 4.0.0 Compatibility Center ready. Profiles are advisory and do not silently change Winlator runtime settings.");
    }

    private void buildInterface() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(16);
        page.setPadding(pad, pad, pad, pad);
        scroll.addView(page);
        setContentView(scroll);

        TextView title = text("WinCore Compatibility Center", 23, true);
        page.addView(title);
        page.addView(text("Executable analysis • GTA IV diagnostics • device checks • profiles • reports", 13, false));
        page.addView(text("Existing Winlator containers, shortcuts, graphics controls, and controller settings remain the source of runtime configuration.", 13, false));

        gameName = edit("Game name");
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

        if (requestCode == PICK_EXE) {
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
                Process process = new ProcessBuilder("logcat", "-d", "-v", "time", "-t", "1200").redirectErrorStream(true).start();
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
        report.append("WinCore 4.0.0 Compatibility Report\n");
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
        store.edit().putString("last_report", finalReport).apply();
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

    private void appendOutput(String message) {
        if (output == null) return;
        output.setText(message + "\n\n" + output.getText());
    }
}
