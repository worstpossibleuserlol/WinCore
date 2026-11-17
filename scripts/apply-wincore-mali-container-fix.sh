#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_DIR="$1"
if [[ -z "$UPSTREAM_DIR" ]]; then UPSTREAM_DIR="upstream"; fi
APP_MODULE="$UPSTREAM_DIR/app/app"
if [[ ! -f "$APP_MODULE/build.gradle" ]]; then
  echo "WinCore upstream Android module was not found: $APP_MODULE" >&2
  exit 1
fi

python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])

def required(relative):
    path = app / relative
    if not path.is_file():
        raise SystemExit(f"Required source file is missing: {path}")
    return path

def add_import(source, anchor, import_line, label):
    if import_line in source:
        return source
    if source.count(anchor) != 1:
        raise SystemExit(f"{label}: import anchor was not unique")
    return source.replace(anchor, anchor + import_line, 1)

# 1. Prevent an EGL probe failure on Mali from blocking the UI forever.
gpu_path = required("src/main/java/com/winlator/core/GPUHelper.java")
gpu = gpu_path.read_text(encoding="utf-8")
gpu = add_import(
    gpu,
    "import java.util.regex.Pattern;\n",
    "import java.util.concurrent.CountDownLatch;\nimport java.util.concurrent.TimeUnit;\n",
    "GPUHelper"
)
gpu = add_import(
    gpu,
    "import javax.microedition.khronos.egl.EGLDisplay;\n",
    "import javax.microedition.khronos.egl.EGLSurface;\n",
    "GPUHelper EGL surface"
)
new_probe = r'''    private static ArrayMap<String, String> loadGPUInformation(Context context) {
        final ArrayMap<String, String> gpuInfo = new ArrayMap<>();
        gpuInfo.put("renderer", "");
        gpuInfo.put("vendor", "");
        gpuInfo.put("version", "");

        final String[] values = new String[]{"", "", ""};
        final CountDownLatch completed = new CountDownLatch(1);

        Thread probe = new Thread(() -> {
            EGL10 egl = null;
            EGLDisplay display = EGL10.EGL_NO_DISPLAY;
            EGLSurface surface = EGL10.EGL_NO_SURFACE;
            EGLContext eglContext = EGL10.EGL_NO_CONTEXT;
            boolean initialized = false;

            try {
                egl = (EGL10)EGLContext.getEGL();
                display = egl.eglGetDisplay(EGL10.EGL_DEFAULT_DISPLAY);
                if (display == null || display == EGL10.EGL_NO_DISPLAY) {
                    throw new IllegalStateException("EGL display is unavailable");
                }

                int[] eglVersion = new int[2];
                if (!egl.eglInitialize(display, eglVersion)) {
                    throw new IllegalStateException(
                        "EGL initialization failed: 0x" + Integer.toHexString(egl.eglGetError())
                    );
                }
                initialized = true;

                int[][] configCandidates = new int[][]{
                    {
                        EGL10.EGL_SURFACE_TYPE, EGL10.EGL_PBUFFER_BIT,
                        EGL10.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                        EGL10.EGL_RED_SIZE, 8,
                        EGL10.EGL_GREEN_SIZE, 8,
                        EGL10.EGL_BLUE_SIZE, 8,
                        EGL10.EGL_ALPHA_SIZE, 8,
                        EGL10.EGL_NONE
                    },
                    {
                        EGL10.EGL_SURFACE_TYPE, EGL10.EGL_PBUFFER_BIT,
                        EGL10.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                        EGL10.EGL_RED_SIZE, 8,
                        EGL10.EGL_GREEN_SIZE, 8,
                        EGL10.EGL_BLUE_SIZE, 8,
                        EGL10.EGL_ALPHA_SIZE, 0,
                        EGL10.EGL_NONE
                    }
                };

                EGLConfig selectedConfig = null;
                for (int[] attributes : configCandidates) {
                    EGLConfig[] configs = new EGLConfig[1];
                    int[] count = new int[1];
                    if (egl.eglChooseConfig(display, attributes, configs, 1, count) &&
                        count[0] > 0 && configs[0] != null) {
                        selectedConfig = configs[0];
                        break;
                    }
                }
                if (selectedConfig == null) {
                    throw new IllegalStateException(
                        "No compatible EGL pbuffer config: 0x" + Integer.toHexString(egl.eglGetError())
                    );
                }

                int[] contextAttributes = {
                    EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL10.EGL_NONE
                };
                eglContext = egl.eglCreateContext(
                    display, selectedConfig, EGL10.EGL_NO_CONTEXT, contextAttributes
                );
                if (eglContext == null || eglContext == EGL10.EGL_NO_CONTEXT) {
                    throw new IllegalStateException(
                        "EGL context creation failed: 0x" + Integer.toHexString(egl.eglGetError())
                    );
                }

                int[] surfaceAttributes = {
                    EGL10.EGL_WIDTH, 1, EGL10.EGL_HEIGHT, 1, EGL10.EGL_NONE
                };
                surface = egl.eglCreatePbufferSurface(display, selectedConfig, surfaceAttributes);
                if (surface == null || surface == EGL10.EGL_NO_SURFACE) {
                    throw new IllegalStateException(
                        "EGL pbuffer creation failed: 0x" + Integer.toHexString(egl.eglGetError())
                    );
                }

                if (!egl.eglMakeCurrent(display, surface, surface, eglContext)) {
                    throw new IllegalStateException(
                        "EGL make-current failed: 0x" + Integer.toHexString(egl.eglGetError())
                    );
                }

                GL10 gl = (GL10)eglContext.getGL();
                values[0] = Objects.toString(gl.glGetString(GL10.GL_RENDERER), "");
                values[1] = Objects.toString(gl.glGetString(GL10.GL_VENDOR), "");
                values[2] = Objects.toString(gl.glGetString(GL10.GL_VERSION), "");

                PreferenceManager.getDefaultSharedPreferences(context).edit()
                    .putString("gpu_renderer", values[0])
                    .putString("gpu_vendor", values[1])
                    .putString("gpu_version", values[2])
                    .apply();
            }
            catch (Throwable error) {
                android.util.Log.w("WinCore/GPUHelper", "GPU information probe failed", error);
            }
            finally {
                if (egl != null && display != null && display != EGL10.EGL_NO_DISPLAY) {
                    try {
                        egl.eglMakeCurrent(
                            display,
                            EGL10.EGL_NO_SURFACE,
                            EGL10.EGL_NO_SURFACE,
                            EGL10.EGL_NO_CONTEXT
                        );
                    }
                    catch (Throwable ignored) {}

                    if (surface != null && surface != EGL10.EGL_NO_SURFACE) {
                        try { egl.eglDestroySurface(display, surface); }
                        catch (Throwable ignored) {}
                    }
                    if (eglContext != null && eglContext != EGL10.EGL_NO_CONTEXT) {
                        try { egl.eglDestroyContext(display, eglContext); }
                        catch (Throwable ignored) {}
                    }
                    if (initialized) {
                        try { egl.eglTerminate(display); }
                        catch (Throwable ignored) {}
                    }
                }
                completed.countDown();
            }
        }, "WinCore-GPU-Probe");

        probe.setDaemon(true);
        probe.start();

        try {
            if (!completed.await(1200, TimeUnit.MILLISECONDS)) {
                android.util.Log.w(
                    "WinCore/GPUHelper",
                    "GPU probe timed out; continuing with a safe generic driver profile"
                );
                return gpuInfo;
            }
        }
        catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            android.util.Log.w("WinCore/GPUHelper", "GPU probe wait was interrupted", error);
            return gpuInfo;
        }

        gpuInfo.put("renderer", values[0]);
        gpuInfo.put("vendor", values[1]);
        gpuInfo.put("version", values[2]);
        return gpuInfo;
    }

    public static String glGetRenderer'''
pattern = re.compile(
    r"    private static ArrayMap<String, String> loadGPUInformation\(Context context\) \{.*?\n    \}\n\n    public static String glGetRenderer",
    re.S
)
gpu, count = pattern.subn(new_probe, gpu, count=1)
if count != 1:
    raise SystemExit("GPUHelper: could not replace the unbounded EGL wait")
gpu_path.write_text(gpu, encoding="utf-8")

# 2. Add device-aware Mali compatibility: Vortek, WineD3D's Vulkan renderer,
#    Mali-safe GL overrides, and a user-controlled Auto/Manual switch.
mali_path = app / "src/main/java/com/winlator/WinCoreMaliCompatibility.java"
mali_java = r'''package com.winlator;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;

import androidx.preference.PreferenceManager;

import com.winlator.container.Container;
import com.winlator.container.DXWrappers;
import com.winlator.container.GraphicsDrivers;
import com.winlator.core.EnvVars;
import com.winlator.core.GPUHelper;
import com.winlator.core.KeyValueSet;

import java.util.Locale;

public final class WinCoreMaliCompatibility {
    public static final String AUTO_PROFILE_KEY = "wincore_mali_auto_compatibility";

    private WinCoreMaliCompatibility() {}

    public static boolean isAutomaticProfileEnabled(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        return preferences.getBoolean(AUTO_PROFILE_KEY, true);
    }

    public static boolean isMali(Context context) {
        StringBuilder identity = new StringBuilder();
        append(identity, Build.HARDWARE);
        append(identity, Build.BOARD);
        append(identity, Build.DEVICE);
        append(identity, Build.PRODUCT);
        append(identity, Build.MANUFACTURER);
        append(identity, Build.MODEL);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) append(identity, Build.SOC_MODEL);

        String value = identity.toString().toLowerCase(Locale.US);
        if (value.contains("mali") || value.contains("dimensity 7100") ||
            value.contains("mt6878") || value.contains("x6887")) {
            return true;
        }

        // Do a single bounded EGL probe only when the Android build identifiers
        // do not already identify the GPU family. GPUHelper caches both fields.
        try {
            String renderer = GPUHelper.glGetRenderer(context);
            String vendor = PreferenceManager.getDefaultSharedPreferences(context)
                .getString("gpu_vendor", "");
            return (renderer + " " + vendor).toLowerCase(Locale.US).contains("mali");
        }
        catch (RuntimeException | LinkageError error) {
            android.util.Log.w("WinCore/Mali", "Could not read EGL GPU identity", error);
            return false;
        }
    }

    private static void append(StringBuilder target, String value) {
        if (value == null || value.trim().isEmpty()) return;
        if (target.length() > 0) target.append(' ');
        target.append(value.trim());
    }

    public static boolean isVirGLFallbackEnabled(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        return preferences.getBoolean("wincore_mali_use_virgl_fallback", false);
    }

    public static String getDefaultGraphicsDriver(Context context) {
        if (isAutomaticProfileEnabled(context) && isMali(context)) {
            String openGL = isVirGLFallbackEnabled(context)
                ? GraphicsDrivers.VIRGL
                : GraphicsDrivers.DEFAULT_OPENGL_DRIVER;
            return GraphicsDrivers.VORTEK + "," + openGL;
        }
        return GraphicsDrivers.getDefaultDriver(context);
    }

    public static String getDefaultDXWrapper(Context context) {
        if (isAutomaticProfileEnabled(context) && isMali(context)) {
            return DXWrappers.WINED3D;
        }
        return Container.DEFAULT_DXWRAPPER;
    }

    public static String[] resolveGraphicsDriver(Context context, String[] selected) {
        if (!isAutomaticProfileEnabled(context) || !isMali(context)) return selected;
        if (selected == null || selected.length < 2) {
            return new String[]{GraphicsDrivers.VORTEK, GraphicsDrivers.DEFAULT_OPENGL_DRIVER};
        }

        String[] resolved = selected.clone();
        if (GraphicsDrivers.TURNIP.equals(resolved[0]) ||
            !GraphicsDrivers.isVulkanDriver(resolved[0])) {
            android.util.Log.w(
                "WinCore/Mali",
                "Replacing the Adreno-specific/invalid Vulkan renderer with Vortek for Mali"
            );
            resolved[0] = GraphicsDrivers.VORTEK;
        }
        if (isVirGLFallbackEnabled(context)) {
            resolved[1] = GraphicsDrivers.VIRGL;
        }
        else if (!GraphicsDrivers.isOpenGLDriver(resolved[1])) {
            resolved[1] = GraphicsDrivers.DEFAULT_OPENGL_DRIVER;
        }
        return resolved;
    }

    public static String resolveDXWrapper(Context context, String selected) {
        if (isAutomaticProfileEnabled(context) && isMali(context) &&
            DXWrappers.DXVK.equals(selected)) {
            android.util.Log.i(
                "WinCore/Mali",
                "Using WineD3D Vulkan renderer as the automatic Mali compatibility path"
            );
            return DXWrappers.WINED3D;
        }
        return selected;
    }

    public static void configureWineD3D(
        Context context,
        String[] graphicsDriver,
        String dxwrapper,
        KeyValueSet[] config
    ) {
        if (!isAutomaticProfileEnabled(context) || !isMali(context) ||
            !DXWrappers.WINED3D.equals(dxwrapper) || config == null ||
            config.length == 0 || config[0] == null) return;

        boolean useVirGL = isVirGLFallbackEnabled(context) ||
            (graphicsDriver != null && graphicsDriver.length > 1 &&
                GraphicsDrivers.VIRGL.equals(graphicsDriver[1]));
        String renderer = useVirGL ? "gl" : "vulkan";
        config[0].put("renderer", renderer);
    }

    public static void applyEnvironment(Context context, String[] graphicsDriver, String dxwrapper, EnvVars envVars) {
        if (!isAutomaticProfileEnabled(context) || !isMali(context) || envVars == null) return;

        boolean useVirGL = isVirGLFallbackEnabled(context) ||
            (graphicsDriver != null && graphicsDriver.length > 1 &&
                GraphicsDrivers.VIRGL.equals(graphicsDriver[1]));

        // Community Mali profiles report fewer stability problems with threaded
        // GL disabled and Box64's conservative memory/signal options enabled.
        envVars.put("mesa_glthread", "false");
        if (!envVars.has("BOX64_MMAP32")) envVars.put("BOX64_MMAP32", "1");
        if (!envVars.has("BOX64_SAFEFLAGS")) envVars.put("BOX64_SAFEFLAGS", "2");

        if (DXWrappers.WINED3D.equals(dxwrapper)) {
            if (!useVirGL) {
                envVars.put("MESA_GL_VERSION_OVERRIDE", "3.2COMPAT");
            }
            envVars.put("MESA_GLSL_VERSION_OVERRIDE", "150");
        }
    }
}
'''
mali_path.parent.mkdir(parents=True, exist_ok=True)
if not mali_path.exists():
    mali_path.write_text(mali_java, encoding="utf-8")
else:
    existing = mali_path.read_text(encoding="utf-8")
    if "public final class WinCoreMaliCompatibility" not in existing:
        raise SystemExit("Refusing to overwrite an unrelated WinCoreMaliCompatibility.java")

layout_path = required("src/main/res/layout/settings_fragment.xml")
layout = layout_path.read_text(encoding="utf-8")
if 'android:id="@+id/CBWinCoreMaliCompatibility"' not in layout:
    marker = 'android:id="@+id/CBWinCoreLiveMonitor"'
    position = layout.find(marker)
    if position < 0:
        raise SystemExit("Settings layout is missing the WinCore live-monitor checkbox")
    end = layout.find("/>", position)
    if end < 0:
        raise SystemExit("Settings layout live-monitor checkbox is malformed")
    end += 2
    layout = layout[:end] + """

                    <CheckBox
                        android:id="@+id/CBWinCoreMaliCompatibility"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="@string/wincore_mali_automatic_compatibility" />

                    <CheckBox
                        android:id="@+id/CBWinCoreMaliVirGLFallback"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="@string/wincore_mali_virgl_fallback" />""" + layout[end:]
layout_path.write_text(layout, encoding="utf-8")

strings_path = required("src/main/res/values/strings.xml")
strings = strings_path.read_text(encoding="utf-8")
if 'name="wincore_mali_automatic_compatibility"' not in strings:
    strings = strings.replace(
        "</resources>",
        '    <string name="wincore_mali_automatic_compatibility">Automatic Mali graphics compatibility (Vortek + WineD3D)</string>\n' +
        '    <string name="wincore_mali_virgl_fallback">Use VirGL fallback for Mali (older DirectX / OpenGL games)</string>\n</resources>',
        1
    )
strings_path.write_text(strings, encoding="utf-8")

settings_path = required("src/main/java/com/winlator/SettingsFragment.java")
settings = settings_path.read_text(encoding="utf-8")
settings = add_import(
    settings,
    "import com.winlator.box64.Box64PresetManager;\n",
    "import com.winlator.WinCoreMaliCompatibility;\n",
    "SettingsFragment Mali compatibility"
)
mali_binding_anchor = '        CheckBox monitor = view.findViewById(R.id.CBWinCoreLiveMonitor);\n'
if "CBWinCoreMaliCompatibility" not in settings:
    if settings.count(mali_binding_anchor) != 1:
        raise SystemExit("SettingsFragment: live-monitor binding anchor changed")
    settings = settings.replace(
        mali_binding_anchor,
        mali_binding_anchor +
        '        CheckBox maliCompatibility = view.findViewById(R.id.CBWinCoreMaliCompatibility);\n'
        '        maliCompatibility.setChecked(preferences.getBoolean(WinCoreMaliCompatibility.AUTO_PROFILE_KEY, true));\n'
        '        CheckBox maliVirglFallback = view.findViewById(R.id.CBWinCoreMaliVirGLFallback);\n'
        '        maliVirglFallback.setChecked(preferences.getBoolean("wincore_mali_use_virgl_fallback", false));\n',
        1
    )
mali_save_anchor = '            editor.putBoolean("wincore_live_monitor", ((CheckBox)view.findViewById(R.id.CBWinCoreLiveMonitor)).isChecked());\n'
if 'editor.putBoolean(WinCoreMaliCompatibility.AUTO_PROFILE_KEY' not in settings:
    if settings.count(mali_save_anchor) != 1:
        raise SystemExit("SettingsFragment: live-monitor save anchor changed")
    settings = settings.replace(
        mali_save_anchor,
        mali_save_anchor +
        '            editor.putBoolean(WinCoreMaliCompatibility.AUTO_PROFILE_KEY, ((CheckBox)view.findViewById(R.id.CBWinCoreMaliCompatibility)).isChecked());\n'
        '            editor.putBoolean("wincore_mali_use_virgl_fallback", ((CheckBox)view.findViewById(R.id.CBWinCoreMaliVirGLFallback)).isChecked());\n',
        1
    )
settings_path.write_text(settings, encoding="utf-8")

detail_path = required("src/main/java/com/winlator/ContainerDetailFragment.java")
detail = detail_path.read_text(encoding="utf-8")
detail = add_import(
    detail,
    "import com.winlator.container.Container;\n",
    "import com.winlator.WinCoreMaliCompatibility;\n",
    "ContainerDetailFragment Mali compatibility"
)
old_graphics_default = 'String selectedGraphicsDriver = isEditMode() ? container.getGraphicsDriver() : GraphicsDrivers.getDefaultDriver(context);'
new_graphics_default = 'String selectedGraphicsDriver = isEditMode() ? container.getGraphicsDriver() : WinCoreMaliCompatibility.getDefaultGraphicsDriver(context);'
if old_graphics_default in detail:
    detail = detail.replace(old_graphics_default, new_graphics_default, 1)
elif new_graphics_default not in detail:
    raise SystemExit("ContainerDetailFragment: graphics-driver default anchor changed")
old_dx_default = 'String selectedDXWrapper = isEditMode() ? container.getDXWrapper() : Container.DEFAULT_DXWRAPPER;'
new_dx_default = 'String selectedDXWrapper = isEditMode() ? container.getDXWrapper() : WinCoreMaliCompatibility.getDefaultDXWrapper(context);'
if old_dx_default in detail:
    detail = detail.replace(old_dx_default, new_dx_default, 1)
elif new_dx_default not in detail:
    raise SystemExit("ContainerDetailFragment: DX-wrapper default anchor changed")
detail_path.write_text(detail, encoding="utf-8")

# 3. Surface container creation failures and retain their actual cause.
manager_path = required("src/main/java/com/winlator/container/ContainerManager.java")
manager = manager_path.read_text(encoding="utf-8")
if "private volatile String lastOperationError" not in manager:
    anchor = "    private final ArrayList<String> loadWarnings = new ArrayList<>();\n"
    if manager.count(anchor) != 1:
        raise SystemExit("ContainerManager: load-warning field anchor changed")
    manager = manager.replace(
        anchor,
        anchor + '    private volatile String lastOperationError = "";\n',
        1
    )

getter_anchor = """    public ArrayList<String> getLoadWarnings() {
        return new ArrayList<>(loadWarnings);
    }
"""
getter_addition = getter_anchor + """
    public String getLastOperationError() {
        return lastOperationError;
    }
"""
if "public String getLastOperationError()" not in manager:
    if manager.count(getter_anchor) != 1:
        raise SystemExit("ContainerManager: load-warning getter anchor changed")
    manager = manager.replace(getter_anchor, getter_addition, 1)

old_async = """        IO_EXECUTOR.execute(() -> {
            Container container = null;
            try { container = createContainer(data); }
            catch (Exception error) { android.util.Log.e("WinCore", "Container creation failed", error); }
            final Container result = container;
            MAIN_HANDLER.post(() -> callback.call(result));
        });"""
new_async = """        lastOperationError = "";
        IO_EXECUTOR.execute(() -> {
            Container container = null;
            try {
                container = createContainer(data);
            }
            catch (Exception error) {
                lastOperationError = error.getMessage() != null
                    ? error.getMessage()
                    : error.getClass().getSimpleName();
                android.util.Log.e("WinCore", "Container creation failed", error);
            }
            if (container == null && lastOperationError.isEmpty()) {
                lastOperationError = "Container creation returned no result";
            }
            final Container result = container;
            MAIN_HANDLER.post(() -> callback.call(result));
        });"""
if old_async in manager:
    manager = manager.replace(old_async, new_async, 1)
elif "lastOperationError = error.getMessage()" not in manager:
    raise SystemExit("ContainerManager: asynchronous container creation anchor changed")

create_start = manager.find("    private Container createContainer(JSONObject data) {")
create_end = manager.find("    private void duplicateContainer(", create_start)
if create_start < 0 or create_end < 0:
    raise SystemExit("ContainerManager: createContainer method was not found")
create_block = manager[create_start:create_end]
create_block = create_block.replace(
    "            if (!containerDir.mkdirs()) return null;",
    """            if (!containerDir.mkdirs()) {
                throw new IllegalStateException(
                    "Could not create container directory: " + containerDir.getAbsolutePath()
                );
            }"""
)
create_block = create_block.replace(
    """            if (!extractContainerPatternFile(container.getWineVersion(), containerDir)) {
                FileUtils.delete(containerDir);
                return null;
            }""",
    """            if (!extractContainerPatternFile(container.getWineVersion(), containerDir)) {
                FileUtils.delete(containerDir);
                throw new IllegalStateException(
                    "Could not extract container_pattern.tzst. Check that the RootFS installation completed."
                );
            }"""
)
create_block = create_block.replace(
    "        catch (JSONException e) {}",
    '        catch (JSONException error) { throw new IllegalStateException("Container metadata is invalid", error); }'
)
create_block = create_block.replace(
    '        catch (JSONException error) { throw new IllegalStateException("Container metadata is invalid", error); }\n        return null;',
    '        catch (JSONException error) { throw new IllegalStateException("Container metadata is invalid", error); }'
)
manager = manager[:create_start] + create_block + manager[create_end:]
manager_path.write_text(manager, encoding="utf-8")

# Load only the selected container at launch, and stop cleanly if its directory
# or configuration is missing/corrupt.
display_path = required("src/main/java/com/winlator/XServerDisplayActivity.java")
display = display_path.read_text(encoding="utf-8")
display = add_import(
    display,
    "import android.widget.Spinner;\n",
    "import android.os.Handler;\nimport android.os.Looper;\n",
    "XServerDisplayActivity startup handler"
)
display = add_import(
    display,
    "import com.winlator.container.Container;\n",
    "import com.winlator.WinCoreMaliCompatibility;\n",
    "XServerDisplayActivity Mali compatibility"
)
old_container_load = """            ContainerManager containerManager = new ContainerManager(this);
            container = containerManager.getContainerById(getIntent().getIntExtra("container_id", 0));
            containerManager.activateContainer(container);"""
new_container_load = """            int requestedContainerId = getIntent().getIntExtra("container_id", 0);
            ContainerManager containerManager = new ContainerManager(this, requestedContainerId);
            container = containerManager.getContainerById(requestedContainerId);
            if (container == null) {
                android.util.Log.e("WinCore/Containers", "Container " + requestedContainerId + " is missing or unreadable");
                Toast.makeText(
                    this,
                    "Container " + requestedContainerId + " could not be loaded. Reopen the container list and check its diagnostics.",
                    Toast.LENGTH_LONG
                ).show();
                finish();
                return;
            }
            try {
                containerManager.activateContainer(container);
            }
            catch (Exception error) {
                android.util.Log.e("WinCore/Containers", "Could not activate container " + requestedContainerId, error);
                Toast.makeText(this, "Could not activate container: " + error.getMessage(), Toast.LENGTH_LONG).show();
                finish();
                return;
            }"""
if old_container_load in display:
    display = display.replace(old_container_load, new_container_load, 1)
elif "Container " + '" + requestedContainerId' not in display:
    raise SystemExit("XServerDisplayActivity: container lookup/activation anchor changed")

# Automatically resolve Adreno-only Turnip away from Mali and select
# WineD3D's Vulkan renderer for the automatic Mali profile.
old_parse = """            this.graphicsDriver = GraphicsDrivers.parseIdentifiers(graphicsDriver);
            this.graphicsDriverConfig = GraphicsDrivers.parseConfigs(graphicsDriver, graphicsDriverConfig);
            this.dxwrapper = DXWrappers.parseIdentifier(dxwrapper);
            this.dxwrapperConfig = DXWrappers.parseConfigs(dxwrapper, dxwrapperConfig);"""
new_parse = """            String originallySelectedVulkanDriver = GraphicsDrivers.parseIdentifiers(graphicsDriver)[0];
            this.graphicsDriver = GraphicsDrivers.parseIdentifiers(graphicsDriver);
            this.graphicsDriver = WinCoreMaliCompatibility.resolveGraphicsDriver(this, this.graphicsDriver);
            this.graphicsDriverConfig = GraphicsDrivers.parseConfigs(graphicsDriver, graphicsDriverConfig);
            if (!originallySelectedVulkanDriver.equals(this.graphicsDriver[0])) {
                this.graphicsDriverConfig[0] = new KeyValueSet();
            }
            this.dxwrapper = DXWrappers.parseIdentifier(dxwrapper);
            this.dxwrapper = WinCoreMaliCompatibility.resolveDXWrapper(this, this.dxwrapper);
            this.dxwrapperConfig = DXWrappers.parseConfigs(dxwrapper, dxwrapperConfig);
            WinCoreMaliCompatibility.configureWineD3D(this, this.graphicsDriver, this.dxwrapper, this.dxwrapperConfig);"""
if old_parse in display:
    display = display.replace(old_parse, new_parse, 1)
elif "WinCoreMaliCompatibility.resolveGraphicsDriver(this" not in display:
    raise SystemExit("XServerDisplayActivity: graphics/DX wrapper parsing anchor changed")

env_anchor = """            envVars.putAll(container.getEnvVars());
            if (shortcut != null) envVars.putAll(shortcut.getExtra("envVars"));
            if (!envVars.has("WINEESYNC")) envVars.put("WINEESYNC", "1");"""
env_replacement = """            envVars.putAll(container.getEnvVars());
            if (shortcut != null) envVars.putAll(shortcut.getExtra("envVars"));
            WinCoreMaliCompatibility.applyEnvironment(this, graphicsDriver, dxwrapper, envVars);
            if (!envVars.has("WINEESYNC")) envVars.put("WINEESYNC", "1");"""
if env_anchor in display:
    display = display.replace(env_anchor, env_replacement, 1)
elif "WinCoreMaliCompatibility.applyEnvironment(this, graphicsDriver, dxwrapper, envVars);" not in display:
    raise SystemExit("XServerDisplayActivity: environment-variable insertion anchor changed")

# A bounded watchdog replaces an infinite preloader if Wine never maps an X11
# window. The timeout leaves a useful log instead of pretending launch succeeded.
field_anchor = "    private String screenEffectProfile;\n"
if "private final Handler startupHandler" not in display:
    if display.count(field_anchor) != 1:
        raise SystemExit("XServerDisplayActivity: startup field anchor changed")
    display = display.replace(
        field_anchor,
        field_anchor +
        "    private final Handler startupHandler = new Handler(Looper.getMainLooper());\n"
        "    private Runnable startupTimeout;\n",
        1
    )

flags_anchor = "        final boolean[] flags = {false, shortcut != null || getIntent().hasExtra(\"exec_path\")};\n"
timeout_code = """        final boolean[] flags = {false, shortcut != null || getIntent().hasExtra("exec_path")};
        startupTimeout = () -> {
            if (!flags[0] && !isFinishing() && !isDestroyed()) {
                android.util.Log.e(
                    "WinCore/Startup",
                    "Timed out waiting for the first renderable X11 window. Container=" +
                        (container != null ? container.id : "wineprefix-generation")
                );
                preloaderDialog.close();
                Toast.makeText(
                    this,
                    "Container startup timed out. Check the WinCore Wine/Box64 logs and graphics profile.",
                    Toast.LENGTH_LONG
                ).show();
            }
        };
"""
if flags_anchor in display:
    display = display.replace(flags_anchor, timeout_code, 1)
elif "startupTimeout = () ->" not in display:
    raise SystemExit("XServerDisplayActivity: startup flags anchor changed")


exit_callback_anchor = "        guestProgramLauncherComponent.setTerminationCallback((status) -> exit());"
exit_callback_replacement = """        guestProgramLauncherComponent.setTerminationCallback((status) -> {
            runOnUiThread(() -> {
                if (wincoreIntentionalExit || isFinishing() || isDestroyed()) return;
                if (status != 0 && !wincoreFirstWindowShown) {
                    android.util.Log.e(
                        "WinCore/GuestExit",
                        "Box64/Wine exited before the first Windows window. Exit code: " + status
                    );
                    String report = "Box64 / Wine stopped before opening a Windows window.\\n\\n" +
                        "Exit code: " + status + "\\n\\n" +
                        "The process output is recorded under the WinCore/ProcessOutput log tag. " +
                        "Open WinCore 7.0.0 Workspace → Session Logs to inspect the captured output.";
                    new android.app.AlertDialog.Builder(this)
                        .setTitle("Box64 / Wine failed to start")
                        .setMessage(report)
                        .setPositiveButton("Return to WinCore", (dialog, which) -> exit())
                        .setNeutralButton("Copy details", (dialog, which) -> {
                            android.content.ClipboardManager clipboard =
                                (android.content.ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
                            if (clipboard != null) {
                                clipboard.setPrimaryClip(
                                    android.content.ClipData.newPlainText("WinCore guest startup failure", report)
                                );
                                Toast.makeText(this, "Failure details copied", Toast.LENGTH_SHORT).show();
                            }
                        })
                        .setCancelable(false)
                        .show();
                }
                else {
                    exit();
                }
            });
        });"""
if exit_callback_anchor in display:
    display = display.replace(exit_callback_anchor, exit_callback_replacement, 1)
elif "WinCore/GuestExit" not in display:
    raise SystemExit("XServerDisplayActivity guest termination callback anchor changed")

map_anchor = """                    preloaderDialog.closeOnUiThread();
                    flags[0] = true;"""
map_replacement = """                    preloaderDialog.closeOnUiThread();
                    startupHandler.removeCallbacks(startupTimeout);
                    flags[0] = true;
                    wincoreFirstWindowShown = true;"""
if map_anchor in display:
    display = display.replace(map_anchor, map_replacement, 1)
elif "startupHandler.removeCallbacks(startupTimeout);" not in display:
    raise SystemExit("XServerDisplayActivity: first-window callback anchor changed")

worker_anchor = """        setupUI();

        Executors.newSingleThreadExecutor().execute(() -> {"""
worker_replacement = """        setupUI();
        startupHandler.postDelayed(startupTimeout, 60000L);
        android.util.Log.i("WinCore/Startup", "Container startup worker queued");

        Executors.newSingleThreadExecutor().execute(() -> {"""
if worker_anchor in display:
    display = display.replace(worker_anchor, worker_replacement, 1)
elif "startupHandler.postDelayed(startupTimeout" not in display:
    raise SystemExit("XServerDisplayActivity: startup worker anchor changed")

catch_anchor = '            catch (Exception error) {\n                android.util.Log.e("WinCore", "Container startup failed", error);'
catch_replacement = '            catch (Exception | LinkageError error) {\n                startupHandler.removeCallbacks(startupTimeout);\n                android.util.Log.e("WinCore", "Container startup failed", error);'
if catch_anchor in display:
    display = display.replace(catch_anchor, catch_replacement, 1)
elif "catch (Exception | LinkageError error)" not in display:
    raise SystemExit("XServerDisplayActivity: startup error handler anchor changed")
display_path.write_text(display, encoding="utf-8")

# Do not silently leave the new-container screen when the template archive
# cannot be extracted or the container directory cannot be created.
detail = detail_path.read_text(encoding="utf-8")
detail = add_import(
    detail,
    "import android.widget.TextView;\n",
    "import android.widget.Toast;\n",
    "ContainerDetailFragment creation error"
)
callback_start_marker = "manager.createContainerAsync(data, (container) -> {"
callback_start = detail.find(callback_start_marker)
if callback_start < 0:
    if "manager.getLastOperationError()" not in detail:
        raise SystemExit("ContainerDetailFragment: create-container callback anchor changed")
else:
    callback_end_marker = "                    });"
    callback_end = detail.find(callback_end_marker, callback_start)
    if callback_end < 0:
        raise SystemExit("ContainerDetailFragment: create-container callback end was not found")
    callback_end += len(callback_end_marker)
    new_callback = """manager.createContainerAsync(data, (container) -> {
                        if (container == null) {
                            preloaderDialog.close();
                            String detail = manager.getLastOperationError();
                            if (detail == null || detail.trim().isEmpty()) {
                                detail = "Check the RootFS and container pattern archive.";
                            }
                            android.util.Log.e("WinCore/Containers", "Container creation failed: " + detail);
                            Toast.makeText(context, "Container creation failed: " + detail, Toast.LENGTH_LONG).show();
                            return;
                        }
                        this.container = container;
                        String selectedWinCoreProfile = WinCoreProfileControls.getSelectedProfile(sWinCoreDeviceProfile);
                        container.putExtra("wincore_cpu_profile",
                            WinCoreDeviceProfile.GLOBAL.equals(selectedWinCoreProfile) ? null : selectedWinCoreProfile);
                        container.saveData();
                        saveWineRegistryKeys(view);
                        preloaderDialog.close();
                        getActivity().onBackPressed();
                    });"""
    detail = detail[:callback_start] + new_callback + detail[callback_end:]
detail_path.write_text(detail, encoding="utf-8")

# 4. Guest and PulseAudio processes are held as Process objects. The guest
#    startup path no longer needs reflective access to Android's private PID.
process_path = required("src/main/java/com/winlator/core/ProcessHelper.java")
process = process_path.read_text(encoding="utf-8")
start_process_method = r'''    private static void createProcessOutputThread(InputStream inputStream, String executable) {
        Thread thread = new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (!line.trim().isEmpty()) {
                        android.util.Log.i("WinCore/ProcessOutput", executable + ": " + line);
                    }
                }
            }
            catch (IOException error) {
                android.util.Log.w("WinCore/ProcessOutput", "Could not read process output for " + executable, error);
            }
        }, "WinCore-Process-Diagnostics");
        thread.setDaemon(true);
        thread.start();
    }

    public static java.lang.Process startProcess(
        String command,
        EnvVars envVars,
        File workingDir
    ) {
        java.lang.Process process = null;
        try {
            String[] arguments = splitCommand(command);
            if (arguments.length == 0) {
                throw new IllegalArgumentException("The process command is empty");
            }

            ProcessBuilder processBuilder = new ProcessBuilder(arguments);
            if (workingDir != null) {
                if (!workingDir.isDirectory()) {
                    throw new IllegalStateException(
                        "The process working directory does not exist: " + workingDir.getAbsolutePath()
                    );
                }
                processBuilder.directory(workingDir);
            }

            if (debugCallbacks.isEmpty()) {
                // Do not discard Box64 stderr. Merge and drain it to Android logcat.
                processBuilder.redirectErrorStream(true);
            }

            Map<String, String> environment = processBuilder.environment();
            if (envVars != null) {
                for (String name : envVars) environment.put(name, envVars.get(name));
            }

            process = processBuilder.start();

            if (!debugCallbacks.isEmpty()) {
                createDebugThread(process.getInputStream());
                createDebugThread(process.getErrorStream());
            }
            else {
                createProcessOutputThread(process.getInputStream(), arguments[0]);
            }

            android.util.Log.i(
                "WinCore/ProcessHelper",
                "Started process: " + arguments[0] +
                    " (workingDir=" + (workingDir != null ? workingDir.getAbsolutePath() : "<default>") + ")"
            );
            return process;
        }
        catch (Exception error) {
            if (process != null) {
                try { process.destroyForcibly(); }
                catch (Exception cleanupError) {
                    android.util.Log.w("WinCore/ProcessHelper", "Could not terminate failed process", cleanupError);
                }
            }
            String reason = error.getMessage() != null ? error.getMessage() : error.getClass().getSimpleName();
            android.util.Log.e(
                "WinCore/ProcessHelper",
                "Failed to start command: " + command +
                    " (workingDir=" + (workingDir != null ? workingDir.getAbsolutePath() : "<default>") + "): " + reason,
                error
            );
            throw new IllegalStateException(
                "Could not launch command: " + command + ". " + reason,
                error
            );
        }
    }

'''
exec_anchor = "    public static int exec(String command, EnvVars envVars, File workingDir, Callback<Integer> terminationCallback) {\n"
if "public static java.lang.Process startProcess(" not in process:
    if process.count(exec_anchor) != 1:
        raise SystemExit("ProcessHelper: exec insertion anchor changed")
    process = process.replace(exec_anchor, start_process_method + exec_anchor, 1)

old_exec = r'''    public static int exec(String command, EnvVars envVars, File workingDir, Callback<Integer> terminationCallback) {
        int pid = -1;
        try {
            ProcessBuilder processBuilder = (new ProcessBuilder(splitCommand(command))).directory(workingDir);
            if (debugCallbacks.isEmpty()) processBuilder.redirectOutput(new File("/dev/null")).redirectErrorStream(true);

            Map<String, String> environment = processBuilder.environment();
            for (String name : envVars) environment.put(name, envVars.get(name));

            java.lang.Process process = processBuilder.start();
            Field pidField = process.getClass().getDeclaredField("pid");
            pidField.setAccessible(true);
            pid = pidField.getInt(process);
            pidField.setAccessible(false);

            if (!debugCallbacks.isEmpty()) {
                createDebugThread(process.getInputStream());
                createDebugThread(process.getErrorStream());
            }

            if (terminationCallback != null) createWaitForThread(process, terminationCallback);
        }
        catch (Exception e) {}
        return pid;
    }'''
new_exec = r'''    public static int exec(String command, EnvVars envVars, File workingDir, Callback<Integer> terminationCallback) {
        java.lang.Process process = startProcess(command, envVars, workingDir);
        if (process == null) return -1;

        try {
            Field pidField = process.getClass().getDeclaredField("pid");
            pidField.setAccessible(true);
            int pid = pidField.getInt(process);
            pidField.setAccessible(false);

            if (pid <= 0) {
                throw new IllegalStateException("Android returned an invalid process id: " + pid);
            }
            if (terminationCallback != null) createWaitForThread(process, terminationCallback);
            return pid;
        }
        catch (Exception error) {
            try { process.destroyForcibly(); }
            catch (Exception cleanupError) {
                android.util.Log.w("WinCore/ProcessHelper", "Could not terminate process after PID lookup failure", cleanupError);
            }
            android.util.Log.e(
                "WinCore/ProcessHelper",
                "Could not obtain a process id for command: " + command,
                error
            );
            return -1;
        }
    }'''
if old_exec in process:
    process = process.replace(old_exec, new_exec, 1)
elif "Could not obtain a process id for command:" not in process:
    raise SystemExit("ProcessHelper: silent exec implementation anchor changed")
process_path.write_text(process, encoding="utf-8")

guest_path = required("src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java")
guest = guest_path.read_text(encoding="utf-8")

# Repair the silent Box64 extraction state bug. The upstream code used to write
# current_box64_version even when the archive failed to extract, which caused
# every later launch to skip recovery while the executable was still missing.
old_box64_extract = """    private void extractBox64File() {
        Context context = environment.getContext();
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String box64Version = preferences.getString("box64_version", DefaultVersion.BOX64);
        String currentBox64Version = preferences.getString("current_box64_version", "");

        if (!box64Version.equals(currentBox64Version)) {
            GeneralComponents.extractFile(GeneralComponents.Type.BOX64, context, box64Version, DefaultVersion.BOX64);
            preferences.edit().putString("current_box64_version", box64Version).apply();
        }
    }"""
new_box64_extract = """    private void extractBox64File() {
        Context context = environment.getContext();
        RootFS rootFS = environment.getRootFS();
        File rootDir = rootFS.getRootDir();
        File box64File = new File(rootDir, "usr/local/bin/box64");
        File box64Directory = box64File.getParentFile();
        if (box64Directory == null || (!box64Directory.isDirectory() && !box64Directory.mkdirs())) {
            throw new IllegalStateException(
                "Could not prepare the RootFS Box64 directory: " +
                    (box64Directory != null ? box64Directory.getAbsolutePath() : "<null>")
            );
        }

        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String box64Version = preferences.getString("box64_version", DefaultVersion.BOX64);
        String currentBox64Version = preferences.getString("current_box64_version", "");
        boolean extractionSucceeded = box64Version.equals(currentBox64Version) &&
            isBox64RuntimeReady(box64File);

        if (!extractionSucceeded) {
            if (GeneralComponents.isBuiltinComponent(GeneralComponents.Type.BOX64, box64Version)) {
                String packagedArchive = "box64/box64-" + box64Version + ".tzst";
                extractionSucceeded = TarCompressorUtils.extract(
                    TarCompressorUtils.Type.ZSTD, context, packagedArchive, rootDir
                );
                if (!extractionSucceeded) {
                    android.util.Log.e(
                        "WinCore/Box64",
                        "Packaged Box64 extraction returned failure for " + packagedArchive
                    );
                }
            }
            else {
                File customArchive = new File(
                    GeneralComponents.getComponentDir(GeneralComponents.Type.BOX64, context),
                    "box64-" + box64Version + ".tzst"
                );
                extractionSucceeded = TarCompressorUtils.extract(
                    TarCompressorUtils.Type.ZSTD, customArchive, rootDir
                );
                if (!extractionSucceeded) {
                    android.util.Log.w(
                        "WinCore/Box64",
                        "Custom Box64 archive could not be extracted: " + customArchive.getAbsolutePath()
                    );
                }
            }
        }

        // Never trust a version preference by itself. Recover from a missing,
        // truncated, or wrong-architecture executable with the packaged default.
        if (!isBox64RuntimeReady(box64File)) {
            String fallbackArchive = "box64/box64-" + DefaultVersion.BOX64 + ".tzst";
            android.util.Log.w("WinCore/Box64", "Box64 is missing or invalid; extracting " + fallbackArchive);
            boolean fallbackSucceeded = TarCompressorUtils.extract(
                TarCompressorUtils.Type.ZSTD, context, fallbackArchive, rootDir
            );
            if (isBox64RuntimeReady(box64File)) {
                box64Version = DefaultVersion.BOX64;
                extractionSucceeded = fallbackSucceeded;
            }
        }

        if (!isBox64RuntimeReady(box64File)) {
            throw new IllegalStateException(
                "Box64 is missing or invalid after recovery. Expected an ARM64 ELF executable at " +
                    box64File.getAbsolutePath() +
                    ". Checked the selected Box64 archive and packaged fallback " +
                    DefaultVersion.BOX64 + ". Check the Box64 archive extraction log. " +
                    "Your containers have not been deleted."
            );
        }

        FileUtils.chmod(box64File, 0771);
        if (!box64File.canExecute()) {
            throw new IllegalStateException(
                "Box64 was extracted but Android cannot execute it: " + box64File.getAbsolutePath() +
                    ". Check app storage permissions and available filesystem space."
            );
        }

        // Commit the version marker only when extraction has been verified.
        // A failed custom update will be retried on the next launch.
        if (extractionSucceeded || box64Version.equals(currentBox64Version)) {
            preferences.edit().putString("current_box64_version", box64Version).apply();
        }
        android.util.Log.i(
            "WinCore/Box64",
            "Verified Box64 ARM64 executable: " + box64File.getAbsolutePath() +
                " (" + box64File.length() + " bytes, executable=" + box64File.canExecute() + ")"
        );
    }

    private boolean isBox64RuntimeReady(File box64File) {
        if (box64File == null || !box64File.isFile() || box64File.length() < 4096 || !box64File.canRead()) {
            return false;
        }
        try (FileInputStream input = new FileInputStream(box64File)) {
            byte[] header = new byte[20];
            int offset = 0;
            while (offset < header.length) {
                int count = input.read(header, offset, header.length - offset);
                if (count < 0) return false;
                offset += count;
            }
            int machine = (header[18] & 0xff) | ((header[19] & 0xff) << 8);
            return (header[0] & 0xff) == 0x7f && header[1] == 'E' &&
                header[2] == 'L' && header[3] == 'F' && header[4] == 2 &&
                header[5] == 1 && machine == 183;
        }
        catch (IOException error) {
            android.util.Log.e("WinCore/Box64", "Could not read Box64 ELF header", error);
            return false;
        }
    }"""
if old_box64_extract in guest:
    guest = guest.replace(old_box64_extract, new_box64_extract, 1)
elif "Box64 is missing or invalid after recovery" not in guest:
    raise SystemExit("GuestProgramLauncherComponent: Box64 extraction method anchor changed")
guest = guest.replace("import android.os.Process;\n", "")
guest = guest.replace(
    "import com.winlator.core.GeneralComponents;\n",
    "import com.winlator.core.GeneralComponents;\nimport com.winlator.core.TarCompressorUtils;\n"
)
guest = guest.replace(
    "import java.io.File;\n",
    "import java.io.File;\nimport java.io.FileInputStream;\nimport java.io.IOException;\n"
)
guest = guest.replace("    private static int pid = -1;\n", "    private static java.lang.Process guestProcess;\n")
old_start = """    @Override
    public void start() {
        synchronized (lock) {
            stop();
            extractBox64File();
            copyDefaultBox64RCFile();
            pid = execGuestProgram();
        }
    }"""
new_start = """    @Override
    public void start() {
        synchronized (lock) {
            stop();
            extractBox64File();
            copyDefaultBox64RCFile();

            guestProcess = execGuestProgram();
            if (guestProcess == null) {
                throw new IllegalStateException(
                    "Box64 could not be started. Check the WinCore/ProcessHelper log for the exact process error."
                );
            }

            final java.lang.Process startedProcess = guestProcess;
            Thread waiter = new Thread(() -> {
                final int status;
                try {
                    status = startedProcess.waitFor();
                }
                catch (InterruptedException error) {
                    Thread.currentThread().interrupt();
                    return;
                }

                synchronized (lock) {
                    if (guestProcess == startedProcess) guestProcess = null;
                }
                if (terminationCallback != null) terminationCallback.call(status);
            }, "WinCore-Guest-Process-Waiter");
            waiter.setDaemon(true);
            waiter.start();
        }
    }"""
if old_start in guest:
    guest = guest.replace(old_start, new_start, 1)
elif "WinCore-Guest-Process-Waiter" not in guest:
    raise SystemExit("GuestProgramLauncherComponent: start method anchor changed")

old_stop = """    @Override
    public void stop() {
        synchronized (lock) {
            if (pid != -1) {
                Process.killProcess(pid);
                pid = -1;
            }
        }
    }"""
new_stop = """    @Override
    public void stop() {
        synchronized (lock) {
            if (guestProcess != null) {
                try { guestProcess.destroyForcibly(); }
                catch (Exception error) {
                    android.util.Log.w("WinCore/GuestLauncher", "Could not stop Box64 process", error);
                }
                guestProcess = null;
            }
        }
    }"""
if old_stop in guest:
    guest = guest.replace(old_stop, new_stop, 1)
elif "guestProcess.destroyForcibly()" not in guest:
    raise SystemExit("GuestProgramLauncherComponent: stop method anchor changed")

guest = guest.replace("    private int execGuestProgram() {", "    private java.lang.Process execGuestProgram() {", 1)
old_guest_exec = """        return ProcessHelper.exec(command, envVars, rootDir, (status) -> {
            synchronized (lock) {
                pid = -1;
            }
            if (terminationCallback != null) terminationCallback.call(status);
        });"""
if old_guest_exec in guest:
    guest = guest.replace(old_guest_exec, "        return ProcessHelper.startProcess(command, envVars, rootDir);", 1)
guest = guest.replace("if (pid != -1) {", "if (guestProcess != null) {")
if "pid != -1" in guest or "Process.killProcess(pid)" in guest:
    raise SystemExit("GuestProgramLauncherComponent: an old PID-based branch remains")
guest_path.write_text(guest, encoding="utf-8")

pulse_path = required("src/main/java/com/winlator/xenvironment/components/PulseAudioComponent.java")
pulse = pulse_path.read_text(encoding="utf-8")
pulse = pulse.replace("import android.os.Process;\n", "")
pulse = pulse.replace("    private static int pid = -1;\n", "    private static java.lang.Process audioProcess;\n")
pulse = pulse.replace(
    "            pid = execPulseAudio();",
    """            audioProcess = execPulseAudio();
            if (audioProcess == null) {
                throw new IllegalStateException("PulseAudio could not be started. Check WinCore/ProcessHelper logs.");
            }""",
    1
)
pulse = pulse.replace(
    """            if (pid != -1) {
                Process.killProcess(pid);
                pid = -1;
            }""",
    """            if (audioProcess != null) {
                try { audioProcess.destroyForcibly(); }
                catch (Exception error) {
                    android.util.Log.w("WinCore/PulseAudio", "Could not stop PulseAudio", error);
                }
                audioProcess = null;
            }""",
    1
)
pulse = pulse.replace("    private int execPulseAudio() {", "    private java.lang.Process execPulseAudio() {", 1)
pulse = pulse.replace(
    "return ProcessHelper.exec(command, envVars, workingDir);",
    "return ProcessHelper.startProcess(command, envVars, workingDir);",
    1
)
if "Process.killProcess(pid)" in pulse or "private static int pid" in pulse:
    raise SystemExit("PulseAudioComponent: an old PID-based branch remains")
pulse_path.write_text(pulse, encoding="utf-8")

# Do not rewrite runtime executable paths globally. The diagnostic checks both supported locations.


# Log archive extraction failures instead of hiding the IOException behind false.
tar_path = required("src/main/java/com/winlator/core/TarCompressorUtils.java")
tar_source = tar_path.read_text(encoding="utf-8")
old_asset_extract = """        catch (IOException e) {
            return false;
        }
    }

    public static boolean extract(Type type, Context context, Uri source, File destination)"""
new_asset_extract = """        catch (IOException e) {
            android.util.Log.e("WinCore/Archive", "Could not open packaged archive: " + assetFile, e);
            return false;
        }
    }

    public static boolean extract(Type type, Context context, Uri source, File destination)"""
if old_asset_extract in tar_source:
    tar_source = tar_source.replace(old_asset_extract, new_asset_extract, 1)
elif "Could not open packaged archive:" not in tar_source:
    raise SystemExit("TarCompressorUtils packaged-asset error anchor changed.")

old_tar_extract = """        catch (IOException e) {
            return false;
        }
    }

    public static long getContentLength(Type type, Context context, String assetFile, File destination)"""
new_tar_extract = """        catch (IOException e) {
            android.util.Log.e(
                "WinCore/Archive",
                "Archive extraction failed into " + destination.getAbsolutePath(),
                e
            );
            return false;
        }
    }

    public static long getContentLength(Type type, Context context, String assetFile, File destination)"""
if old_tar_extract in tar_source:
    tar_source = tar_source.replace(old_tar_extract, new_tar_extract, 1)
elif "Archive extraction failed into " not in tar_source:
    raise SystemExit("TarCompressorUtils extraction error anchor changed.")
tar_path.write_text(tar_source, encoding="utf-8")

# Fail early when the pinned app submodule does not contain the bundled Box64 runtime.
box64_archive = required("src/main/assets/box64/box64-0.4.4.tzst")
if box64_archive.stat().st_size < 1000000:
    raise SystemExit(f"Packaged Box64 archive is missing or implausibly small: {box64_archive}")

# Verify the critical markers before Gradle compiles.
checks = {
    "src/main/java/com/winlator/core/GPUHelper.java": [
        "CountDownLatch",
        "completed.await(1200, TimeUnit.MILLISECONDS)",
        "GPU probe timed out"
    ],
    "src/main/java/com/winlator/WinCoreMaliCompatibility.java": [
        "public static boolean isMali(Context context)",
        "DXWrappers.WINED3D",
        'config[0].put("renderer", renderer)',
        "MESA_GL_VERSION_OVERRIDE"
    ],
    "src/main/java/com/winlator/container/ContainerManager.java": [
        "getLastOperationError()",
        "lastOperationError = error.getMessage()"
    ],
    "src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java": [
        "ProcessHelper.startProcess(command, envVars, rootDir)",
        "WinCore-Guest-Process-Waiter",
        "guestProcess.destroyForcibly()",
        "Box64 is missing or invalid after recovery",
        "GeneralComponents.isBuiltinComponent(GeneralComponents.Type.BOX64, box64Version)",
        "TarCompressorUtils.Type.ZSTD",
        "isBox64RuntimeReady(box64File)",
        "header[4] == 2",
        "FileUtils.chmod(box64File, 0771)",
        "preferences.edit().putString(\"current_box64_version\", box64Version).apply()"
    ],
    "src/main/java/com/winlator/core/ProcessHelper.java": [
        "createProcessOutputThread(InputStream inputStream, String executable)",
        "Could not launch command:",
        "processBuilder.redirectErrorStream(true)"
    ],
    "src/main/java/com/winlator/core/TarCompressorUtils.java": [
        "Could not open packaged archive:",
        "Archive extraction failed into "
    ],
    "src/main/java/com/winlator/xenvironment/components/PulseAudioComponent.java": [
        "ProcessHelper.startProcess(command, envVars, workingDir)",
        "audioProcess.destroyForcibly()"
    ],
    "src/main/java/com/winlator/XServerDisplayActivity.java": [
        "new ContainerManager(this, requestedContainerId)",
        "WinCoreMaliCompatibility.resolveGraphicsDriver(this",
        "startupHandler.postDelayed(startupTimeout, 60000L)",
        "catch (Exception | LinkageError error)"
    ]
}
for relative, markers in checks.items():
    source = required(relative).read_text(encoding="utf-8")
    for marker in markers:
        if marker not in source:
            raise SystemExit(f"WinCore Mali/container verification failed: {relative} missing {marker!r}")

for relative, markers in {
    "src/main/res/layout/settings_fragment.xml": ["CBWinCoreMaliCompatibility"],
    "src/main/java/com/winlator/SettingsFragment.java": ["WinCoreMaliCompatibility.AUTO_PROFILE_KEY"],
    "src/main/java/com/winlator/ContainerDetailFragment.java": [
        "WinCoreMaliCompatibility.getDefaultGraphicsDriver(context)",
        "manager.getLastOperationError()"
    ]
}.items():
    source = required(relative).read_text(encoding="utf-8")
    for marker in markers:
        if marker not in source:
            raise SystemExit(f"WinCore Mali/container UI verification failed: {relative} missing {marker!r}")

print("WinCore 7.0.0 Mali compatibility, bounded GPU probing, container error reporting, and Process-handle startup fixes applied.")
PY
