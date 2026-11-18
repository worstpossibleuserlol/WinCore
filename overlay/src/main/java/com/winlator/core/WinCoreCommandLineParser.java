package com.winlator.core;

import java.util.ArrayList;

/**
 * Tokenizes Winlator guest commands for ProcessBuilder.
 *
 * Quotes group one argument; they are syntax and are never included in argv.
 * Backslash-space outside quotes is Winlator's existing escaped-space form.
 * Other backslashes are preserved so Windows paths such as C:\\windows remain intact.
 */
public final class WinCoreCommandLineParser {
    private WinCoreCommandLineParser() { }

    public static String[] split(String command) {
        if (command == null || command.trim().isEmpty()) return new String[0];

        ArrayList<String> result = new ArrayList<>();
        StringBuilder value = new StringBuilder();
        boolean inQuotes = false;
        boolean tokenStarted = false;

        for (int i = 0; i < command.length(); i++) {
            char current = command.charAt(i);
            char next = i + 1 < command.length() ? command.charAt(i + 1) : 0;

            if (current == '\\\\' && next == '"') {
                value.append('"');
                tokenStarted = true;
                i++;
                continue;
            }

            if (!inQuotes && current == '\\\\' && next == ' ') {
                value.append(' ');
                tokenStarted = true;
                i++;
                continue;
            }

            if (current == '"') {
                inQuotes = !inQuotes;
                tokenStarted = true;
                continue;
            }

            if (Character.isWhitespace(current) && !inQuotes) {
                if (tokenStarted) {
                    result.add(value.toString());
                    value.setLength(0);
                    tokenStarted = false;
                }
                continue;
            }

            value.append(current);
            tokenStarted = true;
        }

        if (inQuotes) {
            throw new IllegalArgumentException("Unclosed double quote in process command");
        }
        if (tokenStarted) result.add(value.toString());
        return result.toArray(new String[0]);
    }
}
