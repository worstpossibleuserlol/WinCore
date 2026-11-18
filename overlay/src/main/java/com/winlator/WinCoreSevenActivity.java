package com.winlator;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.AtomicFile;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import com.winlator.box64.Box64Preset;
import com.winlator.container.Shortcut;
import com.winlator.xenvironment.RootFS;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * WinCore 7.0.0 management workspace.
 *
 * The workspace keeps container operations out of the compatibility checklist.
 * File operations run on a single background executor, config writes use AtomicFile,
 * and restore validates the archive before it can replace an existing container.
 */
public final class WinCoreSevenActivity extends Activity {
    private static final int REQUEST_BACKUP = 701;
    private static final int REQUEST_RESTORE = 702;
    private static final int REQUEST_ARTWORK = 703;
    private static final int REQUEST_LOG_EXPORT = 704;
    private static final long MAX_RESTORE_BYTES = 8L * 1024L * 1024L * 1024L;
    private static final int MAX_RESTORE_ENTRIES = 50000;
    private static final String PREFS = "wincore_7_workspace";

    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ArrayList<ContainerRecord> containers = new ArrayList<>();
    private final ArrayList<Button> featureButtons = new ArrayList<>();
    private final ArrayList<LinearLayout> featureGroups = new ArrayList<>();
    private final ArrayList<String> scanErrors = new ArrayList<>();
    private SharedPreferences preferences;
    private RootFS rootFS;
    private File homeDir;
    private FrameLayout page;
    private LinearLayout column;
    private LinearLayout featureRoot;
    private TextView status;
    private TextView selectedLabel;
    private ProgressBar progress;
    private EditText containerSearch;
    private ContainerRecord selected;
    private int pendingBackupId;
    private Shortcut pendingArtworkShortcut;
    private String lastLogs = "";
    private int sortMode = 0;
    private boolean largeText = false;
    private int createdFeatureGroups = 0;

    private static final class ContainerRecord {
        final int id;
        final File dir;
        final File config;
        final JSONObject data;
        final String name;
        long sizeBytes;

        ContainerRecord(int id, File dir, JSONObject data) {
            this.id = id;
            this.dir = dir;
            this.config = new File(dir, ".container");
            this.data = data;
            this.name = data.optString("name", "Container-" + id);
        }
    }

    public static void recordGameLaunch(Context context, Shortcut shortcut) {
        if (context == null || shortcut == null || shortcut.file == null || shortcut.file.isDirectory()) return;
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            org.json.JSONArray recent = new org.json.JSONArray(prefs.getString("recent_games", "[]"));
            org.json.JSONObject item = new org.json.JSONObject();
            item.put("name", shortcut.name);
            item.put("containerId", shortcut.container.id);
            item.put("path", shortcut.file.getAbsolutePath());
            item.put("time", System.currentTimeMillis());
            recent.put(item);
            while (recent.length() > 40) recent.remove(0);
            prefs.edit().putString("recent_games", recent.toString()).apply();
        }
        catch (Exception ignored) { }
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        preferences = getSharedPreferences(PREFS, MODE_PRIVATE);
        rootFS = RootFS.find(this);
        homeDir = new File(rootFS.getRootDir(), "home");
        largeText = preferences.getBoolean("large_text", false);
        buildInterface();
        loadContainers(false);
        if (getIntent().getBooleanExtra("open_session_logs", false)) {
            main.post(this::collectSessionLogs);
        }
    }

    @Override
    protected void onDestroy() {
        io.shutdown();
        main.removeCallbacksAndMessages(null);
        super.onDestroy();
    }

    private int dp(float value) {
        return (int)(value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void buildInterface() {
        page = new FrameLayout(this);
        page.setFocusable(true);
        page.setFocusableInTouchMode(true);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(dp(16), dp(14), dp(16), dp(24));

        TextView heading = new TextView(this);
        heading.setText("WinCore 7.0.0");
        heading.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 26 : 23);
        heading.setTypeface(null, 1);
        column.addView(heading, matchWrap());

        TextView subtitle = new TextView(this);
        subtitle.setText("container workspace • backups • recovery • library • diagnostics");
        subtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 16 : 13);
        subtitle.setPadding(0, dp(3), 0, dp(10));
        column.addView(subtitle, matchWrap());

        selectedLabel = new TextView(this);
        selectedLabel.setText("selected container: none");
        selectedLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 17 : 15);
        selectedLabel.setPadding(0, dp(7), 0, dp(7));
        column.addView(selectedLabel, matchWrap());

        LinearLayout selectionRow = new LinearLayout(this);
        selectionRow.setOrientation(LinearLayout.HORIZONTAL);
        Button choose = makeButton("select container");
        choose.setOnClickListener(v -> chooseContainer());
        Button refresh = makeButton("refresh");
        refresh.setOnClickListener(v -> loadContainers(true));
        Button sessionLogs = makeButton("Session Logs");
        sessionLogs.setOnClickListener(v -> collectSessionLogs());
        selectionRow.addView(choose, new LinearLayout.LayoutParams(0, dp(48), 1));
        selectionRow.addView(refresh, new LinearLayout.LayoutParams(0, dp(48), 1));
        selectionRow.addView(sessionLogs, new LinearLayout.LayoutParams(0, dp(48), 1));
        column.addView(selectionRow, matchWrap());

        containerSearch = new EditText(this);
        containerSearch.setSingleLine(true);
        containerSearch.setHint("search features or containers");
        containerSearch.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 17 : 15);
        containerSearch.setContentDescription("Search WinCore features and container names");
        containerSearch.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { filterFeatures(s.toString()); }
            @Override public void afterTextChanged(android.text.Editable e) { }
        });
        column.addView(containerSearch, matchWrap());

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setIndeterminate(true);
        progress.setVisibility(View.GONE);
        column.addView(progress, matchWrap());

        status = new TextView(this);
        status.setText("loading container index…");
        status.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 16 : 14);
        status.setPadding(0, dp(8), 0, dp(12));
        status.setTextIsSelectable(true);
        column.addView(status, matchWrap());

        featureRoot = new LinearLayout(this);
        featureRoot.setOrientation(LinearLayout.VERTICAL);
        column.addView(featureRoot, matchWrap());
        addFeatureSection("container manager", new int[]{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20});
        addFeatureSection("launch readiness and diagnostics", new int[]{21,22,23,24,25,26,27,28,29,30});
        addFeatureSection("game library and navigation", new int[]{31,32,33,34,35,36,37,38,39,40});
        addFeatureSection("recovery and verification", new int[]{41,42,43,44,45,46,47,48,49,50});

        scroll.addView(column, new ScrollView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        contentParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        int widthDp = (int)(getResources().getDisplayMetrics().widthPixels / getResources().getDisplayMetrics().density);
        if (widthDp >= 800) contentParams.width = dp(760);
        page.addView(scroll, contentParams);
        setContentView(page);
        page.requestFocus();
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private Button makeButton(String label) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, largeText ? 16 : 14);
        button.setAllCaps(false);
        button.setMinHeight(dp(48));
        button.setMinimumHeight(dp(48));
        button.setFocusable(true);
        button.setFocusableInTouchMode(true);
        button.setContentDescription(label);
        return button;
    }

    private void addFeatureSection(String title, int[] featureIds) {
        Button header = makeButton(title + "  ▾");
        header.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setVisibility(View.GONE);
        featureRoot.addView(header, matchWrap());
        featureRoot.addView(panel, matchWrap());
        featureGroups.add(panel);
        final boolean[] built = {false};
        header.setOnClickListener(v -> {
            if (!built[0]) {
                for (int id : featureIds) {
                    String label = featureLabel(id);
                    Button button = makeButton(String.format(Locale.US, "%02d  %s", id, label));
                    button.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
                    button.setOnClickListener(x -> runFeature(id));
                    panel.addView(button, matchWrap());
                    featureButtons.add(button);
                }
                built[0] = true;
            }
            panel.setVisibility(panel.getVisibility() == View.VISIBLE ? View.GONE : View.VISIBLE);
            header.setText(title + (panel.getVisibility() == View.VISIBLE ? "  ▴" : "  ▾"));
            filterFeatures(containerSearch.getText().toString());
        });
    }

    private String featureLabel(int id) {
        String[] labels = {
            "instant container selection", "background container loading", "container metadata cache",
            "smart cache invalidation", "lazy tab loading", "lazy registry access",
            "asynchronous registry processing", "loading progress indicator", "corrupted-container isolation",
            "atomic configuration saving", "container search", "custom sorting", "favorite containers",
            "recently opened containers", "storage usage dashboard", "complete container backup",
            "verified container restoration", "configuration snapshots", "duplicate progress tracking",
            "bulk backup management", "pre-launch inspection", "missing runtime detector",
            "Wine prefix health check", "per-session log collection", "crash report analyzer",
            "safe launch mode", "custom executable arguments", "configuration comparison",
            "shader cache manager", "game compatibility catalogue", "controller-first navigation",
            "quick container actions", "game library search", "game categories", "custom game artwork",
            "recently played games screen", "improved contextual error messages", "accessibility improvements",
            "tablet layout", "advanced settings search", "automatic configuration backups",
            "configuration rollback", "container migration assistant", "storage cleanup assistant",
            "container permission repair", "upstream compatibility checker", "automated container tests",
            "automated UI tests", "APK regression testing", "build diagnostics report"
        };
        return labels[id - 1];
    }

    private void filterFeatures(String query) {
        String q = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        for (Button button : featureButtons) {
            button.setVisibility(q.isEmpty() || button.getText().toString().toLowerCase(Locale.ROOT).contains(q) ? View.VISIBLE : View.GONE);
        }
    }

    private void setStatus(String message) {
        status.setText(message);
        status.sendAccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT);
    }

    private void loadContainers(boolean invalidateCache) {
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(false);
        progress.setMax(100);
        progress.setProgress(0);
        scanErrors.clear();
        setStatus("scanning container folders in the background…");
        io.execute(() -> {
            ArrayList<ContainerRecord> found = new ArrayList<>();
            File[] dirs = homeDir.listFiles();
            int total = dirs == null ? 0 : dirs.length;
            int visited = 0;
            if (dirs != null) {
                for (File dir : dirs) {
                    visited++;
                    if (dir.isDirectory() && dir.getName().startsWith(RootFS.USER + "-")) {
                        try {
                            int id = Integer.parseInt(dir.getName().substring((RootFS.USER + "-").length()));
                            File cfg = new File(dir, ".container");
                            if (!cfg.isFile()) throw new IllegalStateException("configuration file is missing");
                            String cacheKey = "container_meta_" + id;
                            long modified = cfg.lastModified();
                            long length = cfg.length();
                            String cached = preferences.getString(cacheKey, "");
                            boolean cacheValid = !invalidateCache &&
                                preferences.getLong(cacheKey + "_modified", -1L) == modified &&
                                preferences.getLong(cacheKey + "_length", -1L) == length &&
                                !cached.isEmpty();
                            JSONObject data = cacheValid ? new JSONObject(cached) : new JSONObject(readText(cfg));
                            if (!cacheValid) {
                                preferences.edit().putString(cacheKey, data.toString())
                                    .putLong(cacheKey + "_modified", modified)
                                    .putLong(cacheKey + "_length", length).apply();
                            }
                            found.add(new ContainerRecord(id, dir, data));
                        }
                        catch (Exception error) {
                            scanErrors.add(dir.getName() + ": " + safeMessage(error));
                        }
                    }
                    final int p = total == 0 ? 100 : (visited * 100 / total);
                    main.post(() -> progress.setProgress(p));
                }
            }
            found.sort(Comparator.comparingInt(record -> record.id));
            main.post(() -> {
                containers.clear();
                containers.addAll(found);
                if (selected != null) {
                    selected = findContainer(selected.id);
                }
                if (selected == null && !containers.isEmpty()) selected = containers.get(0);
                updateSelectedLabel();
                progress.setVisibility(View.GONE);
                setStatus("loaded " + containers.size() + " container(s); isolated " + scanErrors.size() + " unreadable folder(s).");
                if (preferences.getBoolean("automatic_backups", false)) {
                    io.execute(() -> {
                        ArrayList<String> snapshotErrors = new ArrayList<>();
                        for (ContainerRecord record : found) {
                            try {
                                createSnapshot(record, "automatic-open");
                            }
                            catch (Exception error) {
                                snapshotErrors.add(record.name + ": " + safeMessage(error));
                            }
                        }
                        if (!snapshotErrors.isEmpty()) {
                            final String summary = String.join("; ", snapshotErrors);
                            main.post(() -> setStatus("some automatic snapshots could not be created: " + summary));
                        }
                    });
                }
            });
        });
    }

    private ContainerRecord findContainer(int id) {
        for (ContainerRecord record : containers) if (record.id == id) return record;
        return null;
    }

    private void updateSelectedLabel() {
        selectedLabel.setText(selected == null ? "selected container: none" :
            "selected: " + selected.name + "  •  id " + selected.id);
    }

    private void chooseContainer() {
        String query = containerSearch.getText().toString().trim().toLowerCase(Locale.ROOT);
        ArrayList<ContainerRecord> matches = new ArrayList<>();
        for (ContainerRecord record : containers) {
            if (query.isEmpty() || record.name.toLowerCase(Locale.ROOT).contains(query) ||
                String.valueOf(record.id).contains(query)) matches.add(record);
        }
        if (matches.isEmpty()) {
            setStatus(containers.isEmpty() ? "no readable containers were found." : "no containers matched the current search.");
            return;
        }
        String[] names = new String[matches.size()];
        for (int i = 0; i < matches.size(); i++) names[i] = matches.get(i).name + "  (id " + matches.get(i).id + ")";
        new AlertDialog.Builder(this).setTitle("select container").setItems(names, (dialog, which) -> {
            selected = matches.get(which);
            updateSelectedLabel();
            preferences.edit().putString("recent_containers", addRecent(preferences.getString("recent_containers", ""), selected.id)).apply();
        }).setNegativeButton("cancel", null).show();
    }

    private String addRecent(String current, int id) {
        ArrayList<String> values = new ArrayList<>(Arrays.asList(current.split(",")));
        values.remove(String.valueOf(id));
        values.add(0, String.valueOf(id));
        while (values.size() > 20) values.remove(values.size() - 1);
        return String.join(",", values);
    }

    private ContainerRecord requireSelected() {
        if (selected != null) return selected;
        if (!containers.isEmpty()) selected = containers.get(0);
        updateSelectedLabel();
        return selected;
    }

    private void runFeature(int id) {
        try {
            switch (id) {
                case 1: chooseContainer(); break;
                case 2: loadContainers(false); break;
                case 3: showMetadataCache(); break;
                case 4: invalidateMetadataCache(); loadContainers(true); setStatus("container metadata cache invalidated; favourites, recents and workspace settings were preserved."); break;
                case 5: setStatus("the four feature groups are created on first expansion; collapse or expand a group to load its controls lazily."); break;
                case 6: setStatus("lazy registry copy-on-write is integrated in WineRegistryEditor: registry reads use the original file; a temporary copy is made only for edits."); break;
                case 7: inspectRegistryAsync(); break;
                case 8: loadContainers(false); setStatus("background scan started; progress is shown above."); break;
                case 9: setStatus(scanErrors.isEmpty() ? "no unreadable container configuration was found in the last scan." : "isolated unreadable containers:\n" + join(scanErrors)); break;
                case 10: saveSelectedConfig(); break;
                case 11: containerSearch.requestFocus(); setStatus("type a name or feature name in the search field above."); break;
                case 12: cycleSort(); break;
                case 13: toggleFavorite(); break;
                case 14: showRecentContainers(); break;
                case 15: storageDashboard(); break;
                case 16: requestBackup(false); break;
                case 17: requestRestore(); break;
                case 18: createSelectedSnapshot(); break;
                case 19: duplicateSelectedWithProgress(); break;
                case 20: requestBackup(true); break;
                case 21: preLaunchInspection(); break;
                case 22: missingRuntimeReport(); break;
                case 23: winePrefixHealth(); break;
                case 24: collectSessionLogs(); break;
                case 25: analyzeCrashReport(); break;
                case 26: toggleSafeLaunch(); break;
                case 27: editExecutableArguments(); break;
                case 28: compareConfiguration(); break;
                case 29: manageShaderCache(); break;
                case 30: showCompatibilityCatalogue(); break;
                case 31: showControllerDiagnostics(); break;
                case 32: quickActions(); break;
                case 33: showGameLibrary(); break;
                case 34: editGameCategory(); break;
                case 35: chooseArtworkShortcut(); break;
                case 36: showRecentlyPlayedGames(); break;
                case 37: showContextualErrors(); break;
                case 38: toggleAccessibility(); break;
                case 39: showTabletLayoutStatus(); break;
                case 40: containerSearch.requestFocus(); setStatus("advanced settings search is available in the search field; filter by feature name."); break;
                case 41: toggleAutomaticBackups(); break;
                case 42: rollbackConfiguration(); break;
                case 43: migrateContainerConfigurations(); break;
                case 44: cleanupStorage(); break;
                case 45: repairContainerPermissions(); break;
                case 46: checkUpstreamCompatibility(); break;
                case 47: runContainerTests(); break;
                case 48: runUiTests(); break;
                case 49: runApkRegressionCheck(); break;
                case 50: exportBuildDiagnostics(); break;
                default: setStatus("unknown feature."); break;
            }
        }
        catch (Exception error) {
            showError("Feature " + id + " failed", error);
        }
    }

    private void invalidateMetadataCache() {
        SharedPreferences.Editor editor = preferences.edit();
        for (String key : preferences.getAll().keySet()) {
            if (key.startsWith("container_meta_")) editor.remove(key);
        }
        editor.apply();
    }

    private void showMetadataCache() {
        int cached = 0;
        for (ContainerRecord record : containers) if (!preferences.getString("container_meta_" + record.id, "").isEmpty()) cached++;
        setStatus("metadata cache: " + cached + " of " + containers.size() + " containers have cached metadata. Entries are reused only while config modification time and size match.");
    }

    private void inspectRegistryAsync() {
        final ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        setStatus("checking registry files on the background worker…");
        io.execute(() -> {
            File prefix = new File(record.dir, ".wine");
            File[] registry = prefix.listFiles((dir, name) -> name.endsWith(".reg"));
            StringBuilder report = new StringBuilder("ASYNC REGISTRY CHECK\n");
            if (registry == null || registry.length == 0) report.append("No registry files found in this prefix.");
            else for (File file : registry) report.append(file.getName()).append(": ").append(file.length()).append(" bytes; ").append(file.canRead() ? "readable" : "not readable").append("\n");
            main.post(() -> { progress.setVisibility(View.GONE); setStatus(report.toString()); });
        });
    }

    private void cycleSort() {
        sortMode = (sortMode + 1) % 3;
        if (sortMode == 0) containers.sort(Comparator.comparing(record -> record.name.toLowerCase(Locale.ROOT)));
        else if (sortMode == 1) containers.sort((a, b) -> Long.compare(b.sizeBytes, a.sizeBytes));
        else containers.sort((a, b) -> Integer.compare(recentRank(a.id), recentRank(b.id)));
        setStatus("container sort: " + (sortMode == 0 ? "name" : sortMode == 1 ? "storage size (unknown sizes last)" : "recently opened") + ". use select container to browse the sorted list.");
    }

    private int recentRank(int id) {
        String[] values = preferences.getString("recent_containers", "").split(",");
        for (int i = 0; i < values.length; i++) if (values[i].equals(String.valueOf(id))) return i;
        return 9999;
    }

    private void toggleFavorite() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        Set<String> favorites = new HashSet<>(preferences.getStringSet("favorites", new HashSet<>()));
        String id = String.valueOf(record.id);
        boolean added = favorites.add(id);
        if (!added) favorites.remove(id);
        preferences.edit().putStringSet("favorites", favorites).apply();
        setStatus(record.name + (added ? " added to favorites." : " removed from favorites."));
    }

    private void showRecentContainers() {
        StringBuilder out = new StringBuilder("RECENTLY OPENED CONTAINERS\n");
        String[] recent = preferences.getString("recent_containers", "").split(",");
        for (String item : recent) {
            if (item.isEmpty()) continue;
            try {
                int id = Integer.parseInt(item);
                ContainerRecord record = findContainer(id);
                out.append(record != null ? record.name : "container " + id + " (not found)").append("\n");
            }
            catch (NumberFormatException ignored) { }
        }
        if (out.toString().endsWith("\n")) out.append("No recent containers recorded.");
        setStatus(out.toString());
    }

    private void storageDashboard() {
        if (containers.isEmpty()) { setStatus("no containers to measure."); return; }
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        setStatus("measuring container storage on the background worker…");
        io.execute(() -> {
            long total = 0;
            StringBuilder report = new StringBuilder("STORAGE USAGE\n");
            for (ContainerRecord record : containers) {
                record.sizeBytes = directorySize(record.dir);
                total += record.sizeBytes;
                report.append(record.name).append(": ").append(formatBytes(record.sizeBytes)).append("\n");
            }
            report.append("Total: ").append(formatBytes(total));
            main.post(() -> { progress.setVisibility(View.GONE); setStatus(report.toString()); });
        });
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024L * 1024L) return String.format(Locale.US, "%.1f KiB", bytes / 1024.0);
        if (bytes < 1024L * 1024L * 1024L) return String.format(Locale.US, "%.1f MiB", bytes / (1024.0 * 1024.0));
        return String.format(Locale.US, "%.2f GiB", bytes / (1024.0 * 1024.0 * 1024.0));
    }

    private long directorySize(File file) {
        if (file == null || !file.exists() || Files.isSymbolicLink(file.toPath())) return 0;
        if (file.isFile()) return file.length();
        long total = 0;
        File[] children = file.listFiles();
        if (children != null) for (File child : children) total += directorySize(child);
        return total;
    }

    private void requestBackup(boolean bulk) {
        pendingBackupId = bulk ? 0 : (requireSelected() == null ? -1 : selected.id);
        if (pendingBackupId < 0) { setStatus("select a container before backing it up."); return; }
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/zip");
        intent.putExtra(Intent.EXTRA_TITLE, bulk ? "WinCore-containers-backup.zip" : "WinCore-container-" + pendingBackupId + ".zip");
        startActivityForResult(intent, REQUEST_BACKUP);
    }

    private void requestRestore() {
        if (requireSelected() == null) { setStatus("select the destination container first."); return; }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/zip");
        startActivityForResult(intent, REQUEST_RESTORE);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        if (requestCode == REQUEST_BACKUP) {
            final int target = pendingBackupId;
            progress.setVisibility(View.VISIBLE);
            progress.setIndeterminate(true);
            setStatus("creating verified backup archive…");
            io.execute(() -> {
                OutputStream destination;
                try {
                    destination = getContentResolver().openOutputStream(uri);
                }
                catch (Exception error) {
                    main.post(() -> {
                        progress.setVisibility(View.GONE);
                        showError("Backup failed", error);
                    });
                    return;
                }
                if (destination == null) {
                    main.post(() -> { progress.setVisibility(View.GONE); setStatus("backup failed: the document provider did not open the destination."); });
                    return;
                }
                try (OutputStream out = destination;
                     ZipOutputStream zip = new ZipOutputStream(new BufferedOutputStream(out))) {
                    org.json.JSONArray links = new org.json.JSONArray();
                    if (target == 0) {
                        for (ContainerRecord record : new ArrayList<>(containers)) zipDirectory(record.dir, "xuser-" + record.id + "/", zip, links);
                    }
                    else {
                        ContainerRecord record = findContainer(target);
                        if (record == null) throw new IOException("The selected container is no longer available.");
                        zipDirectory(record.dir, "", zip, links);
                    }
                    writeSymlinkManifest(zip, links);
                    final int symlinkCount = links.length();
                    main.post(() -> { progress.setVisibility(View.GONE); setStatus("backup completed. included hidden files, configuration and " + symlinkCount + " symbolic link(s)."); });
                }
                catch (Exception error) { main.post(() -> { progress.setVisibility(View.GONE); showError("Backup failed", error); }); }
            });
        }
        else if (requestCode == REQUEST_RESTORE) {
            final ContainerRecord record = selected;
            if (record == null) return;
            progress.setVisibility(View.VISIBLE);
            progress.setIndeterminate(true);
            setStatus("validating and extracting backup to a temporary folder…");
            io.execute(() -> {
                try {
                    restoreFromUri(uri, record);
                    main.post(() -> { progress.setVisibility(View.GONE); setStatus("restore completed and the container configuration was validated before replacement."); loadContainers(true); });
                }
                catch (Exception error) { main.post(() -> { progress.setVisibility(View.GONE); showError("Restore was stopped; existing container data was preserved", error); }); }
            });
        }
        else if (requestCode == REQUEST_ARTWORK && pendingArtworkShortcut != null) {
            final Shortcut shortcut = pendingArtworkShortcut;
            pendingArtworkShortcut = null;
            try { getContentResolver().takePersistableUriPermission(uri, data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION)); }
            catch (Exception ignored) { }
            io.execute(() -> {
                try {
                    BitmapFactory.Options bounds = new BitmapFactory.Options();
                    bounds.inJustDecodeBounds = true;
                    try (InputStream in = getContentResolver().openInputStream(uri)) {
                        BitmapFactory.decodeStream(in, null, bounds);
                    }
                    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw new IOException("The selected image could not be decoded.");
                    BitmapFactory.Options decode = new BitmapFactory.Options();
                    decode.inSampleSize = 1;
                    while (bounds.outWidth / decode.inSampleSize > 512 || bounds.outHeight / decode.inSampleSize > 512) {
                        decode.inSampleSize *= 2;
                    }
                    Bitmap bitmap;
                    try (InputStream in = getContentResolver().openInputStream(uri)) {
                        bitmap = BitmapFactory.decodeStream(in, null, decode);
                    }
                    if (bitmap == null) throw new IOException("The selected image could not be decoded.");
                    String iconKey = shortcut.container.id + ":" + shortcut.file.getAbsolutePath();
                    String iconName = "wincore-custom-" + Integer.toUnsignedString(iconKey.hashCode(), 16);
                    File iconFile = new File(shortcut.container.getIconsDir(64), iconName + ".png");
                    iconFile.getParentFile().mkdirs();
                    try (FileOutputStream out = new FileOutputStream(iconFile)) {
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
                    }
                    bitmap.recycle();
                    setDesktopIcon(shortcut.file, iconName);
                    main.post(() -> setStatus("custom artwork installed for " + shortcut.name + "."));
                }
                catch (Exception error) { main.post(() -> showError("Artwork import failed", error)); }
            });
        }
        else if (requestCode == REQUEST_LOG_EXPORT) {
            final String logs = lastLogs;
            io.execute(() -> {
                try (OutputStream out = getContentResolver().openOutputStream(uri)) {
                    if (out == null) throw new IOException("The document provider did not open the destination.");
                    out.write(logs.getBytes(StandardCharsets.UTF_8));
                    main.post(() -> setStatus("diagnostic report exported."));
                }
                catch (Exception error) { main.post(() -> showError("Export failed", error)); }
            });
        }
    }

    private void zipDirectory(File root, String prefix, ZipOutputStream zip, org.json.JSONArray links) throws IOException {
        File[] files = root.listFiles();
        if (files == null) throw new IOException("Cannot read " + root.getName());
        for (File file : files) {
            String name = prefix + file.getName();
            if (Files.isSymbolicLink(file.toPath())) {
                JSONObject link = new JSONObject();
                try {
                    link.put("path", name);
                    link.put("target", Files.readSymbolicLink(file.toPath()).toString());
                    links.put(link);
                }
                catch (JSONException error) {
                    throw new IOException("Could not record symbolic link " + name, error);
                }
                continue;
            }
            if (file.isDirectory()) {
                zip.putNextEntry(new ZipEntry(name + "/"));
                zip.closeEntry();
                zipDirectory(file, name + "/", zip, links);
            }
            else {
                zip.putNextEntry(new ZipEntry(name));
                try (InputStream in = new BufferedInputStream(new FileInputStream(file))) {
                    byte[] buffer = new byte[64 * 1024];
                    int read;
                    while ((read = in.read(buffer)) != -1) zip.write(buffer, 0, read);
                }
                zip.closeEntry();
            }
        }
    }

    private void writeSymlinkManifest(ZipOutputStream zip, org.json.JSONArray links) throws IOException {
        if (links.length() == 0) return;
        zip.putNextEntry(new ZipEntry(".wincore-backup/symlinks.json"));
        zip.write(links.toString().getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }

    private void restoreSymlinks(File staging, org.json.JSONArray links, int targetId) throws Exception {
        HashSet<String> linkNames = new HashSet<>();
        for (int i = 0; i < links.length(); i++) {
            String name = links.getJSONObject(i).getString("path").replace('\\', '/');
            if (name.startsWith("xuser-")) {
                String prefix = "xuser-" + targetId + "/";
                if (!name.startsWith(prefix)) continue;
                name = name.substring(prefix.length());
            }
            if (name.startsWith("/") || name.contains("../") || name.equals("..") || !linkNames.add(name))
                throw new IOException("Unsafe or duplicate symbolic link path in backup.");
        }
        for (String name : linkNames) {
            String parent = name;
            while (parent.contains("/")) {
                parent = parent.substring(0, parent.lastIndexOf('/'));
                if (linkNames.contains(parent)) throw new IOException("A symbolic link cannot contain another archived link.");
            }
        }
        for (int i = 0; i < links.length(); i++) {
            JSONObject item = links.getJSONObject(i);
            String relativeName = item.getString("path").replace('\\', '/');
            if (relativeName.startsWith("xuser-")) {
                String prefix = "xuser-" + targetId + "/";
                if (!relativeName.startsWith(prefix)) continue;
                relativeName = relativeName.substring(prefix.length());
            }
            String targetText = item.getString("target");
            if (targetText.isEmpty() || targetText.length() > 4096) throw new IOException("Invalid symbolic link target.");
            Path normalizedRoot = staging.toPath().toAbsolutePath().normalize();
            Path normalizedLink = new File(staging, relativeName).toPath().toAbsolutePath().normalize();
            if (!normalizedLink.startsWith(normalizedRoot)) throw new IOException("Symbolic link path escaped the staging folder.");
            Path targetPath = Paths.get(targetText);
            if (!targetPath.isAbsolute()) {
                Path resolved = normalizedLink.getParent().resolve(targetPath).normalize();
                if (!resolved.startsWith(normalizedRoot)) throw new IOException("Relative symbolic link escapes the staging folder.");
            }
            else {
                String absolute = targetPath.normalize().toString();
                boolean allowed = absolute.equals("/") || absolute.equals("/home/xuser") ||
                    absolute.startsWith("/home/xuser/") || absolute.equals("/tmp") ||
                    absolute.startsWith("/tmp/") || absolute.equals("/opt") || absolute.startsWith("/opt/") ||
                    absolute.equals("/usr") || absolute.startsWith("/usr/") ||
                    absolute.equals("/etc") || absolute.startsWith("/etc/") ||
                    absolute.equals("/dev") || absolute.startsWith("/dev/") ||
                    absolute.equals("/proc") || absolute.startsWith("/proc/");
                if (!allowed) throw new IOException("Absolute symbolic link target is outside the permitted Wine runtime paths.");
            }
            File parent = normalizedLink.getParent().toFile();
            if (!parent.isDirectory() && !parent.mkdirs()) throw new IOException("Could not create symbolic link parent.");
            if (Files.exists(normalizedLink) || Files.isSymbolicLink(normalizedLink)) throw new IOException("Symbolic link path already exists in backup.");
            Files.createSymbolicLink(normalizedLink, targetPath);
        }
    }

    private void restoreFromUri(Uri uri, ContainerRecord record) throws Exception {
        File staging = new File(homeDir, ".restore-" + record.id + "-" + System.currentTimeMillis());
        if (!staging.mkdirs()) throw new IOException("Could not create restore staging folder.");
        long total = 0;
        int entries = 0;
        org.json.JSONArray symlinks = new org.json.JSONArray();
        try {
            InputStream source = getContentResolver().openInputStream(uri);
            if (source == null) throw new IOException("The selected backup could not be opened.");
            try (ZipInputStream zip = new ZipInputStream(new BufferedInputStream(source))) {
            ZipEntry entry;
            byte[] buffer = new byte[64 * 1024];
            HashSet<String> restoredEntryNames = new HashSet<>();
            boolean symlinkManifestSeen = false;
            while ((entry = zip.getNextEntry()) != null) {
                if (++entries > MAX_RESTORE_ENTRIES) throw new IOException("The backup contains too many entries.");
                String name = entry.getName().replace('\\', '/');
                if (name.equals(".wincore-backup/symlinks.json")) {
                    if (symlinkManifestSeen) throw new IOException("Backup contains duplicate symbolic link manifests.");
                    symlinkManifestSeen = true;
                    ByteArrayOutputStream manifestBytes = new ByteArrayOutputStream();
                    int read;
                    long manifestSize = 0;
                    while ((read = zip.read(buffer)) != -1) {
                        total += read;
                        manifestSize += read;
                        if (manifestSize > 1024 * 1024) throw new IOException("Symbolic link manifest exceeds 1 MiB.");
                        manifestBytes.write(buffer, 0, read);
                    }
                    symlinks = new org.json.JSONArray(manifestBytes.toString("UTF-8"));
                    zip.closeEntry();
                    continue;
                }
                if (name.startsWith("/") || name.contains("../") || name.equals("..")) throw new IOException("Unsafe path in backup archive.");
                if (name.startsWith("xuser-" + record.id + "/")) name = name.substring(("xuser-" + record.id + "/").length());
                else if (name.startsWith("xuser-")) {
                    zip.closeEntry();
                    continue;
                }
                if (!restoredEntryNames.add(name)) throw new IOException("Backup contains a duplicate path: " + name);
                File output = new File(staging, name);
                String canonicalRoot = staging.getCanonicalPath() + File.separator;
                if (!output.getCanonicalPath().startsWith(canonicalRoot) && !output.equals(staging)) throw new IOException("Backup path escaped the staging folder.");
                if (entry.isDirectory()) output.mkdirs();
                else {
                    File parent = output.getParentFile();
                    if (parent != null) parent.mkdirs();
                    try (OutputStream out = new BufferedOutputStream(new FileOutputStream(output))) {
                        int read;
                        while ((read = zip.read(buffer)) != -1) {
                            total += read;
                            if (total > MAX_RESTORE_BYTES) throw new IOException("Backup is larger than the 8 GiB restore limit.");
                            out.write(buffer, 0, read);
                        }
                    }
                }
                zip.closeEntry();
            }
            restoreSymlinks(staging, symlinks, record.id);
            File stagedConfig = new File(staging, ".container");
            if (!stagedConfig.isFile()) throw new IOException("Backup does not contain a root .container file.");
            JSONObject restored = new JSONObject(readText(stagedConfig));
            restored.put("id", record.id);
            writeAtomicNoSnapshot(stagedConfig, restored.toString());
            File oldBackup = new File(homeDir, ".rollback-before-restore-" + record.id);
            deleteRecursively(oldBackup);
            if (!record.dir.renameTo(oldBackup)) throw new IOException("Could not move the existing container to its rollback location.");
            File target = new File(homeDir, RootFS.USER + "-" + record.id);
            if (!staging.renameTo(target)) {
                if (!oldBackup.renameTo(record.dir)) {
                    throw new IOException("Could not install the validated restore, and automatic rollback failed. Previous data remains at: " + oldBackup.getAbsolutePath());
                }
                throw new IOException("Could not install the validated restore. The previous container was restored.");
            }
            preferences.edit().putString("last_restore_backup_" + record.id, oldBackup.getAbsolutePath()).apply();
            deleteRecursively(oldBackup);
            }
        }
        catch (Exception error) {
            deleteRecursively(staging);
            throw error;
        }
    }

    private void duplicateSelectedWithProgress() {
        ContainerRecord source = requireSelected();
        if (source == null) { setStatus("select a container first."); return; }
        final ContainerRecord original = source;
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        setStatus("duplicating " + source.name + "…");
        io.execute(() -> {
            File[] dirs = homeDir.listFiles();
            int nextId = 1;
            if (dirs != null) for (File dir : dirs) {
                if (dir.getName().startsWith(RootFS.USER + "-")) {
                    try { nextId = Math.max(nextId, Integer.parseInt(dir.getName().substring((RootFS.USER + "-").length())) + 1); }
                    catch (NumberFormatException ignored) { }
                }
            }
            final int newId = nextId;
            File target = new File(homeDir, RootFS.USER + "-" + newId);
            try {
                copyRecursively(original.dir, target);
                File config = new File(target, ".container");
                JSONObject json = new JSONObject(readText(config));
                json.put("id", newId);
                json.put("name", original.name + " (Copy)");
                writeAtomicNoSnapshot(config, json.toString());
                main.post(() -> { progress.setVisibility(View.GONE); setStatus("duplicate created as container " + newId + "."); loadContainers(true); });
            }
            catch (Exception error) {
                deleteRecursively(target);
                main.post(() -> { progress.setVisibility(View.GONE); showError("Duplicate failed", error); });
            }
        });
    }

    private void copyRecursively(File source, File target) throws IOException {
        if (Files.isSymbolicLink(source.toPath())) {
            Path linkTarget = Files.readSymbolicLink(source.toPath());
            Path parent = target.toPath().getParent();
            if (parent != null) Files.createDirectories(parent);
            Files.createSymbolicLink(target.toPath(), linkTarget);
            return;
        }
        if (source.isDirectory()) {
            if (!target.mkdirs() && !target.isDirectory()) throw new IOException("Could not create " + target);
            File[] children = source.listFiles();
            if (children == null) throw new IOException("Could not read " + source);
            for (File child : children) copyRecursively(child, new File(target, child.getName()));
        }
        else {
            File parent = target.getParentFile();
            if (parent != null) parent.mkdirs();
            try (InputStream in = new BufferedInputStream(new FileInputStream(source));
                 OutputStream out = new BufferedOutputStream(new FileOutputStream(target))) {
                byte[] buffer = new byte[64 * 1024];
                int count;
                while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
            }
        }
    }

    private void createSelectedSnapshot() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        io.execute(() -> {
            try { File snapshot = createSnapshot(record, "manual"); main.post(() -> setStatus("configuration snapshot saved: " + snapshot.getName())); }
            catch (Exception error) { main.post(() -> showError("Snapshot failed", error)); }
        });
    }

    private File createSnapshot(ContainerRecord record, String reason) throws IOException {
        File folder = new File(getFilesDir(), "wincore7/snapshots/" + record.id);
        if (!folder.exists() && !folder.mkdirs()) throw new IOException("Could not create snapshot folder.");
        long timestamp = System.currentTimeMillis();
        File snapshot = new File(folder, timestamp + "-" + reason + ".json");
        while (snapshot.exists()) snapshot = new File(folder, ++timestamp + "-" + reason + ".json");
        try (InputStream in = new FileInputStream(record.config); OutputStream out = new FileOutputStream(snapshot)) {
            byte[] buffer = new byte[16 * 1024];
            int count;
            while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
        }
        File[] saved = folder.listFiles((dir, name) -> name.endsWith(".json"));
        if (saved != null && saved.length > 20) {
            Arrays.sort(saved, (a, b) -> Long.compare(b.lastModified(), a.lastModified()));
            for (int index = 20; index < saved.length; index++) {
                if (!saved[index].delete()) android.util.Log.w("WinCore7", "Could not prune old snapshot: " + saved[index]);
            }
        }
        return snapshot;
    }

    private List<File> snapshots(int id) {
        File folder = new File(getFilesDir(), "wincore7/snapshots/" + id);
        File[] files = folder.listFiles((dir, name) -> name.endsWith(".json"));
        ArrayList<File> list = new ArrayList<>();
        if (files != null) list.addAll(Arrays.asList(files));
        list.sort((a, b) -> Long.compare(b.lastModified(), a.lastModified()));
        return list;
    }

    private void saveSelectedConfig() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        io.execute(() -> {
            try {
                if (preferences.getBoolean("automatic_backups", false)) createSnapshot(record, "before-save");
                writeAtomicNoSnapshot(record.config, record.data.toString());
                main.post(() -> setStatus("configuration written atomically. the previous file remains safe if the write is interrupted."));
            }
            catch (Exception error) { main.post(() -> showError("Atomic save failed", error)); }
        });
    }

    private void writeAtomicNoSnapshot(File file, String content) throws IOException {
        AtomicFile atomic = new AtomicFile(file);
        FileOutputStream out = null;
        try {
            out = atomic.startWrite();
            out.write(content.getBytes(StandardCharsets.UTF_8));
            out.flush();
            atomic.finishWrite(out);
        }
        catch (IOException error) {
            if (out != null) atomic.failWrite(out);
            throw error;
        }
    }

    private void rollbackConfiguration() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        List<File> saved = snapshots(record.id);
        if (saved.isEmpty()) { setStatus("no saved configuration snapshot exists for this container."); return; }
        new AlertDialog.Builder(this).setTitle("restore latest snapshot?")
            .setMessage("this replaces only the .container settings file. it does not replace the Wine prefix or game data.")
            .setNegativeButton("cancel", null).setPositiveButton("restore", (d, w) -> io.execute(() -> {
                try {
                    createSnapshot(record, "before-rollback");
                    writeAtomicNoSnapshot(record.config, readText(saved.get(0)));
                    main.post(() -> { setStatus("configuration rollback completed from " + saved.get(0).getName()); loadContainers(true); });
                }
                catch (Exception error) { main.post(() -> showError("Rollback failed", error)); }
            })).show();
    }

    private void compareConfiguration() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        List<File> saved = snapshots(record.id);
        if (saved.isEmpty()) { setStatus("save a snapshot first, then compare it with the current configuration."); return; }
        io.execute(() -> {
            try {
                JSONObject before = new JSONObject(readText(saved.get(0)));
                JSONObject now = new JSONObject(readText(record.config));
                StringBuilder out = new StringBuilder("CONFIGURATION COMPARISON\n");
                HashSet<String> keys = new HashSet<>();
                Iterator<String> a = before.keys(); while (a.hasNext()) keys.add(a.next());
                Iterator<String> b = now.keys(); while (b.hasNext()) keys.add(b.next());
                int differences = 0;
                for (String key : keys) {
                    String oldValue = before.optString(key, "<missing>");
                    String newValue = now.optString(key, "<missing>");
                    if (!oldValue.equals(newValue)) { out.append(key).append(": ").append(oldValue).append(" -> ").append(newValue).append("\n"); differences++; }
                }
                if (differences == 0) out.append("No top-level configuration differences were found.");
                main.post(() -> setStatus(out.toString()));
            }
            catch (Exception error) { main.post(() -> showError("Configuration comparison failed", error)); }
        });
    }

    private void preLaunchInspection() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        StringBuilder out = new StringBuilder("PRE-LAUNCH INSPECTION\n");
        out.append("configuration: ").append(record.config.isFile() ? "present" : "missing").append("\n");
        File localBox64 = new File(rootFS.getRootDir(), "usr/local/bin/box64");
        File legacyBox64 = new File(rootFS.getRootDir(), "usr/bin/box64");
        File box64Runtime = localBox64.isFile() ? localBox64 : (legacyBox64.isFile() ? legacyBox64 : null);
        out.append("Box64 runtime: ").append(box64Runtime == null ? "missing" :
            box64Runtime.getAbsolutePath() + (box64Runtime.canExecute() ? " (executable)" : " (not executable)")).append("\n");
        out.append("root filesystem: ").append(rootFS.isValid() ? "valid marker found" : "not validated").append("\n");
        out.append("Wine prefix: ").append(new File(record.dir, ".wine").isDirectory() ? "present" : "missing").append("\n");
        out.append("Windows system32: ").append(new File(record.dir, ".wine/drive_c/windows/system32").isDirectory() ? "present" : "missing").append("\n");
        out.append("Wine version id: ").append(record.data.optString("wineVersion", "main")).append("\n");
        out.append("Box64 preset id: ").append(record.data.optString("box64Preset", "default")).append("\n");
        out.append("graphics wrapper: ").append(record.data.optString("dxwrapper", "default")).append("\n");
        out.append("This is a file/configuration check, not a promise that the game will start.");
        setStatus(out.toString());
    }

    private void missingRuntimeReport() {
        File base = rootFS.getRootDir();
        StringBuilder out = new StringBuilder("MISSING RUNTIME DETECTOR\n");
        String[] paths = {"opt/wine/bin/wine", "usr/local/bin/box64", "usr/bin/box64", "usr/bin/box86", "usr/lib"};
        for (String path : paths) {
            File file = new File(base, path);
            out.append(path).append(": ").append(file.exists() ? "found" : "not found").append("\n");
        }
        setStatus(out.toString());
    }

    private void winePrefixHealth() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        String[] paths = {".wine", ".wine/drive_c", ".wine/drive_c/windows", ".wine/drive_c/windows/system32", ".wine/user.reg", ".wine/system.reg", ".wine/dosdevices"};
        StringBuilder out = new StringBuilder("WINE PREFIX HEALTH\n");
        for (String path : paths) out.append(path).append(": ").append(new File(record.dir, path).exists() ? "present" : "missing").append("\n");
        setStatus(out.toString());
    }

    private void collectSessionLogs() {
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        setStatus("collecting saved Box64/Wine process output and Android diagnostics…");
        io.execute(() -> {
            StringBuilder out = new StringBuilder();
            File logDirectory = new File(getFilesDir(), "wincore7");
            File previousProcessLog = new File(logDirectory, "ProcessOutput.previous.log");
            File processLog = new File(logDirectory, "ProcessOutput.log");
            boolean foundProcessOutput = false;
            if (previousProcessLog.isFile()) {
                out.append("===== PREVIOUS BOX64 / WINE PROCESS OUTPUT (ROTATED) =====\n");
                try { out.append(readText(previousProcessLog)).append("\n"); foundProcessOutput = true; }
                catch (Exception error) {
                    out.append("Could not read previous process output: ").append(safeMessage(error)).append("\n");
                }
            }
            if (processLog.isFile()) {
                out.append("===== LATEST BOX64 / WINE PROCESS OUTPUT =====\n");
                try { out.append(readText(processLog)).append("\n"); foundProcessOutput = true; }
                catch (Exception error) {
                    out.append("Could not read latest process output: ").append(safeMessage(error)).append("\n");
                }
            }
            if (!foundProcessOutput) {
                out.append("No persistent Box64/Wine process log exists yet. Start the container once after installing this build, then collect logs again. The log path is files/wincore7/ProcessOutput.log.\n");
            }

            out.append("\n===== ANDROID LOGCAT (WINCORE / BOX64 / WINE) =====\n");
            try {
                Process process = new ProcessBuilder("logcat", "-d", "-v", "threadtime", "-t", "4000")
                    .redirectErrorStream(true).start();
                try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8)
                )) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        String lower = line.toLowerCase(Locale.ROOT);
                        if (line.contains("WinCore/") || line.contains("WinCore") ||
                            line.contains("Box64") || lower.contains("wine") ||
                            lower.contains("fatal exception") || lower.contains("fatal signal")) {
                            out.append(line).append("\n");
                        }
                    }
                }
                process.waitFor();
            }
            catch (Exception error) {
                out.append("Android logcat collection was unavailable: ").append(safeMessage(error)).append("\n");
            }

            if (out.length() == 0) out.append("No Box64/Wine or Android diagnostic output was captured.");
            lastLogs = out.toString();
            try {
                File file = new File(getFilesDir(), "wincore7/last-session.log");
                File parent = file.getParentFile();
                if (parent != null && !parent.isDirectory()) parent.mkdirs();
                try (FileOutputStream stream = new FileOutputStream(file)) {
                    stream.write(lastLogs.getBytes(StandardCharsets.UTF_8));
                }
            }
            catch (Exception error) {
                out.append("\nCould not save the combined session log: ").append(safeMessage(error));
                lastLogs = out.toString();
            }

            main.post(() -> {
                progress.setVisibility(View.GONE);
                setStatus("Session Logs collected. The captured output is shown below and can be copied or exported.");
                showSessionLogsDialog(lastLogs);
            });
        });
    }

    private void showSessionLogsDialog(String logs) {
        String display = logs == null || logs.trim().isEmpty()
            ? "No session output has been captured yet."
            : logs;
        final int displayLimit = 250000;
        if (display.length() > displayLimit) {
            display = "[Showing the latest " + displayLimit + " characters. Use Export for the complete log.]\n\n" +
                display.substring(display.length() - displayLimit);
        }

        TextView content = new TextView(this);
        content.setText(display);
        content.setTextIsSelectable(true);
        content.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        content.setTypeface(android.graphics.Typeface.MONOSPACE);
        content.setPadding(dp(12), dp(8), dp(12), dp(8));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        scroll.addView(content, new ScrollView.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        new AlertDialog.Builder(this)
            .setTitle("WinCore Session Logs")
            .setView(scroll)
            .setPositiveButton("Copy", (dialog, which) -> {
                android.content.ClipboardManager clipboard =
                    (android.content.ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
                if (clipboard != null) {
                    clipboard.setPrimaryClip(android.content.ClipData.newPlainText("WinCore Session Logs", logs));
                    setStatus("Session Logs copied to clipboard.");
                }
            })
            .setNeutralButton("Export", (dialog, which) -> exportSessionLogs())
            .setNegativeButton("Close", null)
            .show();
    }

    private void exportSessionLogs() {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("text/plain");
        intent.putExtra(Intent.EXTRA_TITLE, "WinCore-Session-Logs.txt");
        startActivityForResult(intent, REQUEST_LOG_EXPORT);
    }

    private void analyzeCrashReport() {
        String logs = lastLogs;
        if (logs.isEmpty()) {
            File file = new File(getFilesDir(), "wincore7/last-session.log");
            try { if (file.isFile()) logs = readText(file); }
            catch (Exception ignored) { }
        }
        if (logs.isEmpty()) { setStatus("no session log exists. run per-session log collection first."); return; }
        String[] patterns = {"fatal exception", "fatal signal", "sigsegv", "segmentation fault", "outofmemoryerror", "unsatisfiedlinkerror", "failed to load", "permission denied"};
        StringBuilder out = new StringBuilder("CRASH / FAILURE ANALYSIS\n");
        int hits = 0;
        for (String line : logs.split("\\R")) {
            String lower = line.toLowerCase(Locale.ROOT);
            for (String pattern : patterns) if (lower.contains(pattern)) { out.append(line).append("\n"); hits++; break; }
        }
        if (hits == 0) out.append("No known crash pattern appeared in the captured lines. This is not proof that the session was error-free.");
        else out.append("Matched ").append(hits).append(" potential diagnostic line(s). Review them before changing any container settings.");
        setStatus(out.toString());
    }

    private void toggleSafeLaunch() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        try {
            JSONObject json = new JSONObject(record.data.toString());
            JSONObject extras = json.optJSONObject("extraData");
            if (extras == null) extras = new JSONObject();
            boolean enabled = extras.optBoolean("wincoreSafeLaunch", false);
            if (!enabled) {
                extras.put("wincorePreviousBox64Preset", json.optString("box64Preset", Box64Preset.DEFAULT));
                json.put("box64Preset", Box64Preset.STABILITY);
                extras.put("wincoreSafeLaunch", true);
            }
            else {
                json.put("box64Preset", extras.optString("wincorePreviousBox64Preset", Box64Preset.DEFAULT));
                extras.remove("wincorePreviousBox64Preset");
                extras.put("wincoreSafeLaunch", false);
            }
            json.put("extraData", extras);
            saveJson(record, json);
            setStatus(enabled ? "safe launch profile disabled; previous Box64 preset restored." :
                "safe launch profile saved using the Stability Box64 preset. it applies to the next launch of this container.");
        }
        catch (Exception error) { showError("Safe launch setting failed", error); }
    }

    private void editExecutableArguments() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File desktop = new File(record.dir, ".wine/drive_c/users/xuser/Desktop");
        File[] files = desktop.listFiles((dir, name) -> name.endsWith(".desktop"));
        if (files == null || files.length == 0) { setStatus("no game shortcuts were found on this container's Desktop."); return; }
        ArrayList<Shortcut> shortcuts = new ArrayList<>();
        for (File file : files) shortcuts.add(new Shortcut(buildContainer(record), file));
        String[] names = new String[shortcuts.size()];
        for (int i = 0; i < shortcuts.size(); i++) names[i] = shortcuts.get(i).name;
        new AlertDialog.Builder(this).setTitle("choose shortcut").setItems(names, (d, index) -> {
            Shortcut shortcut = shortcuts.get(index);
            EditText args = new EditText(this);
            args.setSingleLine(false);
            args.setText(shortcut.getExtra("execArgs"));
            new AlertDialog.Builder(this).setTitle("launch arguments • " + shortcut.name).setView(args)
                .setNegativeButton("cancel", null).setPositiveButton("save", (dialog, which) -> {
                    String value = args.getText().toString().trim();
                    shortcut.putExtra("execArgs", value.isEmpty() ? null : value);
                    shortcut.saveData();
                    setStatus("launch arguments saved for " + shortcut.name + ". the original executable remains unchanged.");
                }).show();
        }).setNegativeButton("cancel", null).show();
    }

    private com.winlator.container.Container buildContainer(ContainerRecord record) {
        com.winlator.container.Container container = new com.winlator.container.Container(record.id);
        container.setRootDir(record.dir);
        try { container.loadData(new JSONObject(record.data.toString())); } catch (Exception ignored) { }
        return container;
    }

    private void manageShaderCache() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File[] candidates = {
            new File(record.dir, ".cache/mesa_shader_cache"),
            new File(record.dir, ".cache/mesa_shader_cache_db"),
            new File(record.dir, ".cache/dxvk_state_cache"),
            new File(record.dir, ".cache/vkd3d-proton"),
            new File(record.dir, ".wine/drive_c/users/xuser/Temp/shadercache")
        };
        StringBuilder out = new StringBuilder("SHADER CACHE MANAGER\n");
        long total = 0;
        for (File folder : candidates) {
            long size = directorySize(folder);
            total += size;
            out.append(folder.getName()).append(": ").append(folder.exists() ? formatBytes(size) : "not present").append("\n");
        }
        final long bytes = total;
        new AlertDialog.Builder(this).setTitle("shader cache").setMessage(out + "\nidentified total: " + formatBytes(bytes) + "\nclear only these known cache folders?")
            .setNegativeButton("cancel", null).setPositiveButton("clear cache", (d, w) -> io.execute(() -> {
                int removed = 0;
                for (File folder : candidates) if (folder.exists() && deleteRecursively(folder)) removed++;
                final int count = removed;
                main.post(() -> setStatus("removed " + count + " known shader cache folder(s). game files and Wine prefix settings were not targeted."));
            })).show();
    }

    private void showCompatibilityCatalogue() {
        setStatus("LOCAL COMPATIBILITY CATALOGUE\n\nGTA IV — inspect the selected executable, DirectX 9 clues, available RAM, graphics wrapper and captured Wine/Box64 logs.\n\nGTA San Andreas — inspect executable architecture, game folder contents, controller mapping and launch logs.\n\nDirectX 9 titles — check Vulkan availability before evaluating DXVK; WineD3D is an alternative to investigate.\n\nOpenGL titles — inspect the selected renderer and Android OpenGL ES support.\n\nThese are diagnostic starting points only. No title is declared compatible and no FPS or successful launch is guaranteed.");
    }

    private void showControllerDiagnostics() {
        StringBuilder out = new StringBuilder("CONTROLLER-FIRST NAVIGATION\n");
        int[] ids = InputDevice.getDeviceIds();
        for (int id : ids) {
            InputDevice device = InputDevice.getDevice(id);
            if (device != null) out.append(device.getName()).append(" — ").append(device.getSources()).append("\n");
        }
        if (ids.length == 0) out.append("No Android input devices are currently exposed.");
        out.append("\nWorkspace buttons are focusable and can be navigated with a hardware keyboard or controller D-pad.");
        page.requestFocus();
        setStatus(out.toString());
    }

    private void quickActions() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        String[] actions = {"open container files", "backup selected", "duplicate selected", "toggle favorite", "inspect before launch", "remove container"};
        new AlertDialog.Builder(this).setTitle(record.name).setItems(actions, (d, which) -> {
            if (which == 0) setStatus("container folder: " + record.dir.getAbsolutePath());
            else if (which == 1) requestBackup(false);
            else if (which == 2) duplicateSelectedWithProgress();
            else if (which == 3) toggleFavorite();
            else if (which == 4) preLaunchInspection();
            else if (which == 5) new AlertDialog.Builder(this).setTitle("remove container?")
                .setMessage("this permanently removes the selected container folder. create a backup first if you need its data.")
                .setNegativeButton("cancel", null).setPositiveButton("remove", (a, b) -> io.execute(() -> {
                    boolean removed = deleteRecursively(record.dir);
                    main.post(() -> { setStatus(removed ? "container removed." : "container could not be removed."); loadContainers(true); });
                })).show();
        }).show();
    }

    private void showGameLibrary() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File desktop = new File(record.dir, ".wine/drive_c/users/xuser/Desktop");
        File[] files = desktop.listFiles((dir, name) -> name.endsWith(".desktop"));
        if (files == null || files.length == 0) { setStatus("no game shortcuts were found in the selected container."); return; }
        String query = containerSearch.getText().toString().trim().toLowerCase(Locale.ROOT);
        ArrayList<File> visible = new ArrayList<>();
        for (File file : files) if (query.isEmpty() || file.getName().toLowerCase(Locale.ROOT).contains(query)) visible.add(file);
        String[] labels = new String[visible.size()];
        for (int i = 0; i < visible.size(); i++) labels[i] = visible.get(i).getName().replace(".desktop", "");
        new AlertDialog.Builder(this).setTitle("game library • " + record.name).setItems(labels, (d, which) -> {
            Shortcut shortcut = new Shortcut(buildContainer(record), visible.get(which));
            setStatus("game: " + shortcut.name + "\nexecutable clue: " + shortcut.path + "\ncategory: " + shortcut.getExtra("wincoreCategory", "uncategorized"));
        }).setNegativeButton("close", null).show();
    }

    private void editGameCategory() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File desktop = new File(record.dir, ".wine/drive_c/users/xuser/Desktop");
        File[] files = desktop.listFiles((dir, name) -> name.endsWith(".desktop"));
        if (files == null || files.length == 0) { setStatus("no game shortcuts were found."); return; }
        String[] labels = new String[files.length];
        for (int i = 0; i < files.length; i++) labels[i] = files[i].getName().replace(".desktop", "");
        new AlertDialog.Builder(this).setTitle("choose game").setItems(labels, (d, which) -> {
            File file = files[which];
            Shortcut shortcut = new Shortcut(buildContainer(record), file);
            EditText input = new EditText(this);
            input.setSingleLine(true);
            input.setHint("e.g. action, racing, strategy");
            input.setText(shortcut.getExtra("wincoreCategory"));
            new AlertDialog.Builder(this).setTitle("game category").setView(input).setNegativeButton("cancel", null)
                .setPositiveButton("save", (a, b) -> {
                    shortcut.putExtra("wincoreCategory", input.getText().toString().trim());
                    shortcut.saveData();
                    setStatus("category saved for " + shortcut.name + ".");
                }).show();
        }).show();
    }

    private void chooseArtworkShortcut() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File desktop = new File(record.dir, ".wine/drive_c/users/xuser/Desktop");
        File[] files = desktop.listFiles((dir, name) -> name.endsWith(".desktop"));
        if (files == null || files.length == 0) { setStatus("no game shortcuts were found."); return; }
        String[] labels = new String[files.length];
        for (int i = 0; i < files.length; i++) labels[i] = files[i].getName().replace(".desktop", "");
        new AlertDialog.Builder(this).setTitle("choose game for artwork").setItems(labels, (d, which) -> {
            pendingArtworkShortcut = new Shortcut(buildContainer(record), files[which]);
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("image/*");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
            startActivityForResult(intent, REQUEST_ARTWORK);
        }).show();
    }

    private void setDesktopIcon(File desktopFile, String iconName) throws IOException {
        List<String> lines = Files.readAllLines(desktopFile.toPath(), StandardCharsets.UTF_8);
        StringBuilder out = new StringBuilder();
        boolean found = false;
        for (String line : lines) {
            if (line.startsWith("Icon=")) {
                out.append("Icon=").append(iconName);
                found = true;
            }
            else out.append(line);
            out.append("\n");
        }
        if (!found) out.append("Icon=").append(iconName).append("\n");
        AtomicFile atomic = new AtomicFile(desktopFile);
        FileOutputStream stream = null;
        try {
            stream = atomic.startWrite();
            stream.write(out.toString().getBytes(StandardCharsets.UTF_8));
            atomic.finishWrite(stream);
        }
        catch (IOException error) {
            if (stream != null) atomic.failWrite(stream);
            throw error;
        }
    }

    private void showRecentlyPlayedGames() {
        try {
            org.json.JSONArray recent = new org.json.JSONArray(preferences.getString("recent_games", "[]"));
            StringBuilder out = new StringBuilder("RECENTLY PLAYED GAMES\n");
            for (int i = recent.length() - 1; i >= 0; i--) {
                JSONObject item = recent.getJSONObject(i);
                out.append(item.optString("name")).append(" — container ").append(item.optInt("containerId"))
                    .append(" — ").append(new java.util.Date(item.optLong("time"))).append("\n");
            }
            if (recent.length() == 0) out.append("No game launches have been recorded yet. WinCore records a game when it is launched from its shortcut list.");
            setStatus(out.toString());
        }
        catch (Exception error) { setStatus("recent game history is unreadable: " + safeMessage(error)); }
    }

    private void showContextualErrors() {
        if (scanErrors.isEmpty()) setStatus("no current container scan errors are recorded. open a specific diagnostic action to receive a context-specific explanation.");
        else setStatus("CONTAINER ERRORS\n" + join(scanErrors) + "\nUnreadable folders are skipped individually so they do not stop the full list scan.");
    }

    private void toggleAccessibility() {
        largeText = !largeText;
        preferences.edit().putBoolean("large_text", largeText).apply();
        setStatus("large workspace text " + (largeText ? "enabled" : "disabled") + ". reopening the workspace applies the text scale to all controls.");
        recreate();
    }

    private void showTabletLayoutStatus() {
        int width = (int)(getResources().getDisplayMetrics().widthPixels / getResources().getDisplayMetrics().density);
        setStatus("TABLET LAYOUT\navailable width: " + width + " dp\ncontent width: " + (width >= 800 ? "760 dp maximum, centered" : "full available width with side padding") + "\nThe same controls remain available in portrait and landscape.");
    }

    private void toggleAutomaticBackups() {
        boolean value = !preferences.getBoolean("automatic_backups", false);
        preferences.edit().putBoolean("automatic_backups", value).apply();
        setStatus("automatic configuration snapshots " + (value ? "enabled" : "disabled") + ". snapshots are taken when the workspace is opened and before workspace-managed config changes.");
    }

    private void migrateContainerConfigurations() {
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        io.execute(() -> {
            int migrated = 0, unreadable = 0;
            for (ContainerRecord record : new ArrayList<>(containers)) {
                try {
                    JSONObject json = new JSONObject(readText(record.config));
                    JSONObject extra = json.optJSONObject("extraData");
                    if (extra == null) extra = new JSONObject();
                    if (!extra.has("wincoreConfigSchema")) extra.put("wincoreConfigSchema", 1);
                    json.put("extraData", extra);
                    createSnapshot(record, "before-migration");
                    writeAtomicNoSnapshot(record.config, json.toString());
                    migrated++;
                }
                catch (Exception error) { unreadable++; scanErrors.add(record.dir.getName() + ": migration: " + safeMessage(error)); }
            }
            final int done = migrated, skipped = unreadable;
            main.post(() -> { progress.setVisibility(View.GONE); setStatus("migration assistant finished: " + done + " config(s) normalized; " + skipped + " skipped. original values were retained and snapshots were made before changes."); loadContainers(true); });
        });
    }

    private void cleanupStorage() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        File cache = new File(record.dir, ".cache");
        long size = directorySize(cache);
        new AlertDialog.Builder(this).setTitle("storage cleanup assistant")
            .setMessage("known per-container cache folder size: " + formatBytes(size) + "\nremove .cache only? Wine prefix and game data are not targeted.")
            .setNegativeButton("cancel", null).setPositiveButton("clean", (d, w) -> io.execute(() -> {
                boolean result = !cache.exists() || deleteRecursively(cache);
                main.post(() -> setStatus(result ? "selected container cache folder cleaned." : "cache cleanup could not remove every file."));
            })).show();
    }

    private void repairContainerPermissions() {
        ContainerRecord record = requireSelected();
        if (record == null) { setStatus("select a container first."); return; }
        io.execute(() -> {
            int touched = repairPermissions(record.dir);
            main.post(() -> setStatus("permission repair checked " + touched + " directory/file entries inside the selected app-private container. no external storage permissions or root access were requested."));
        });
    }

    private int repairPermissions(File file) {
        if (file == null || !file.exists() || Files.isSymbolicLink(file.toPath())) return 0;
        int count = 1;
        if (file.isDirectory()) {
            file.setReadable(true, false);
            file.setWritable(true, false);
            File[] children = file.listFiles();
            if (children != null) for (File child : children) count += repairPermissions(child);
        }
        else {
            file.setReadable(true, false);
            file.setWritable(true, false);
        }
        return count;
    }

    private void checkUpstreamCompatibility() {
        StringBuilder out = new StringBuilder("UPSTREAM / RUNTIME COMPATIBILITY CHECK\n");
        out.append("WinCore package: ").append(getPackageName()).append("\n");
        out.append("WinCore version: ").append(getPackageManagerVersion()).append("\n");
        out.append("rootfs marker: ").append(rootFS.getRFSVersionFile().isFile() ? "present" : "missing").append("\n");
        out.append("rootfs valid: ").append(rootFS.isValid()).append("\n");
        out.append("wine binary: ").append(new File(rootFS.getRootDir(), "opt/wine/bin/wine").isFile()).append("\n");
        File box64UsrBin = new File(rootFS.getRootDir(), "usr/bin/box64");
        File box64UsrLocalBin = new File(rootFS.getRootDir(), "usr/local/bin/box64");
        boolean box64Found = box64UsrBin.isFile() || box64UsrLocalBin.isFile();
        out.append("box64 binary: ").append(box64Found).append("\n");
        out.append("box64 path: ").append(box64UsrBin.isFile() ? box64UsrBin.getAbsolutePath() :
            box64UsrLocalBin.isFile() ? box64UsrLocalBin.getAbsolutePath() : "not found in usr/bin or usr/local/bin").append("\n");
        out.append("source base pin: 30aafbdb9eea47b92669201621e03cd2cf04540d\n");
        out.append("This checks expected local runtime files against the pinned Winlator source base; it does not contact or modify upstream servers.");
        setStatus(out.toString());
    }

    private String getPackageManagerVersion() {
        try { return getPackageManager().getPackageInfo(getPackageName(), 0).versionName; }
        catch (Exception ignored) { return "unknown"; }
    }

    private void runContainerTests() {
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        io.execute(() -> {
            int passed = 0, failed = 0;
            StringBuilder report = new StringBuilder("AUTOMATED CONTAINER TESTS\n");
            if (homeDir.isDirectory()) passed++; else { failed++; report.append("FAIL: container home directory missing\n"); }
            if (rootFS.isValid()) passed++; else { failed++; report.append("FAIL: root filesystem marker is invalid\n"); }
            HashSet<Integer> ids = new HashSet<>();
            for (ContainerRecord record : containers) {
                if (!ids.add(record.id)) { failed++; report.append("FAIL: duplicate container id ").append(record.id).append("\n"); }
                try { new JSONObject(readText(record.config)); passed++; }
                catch (Exception error) { failed++; report.append("FAIL: ").append(record.name).append(": ").append(safeMessage(error)).append("\n"); }
                if (record.dir.isDirectory() && record.config.isFile()) passed++; else { failed++; report.append("FAIL: missing container directory or config for ").append(record.name).append("\n"); }
            }
            File probe = new File(getFilesDir(), "wincore7/test-probe.tmp");
            try {
                probe.getParentFile().mkdirs();
                writeAtomicNoSnapshot(probe, "WinCore-7.0.0-test");
                if ("WinCore-7.0.0-test".equals(readText(probe))) passed++; else failed++;
            }
            catch (Exception error) { failed++; report.append("FAIL: atomic-write probe: ").append(safeMessage(error)).append("\n"); }
            probe.delete();
            report.append("Passed: ").append(passed).append("\nFailed: ").append(failed).append("\nTests validate local files and app storage; they do not launch Windows games.");
            final String result = report.toString();
            main.post(() -> { progress.setVisibility(View.GONE); setStatus(result); });
        });
    }

    private void runUiTests() {
        int[] values = {0,0};
        inspectViews(page, values);
        setStatus("AUTOMATED UI ACCESSIBILITY CHECK\nViews inspected: " + values[0] + "\nClickable controls with missing descriptions or focus support: " + values[1] +
            "\nThis checks the workspace view tree at runtime. CI compilation and package checks remain separate; it is not an emulator-driven Espresso test.");
    }

    private void inspectViews(View view, int[] totals) {
        if (view == null) return;
        totals[0]++;
        if (view.isClickable() && (!view.isFocusable() || view.getContentDescription() == null)) totals[1]++;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup)view;
            for (int i = 0; i < group.getChildCount(); i++) inspectViews(group.getChildAt(i), totals);
        }
    }

    private void runApkRegressionCheck() {
        try {
            PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
            File apk = new File(getApplicationInfo().sourceDir);
            String result = "APK REGRESSION CHECK\npackage: " + info.packageName + "\nversion: " + info.versionName +
                "\nversion code: " + info.versionCode + "\ninstalled APK: " + apk.isFile() + "\nAPK size: " + (apk.isFile() ? formatBytes(apk.length()) : "not available") +
                "\nThe CI workflow additionally verifies ZIP integrity, ARM64 libraries and package metadata before publishing the artifact.";
            setStatus(result);
        }
        catch (Exception error) { showError("APK check failed", error); }
    }

    private void exportBuildDiagnostics() {
        StringBuilder report = new StringBuilder("WINCORE BUILD / DEVICE DIAGNOSTICS\n");
        report.append("package: ").append(getPackageName()).append("\nversion: ").append(getPackageManagerVersion()).append("\n");
        report.append("android: ").append(android.os.Build.VERSION.RELEASE).append(" (API ").append(android.os.Build.VERSION.SDK_INT).append(")\n");
        report.append("device: ").append(android.os.Build.MANUFACTURER).append(" ").append(android.os.Build.MODEL).append("\n");
        report.append("rootfs valid: ").append(rootFS.isValid()).append("\ncontainers indexed: ").append(containers.size()).append("\n");
        report.append("scan errors: ").append(scanErrors.size()).append("\n").append(join(scanErrors)).append("\n");
        report.append("last log captured lines: ").append(lastLogs.isEmpty() ? 0 : lastLogs.split("\\R").length).append("\n");
        lastLogs = report.toString() + "\n" + lastLogs;
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("text/plain");
        intent.putExtra(Intent.EXTRA_TITLE, "WinCore-7.0.0-build-diagnostics.txt");
        startActivityForResult(intent, REQUEST_LOG_EXPORT);
    }

    private void chooseExeForArguments() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(intent, REQUEST_ARTWORK);
    }

    private void saveJson(ContainerRecord record, JSONObject json) {
        final String updated = json.toString();
        progress.setVisibility(View.VISIBLE);
        progress.setIndeterminate(true);
        io.execute(() -> {
            try {
                if (preferences.getBoolean("automatic_backups", false)) createSnapshot(record, "before-change");
                writeAtomicNoSnapshot(record.config, updated);
                main.post(() -> {
                    progress.setVisibility(View.GONE);
                    loadContainers(false);
                });
            }
            catch (Exception error) {
                main.post(() -> {
                    progress.setVisibility(View.GONE);
                    showError("Configuration update failed", error);
                });
            }
        });
    }

    private void toggleSafeLaunchLegacy() { toggleSafeLaunch(); }

    private void showError(String title, Exception error) {
        String message = safeMessage(error);
        setStatus(title + ": " + message);
        new AlertDialog.Builder(this).setTitle(title).setMessage(message).setPositiveButton("ok", null).show();
    }

    private String safeMessage(Throwable error) {
        String value = error.getMessage();
        if (value == null || value.trim().isEmpty()) value = error.getClass().getSimpleName();
        return value;
    }

    private String readText(File file) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (InputStream in = new BufferedInputStream(new FileInputStream(file))) {
            byte[] buffer = new byte[16 * 1024];
            int count;
            while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
        }
        return out.toString("UTF-8");
    }

    private void showError(String title, Throwable error) {
        showError(title, error instanceof Exception ? (Exception)error : new Exception(error));
    }

    private boolean deleteRecursively(File file) {
        if (file == null || !file.exists()) return true;
        if (Files.isSymbolicLink(file.toPath())) return file.delete();
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) for (File child : children) if (!deleteRecursively(child)) return false;
        }
        return file.delete();
    }

    private String join(List<String> values) {
        StringBuilder out = new StringBuilder();
        for (String value : values) out.append("• ").append(value).append("\n");
        return out.toString();
    }
}
