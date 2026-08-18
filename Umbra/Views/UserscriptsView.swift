// UserscriptsView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct UserscriptsView: View {
    @EnvironmentObject var userscriptService: UserscriptService
    @Environment(\.dismiss) private var dismiss
    @State private var showAddScript = false
    @State private var newScriptName = ""
    @State private var newScriptSource = ""
    @State private var newScriptInjection: Userscript.InjectionTime = .atDocumentEnd
    @State private var newScriptPatterns = "*://*/*"
    @State private var editingScript: Userscript?

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                if userscriptService.scripts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 40))
                            .foregroundColor(UmbraTheme.textMuted)
                        Text("No Userscripts")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(UmbraTheme.textSecondary)
                        Text("Add custom JavaScript that runs\non pages you visit.")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                            .multilineTextAlignment(.center)

                        Text("Scripts are stored in:\nDocuments/Userscripts/")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(UmbraTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                } else {
                    List {
                        ForEach(userscriptService.scripts) { script in
                            scriptRow(script)
                                .listRowBackground(UmbraTheme.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        userscriptService.removeScript(script)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Userscripts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddScript = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(UmbraTheme.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UmbraTheme.accent)
                }
            }
            .toolbarBackground(UmbraTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAddScript) {
                addScriptSheet
            }
        }
    }

    // MARK: - Script Row

    @ViewBuilder
    private func scriptRow(_ script: Userscript) -> some View {
        HStack(spacing: 12) {
            // Toggle
            Button {
                userscriptService.toggleScript(script)
            } label: {
                Image(systemName: script.enabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(script.enabled ? UmbraTheme.success : UmbraTheme.textMuted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(script.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(script.enabled ? UmbraTheme.textPrimary : UmbraTheme.textMuted)

                HStack(spacing: 8) {
                    Text(script.injectionTime.displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(UmbraTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(UmbraTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(script.matchPatterns.first ?? "*")
                        .font(.system(size: 11))
                        .foregroundColor(UmbraTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(script.filename)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(UmbraTheme.textMuted)
                .lineLimit(1)
        }
    }

    // MARK: - Add Script Sheet

    private var addScriptSheet: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(UmbraTheme.textMuted)

                            TextField("My Script", text: $newScriptName)
                                .font(.system(size: 15))
                                .foregroundColor(UmbraTheme.textPrimary)
                                .padding(12)
                                .background(UmbraTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(UmbraTheme.border, lineWidth: 0.5)
                                )
                        }

                        // Injection time
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Run at")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(UmbraTheme.textMuted)

                            Picker("Injection Time", selection: $newScriptInjection) {
                                ForEach(Userscript.InjectionTime.allCases, id: \.rawValue) { time in
                                    Text(time.displayName).tag(time)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Match patterns
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Match patterns")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(UmbraTheme.textMuted)

                            TextField("*://*/*", text: $newScriptPatterns)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(UmbraTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(UmbraTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(UmbraTheme.border, lineWidth: 0.5)
                                )

                            Text("Comma-separated. Use *://*.example.com/* to match a specific site.")
                                .font(.system(size: 11))
                                .foregroundColor(UmbraTheme.textMuted)
                        }

                        // Source code
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JavaScript")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(UmbraTheme.textMuted)

                            TextEditor(text: $newScriptSource)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(UmbraTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(12)
                                .background(UmbraTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(UmbraTheme.border, lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Userscript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        resetForm()
                        showAddScript = false
                    }
                    .foregroundColor(UmbraTheme.textMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveScript()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(UmbraTheme.accent)
                    .disabled(newScriptName.isEmpty || newScriptSource.isEmpty)
                }
            }
            .toolbarBackground(UmbraTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func saveScript() {
        let patterns = newScriptPatterns
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        userscriptService.addScript(
            name: newScriptName,
            source: newScriptSource,
            injectionTime: newScriptInjection,
            matchPatterns: patterns.isEmpty ? ["*://*/*"] : patterns
        )

        resetForm()
        showAddScript = false
    }

    private func resetForm() {
        newScriptName = ""
        newScriptSource = ""
        newScriptInjection = .atDocumentEnd
        newScriptPatterns = "*://*/*"
    }
}
