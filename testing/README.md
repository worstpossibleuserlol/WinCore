# WinCore compatibility testing

This folder defines a repeatable manual test process. It is a test plan, not a claim that these tests have already passed.

## Testing principles

- Record the exact WinCore build and device configuration.
- Back up containers before testing changes.
- Change one variable at a time.
- Repeat important tests after a fresh app launch.
- Separate build success, audit success, game launch, gameplay stability, and performance.
- Mark unrun tests as Not tested. Do not convert missing evidence into a pass.

## Suggested test order

1. Install and open WinCore.
2. Inspect device diagnostics.
3. Create or open a disposable test container.
4. Run the container audit.
5. Verify global, container, and shortcut profile precedence.
6. Launch a small known-compatible Windows application.
7. Test controller input separately from keyboard/mouse input.
8. Test graphics settings one at a time.
9. Observe app stability and Android thermal/memory status.
10. Repeat after a clean relaunch and record the result.

Use MANUAL_TEST_PLAN.md for detailed cases and COMPATIBILITY_MATRIX_TEMPLATE.md to record results.
