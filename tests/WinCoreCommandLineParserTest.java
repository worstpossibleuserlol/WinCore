package com.winlator.core;

import java.util.Arrays;

public final class WinCoreCommandLineParserTest {
    private static int assertions;

    private static void expect(String label, String command, String... expected) {
        String[] actual = WinCoreCommandLineParser.split(command);
        assertions++;
        if (!Arrays.equals(expected, actual)) {
            throw new AssertionError(label + "\nexpected=" + Arrays.toString(expected) +
                "\nactual=" + Arrays.toString(actual));
        }
    }

    private static void expectUnclosedQuoteRejected() {
        assertions++;
        try {
            WinCoreCommandLineParser.split("wine \"unterminated");
            throw new AssertionError("unclosed quote was accepted");
        }
        catch (IllegalArgumentException expected) {
            // Expected: malformed command must be rejected before process creation.
        }
    }

    public static void main(String[] args) {
        expect("standard Wine window command",
            "/root/usr/local/bin/box64 wine explorer /desktop=shell,1280x720 " +
                "C:\\windows\\winhandler.exe /dir C:\\windows \"wfm.exe\"",
            "/root/usr/local/bin/box64", "wine", "explorer",
            "/desktop=shell,1280x720", "C:\\windows\\winhandler.exe",
            "/dir", "C:\\windows", "wfm.exe");

        expect("quoted Windows path with spaces",
            "wine \"C:\\Program Files\\Game Folder\\game.exe\" -windowed",
            "wine", "C:\\Program Files\\Game Folder\\game.exe", "-windowed");

        expect("Winlator escaped spaces",
            "wine C:\\Program\\ Files\\Game\\ game.exe",
            "wine", "C:\\Program Files\\Game game.exe");

        expect("empty quoted argument and trailing whitespace",
            "wine \"\"   ",
            "wine", "");

        expect("escaped quote",
            "wine \"prefix\\\"quoted\\\"suffix\"",
            "wine", "prefix\"quoted\"suffix");

        expect("empty input", "   ");
        expectUnclosedQuoteRejected();
        System.out.println("WinCoreCommandLineParser: " + assertions + " assertions passed.");
    }
}
