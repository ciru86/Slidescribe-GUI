//
//  ContentView.swift
//  SlideScribe
//
//  Created by Pier Paolo Cirulli on 28/03/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var outputFolderPath: String = ""
    @State private var inputURL: String = ""
    @State private var generatedCommand: String = ""
    @State private var feedbackMessage: String = ""
    @State private var executionErrorMessage: String = ""
    @State private var showExecutionError: Bool = false
    @State private var showOptionsWindow: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var isDropHovered: Bool = false

    @State private var executionLog: String = ""
    @State private var showExecutionLogWindow: Bool = false
    @State private var executionStatus: String = "Idle"
    @State private var runningProcess: Process?
    @State private var isRunning: Bool = false

    @State private var videoBasename: String = ""
    @State private var lessonTopic: String = ""
    @State private var terminologyContext: String = ""
    @State private var terminologyFile: String = ""
    @State private var roiMode: String = "separate"
    @State private var enhanceSlide: Bool = true
    @State private var enhancePreset: String = ""
    @State private var chunkSize: String = ""
    @State private var subLangs: String = ""
    @State private var ytdlpMode: String = ""
    @State private var cookiesFromBrowser: String = ""
    @State private var model: String = ""
    @State private var temperature: String = ""
    @State private var maxOutputTokens: String = ""
    @State private var effort: String = ""
    @State private var verbosity: String = ""
    @State private var scriptVerbosity: String = ""
    @State private var llmVerbosity: String = ""
    @State private var promptFile: String = ""
    @State private var useDefaultConfig: Bool = false
    @State private var configFile: String = ""

    @State private var skipDownload: Bool = false
    @State private var skipSubs: Bool = false
    @State private var skipScreenshots: Bool = false
    @State private var skipLLM: Bool = false
    @State private var skipPDF: Bool = false
    @State private var fromStep: String = ""
    @State private var forceAll: Bool = false

    @State private var keepIntermediateSrts: Bool = false
    @State private var keepRawJSON: Bool = false
    @State private var keepTemp: Bool = false
    @State private var nonInteractive: Bool = false
    @State private var dryRun: Bool = false
    @State private var manual: Bool = false

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .windowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ToolbarPill {
                        IconOnlyButton(icon: "gearshape", helpText: "Opzioni") {
                            showOptionsWindow = true
                        }
                    }

                    Spacer(minLength: 0)

                    ToolbarPill {
                        IconOnlyButton(icon: "folder", helpText: "Scegli o crea workdir") {
                            pickOutputFolder()
                        }
                    }
                }
                .padding(.bottom, 2)

                OutputDropZone(
                    title: outputFolderDisplayName,
                    subtitle: outputFolderSubtitle,
                    isTargeted: isDropTargeted,
                    isHovered: isDropHovered
                )
                .onHover { hovering in
                    isDropHovered = hovering
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("YouTube URL")
                        .font(.headline.weight(.semibold))

                    TextField("https://www.youtube.com/watch?v=...", text: $inputURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)

                    if let urlValidationMessage {
                        ValidationMessage(text: urlValidationMessage)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        runCommand()
                    } label: {
                        Label(isRunning ? "Running..." : "Run", systemImage: isRunning ? "hourglass" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .disabled(isRunning || workdirValidationMessage != nil || urlValidationMessage != nil)

                    Button {
                        showExecutionLogWindow = true
                    } label: {
                        Label("Log", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .disabled(executionLog.isEmpty && !isRunning)

                    if isRunning {
                        Button(role: .destructive) {
                            stopRunningProcess()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Command")
                            .font(.headline.weight(.semibold))

                        Spacer(minLength: 0)

                        Text("Preview")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        Text(generatedCommand.isEmpty ? "Il comando generato verrà visualizzato qui ed eseguito direttamente dall'app." : generatedCommand)
                            .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(generatedCommand.isEmpty ? Color.secondary : Color.primary.opacity(0.96))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                    }
                    .frame(minHeight: 132)
                    .background(commandBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(commandBorderColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04), radius: 8, y: 3)

                    StatusRow(
                        statusText: executionStatus,
                        detailText: feedbackMessage,
                        isRunning: isRunning
                    )
                }
            }
            .padding(18)
        }
        .frame(width: 640, height: 560, alignment: .topLeading)
        .sheet(isPresented: $showOptionsWindow) {
            OptionsSheet(
                videoBasename: $videoBasename,
                lessonTopic: $lessonTopic,
                terminologyContext: $terminologyContext,
                terminologyFile: $terminologyFile,
                roiMode: $roiMode,
                enhanceSlide: $enhanceSlide,
                enhancePreset: $enhancePreset,
                chunkSize: $chunkSize,
                subLangs: $subLangs,
                ytdlpMode: $ytdlpMode,
                cookiesFromBrowser: $cookiesFromBrowser,
                model: $model,
                temperature: $temperature,
                maxOutputTokens: $maxOutputTokens,
                effort: $effort,
                verbosity: $verbosity,
                scriptVerbosity: $scriptVerbosity,
                llmVerbosity: $llmVerbosity,
                promptFile: $promptFile,
                useDefaultConfig: $useDefaultConfig,
                configFile: $configFile,
                skipDownload: $skipDownload,
                skipSubs: $skipSubs,
                skipScreenshots: $skipScreenshots,
                skipLLM: $skipLLM,
                skipPDF: $skipPDF,
                fromStep: $fromStep,
                forceAll: $forceAll,
                keepIntermediateSrts: $keepIntermediateSrts,
                keepRawJSON: $keepRawJSON,
                keepTemp: $keepTemp,
                nonInteractive: $nonInteractive,
                dryRun: $dryRun,
                manual: $manual,
                onPickTerminologyFile: {
                    terminologyFile = pickFilePath() ?? terminologyFile
                },
                onPickPromptFile: {
                    promptFile = pickFilePath() ?? promptFile
                },
                onPickConfigFile: {
                    configFile = pickFilePath() ?? configFile
                }
            )
        }
        .sheet(isPresented: $showExecutionLogWindow) {
            ExecutionLogSheet(
                isPresented: $showExecutionLogWindow,
                logText: $executionLog,
                statusText: executionStatus,
                isRunning: isRunning,
                onStop: stopRunningProcess,
                onCopy: copyExecutionLog,
                onClear: clearExecutionLog
            )
        }
        .alert("Errore esecuzione", isPresented: $showExecutionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(executionErrorMessage)
        }
    }

    private var commandBackgroundColor: Color {
        Color(nsColor: colorScheme == .dark ? .textBackgroundColor : .controlBackgroundColor)
            .opacity(colorScheme == .dark ? 0.94 : 0.98)
    }

    private var commandBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var outputFolderDisplayName: String {
        if outputFolderPath.isEmpty {
            return "Drop Workdir Here"
        }
        return URL(fileURLWithPath: outputFolderPath).lastPathComponent
    }

    private var outputFolderSubtitle: String {
        if let workdirValidationMessage {
            return workdirValidationMessage
        }
        return outputFolderPath
    }

    private var workdirValidationMessage: String? {
        let trimmed = outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Scegli o trascina una cartella di lavoro"
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            return "La workdir deve essere una cartella valida"
        }

        return nil
    }

    private var urlValidationMessage: String? {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Inserisci un URL YouTube"
        }

        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return "URL non valido"
        }

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return nil
        }

        return "Inserisci un URL YouTube valido"
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scegli cartella"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolderPath = url.path
    }

    private func pickFilePath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return
            }

            DispatchQueue.main.async {
                outputFolderPath = url.path
            }
        }

        return true
    }

    private func runCommand() {
        guard workdirValidationMessage == nil, urlValidationMessage == nil else {
            feedbackMessage = "Correggi workdir e URL prima di eseguire il comando."
            return
        }

        generatedCommand = buildCommandString()
        executionLog = ""
        executionStatus = "Running"
        isRunning = true
        showExecutionLogWindow = true
        feedbackMessage = "Esecuzione in corso..."

        appendToLog("$ \(generatedCommand)\n\n")

        do {
            runningProcess = try TerminalExecutor.execute(command: generatedCommand) { event in
                switch event {
                case .stdout(let text):
                    appendToLog(text)

                case .stderr(let text):
                    appendToLog(text)

                case .finished(let exitCode):
                    runningProcess = nil
                    isRunning = false

                    if exitCode == 0 {
                        executionStatus = "Finished successfully"
                        feedbackMessage = "Comando completato."
                    } else if exitCode == 15 {
                        executionStatus = "Stopped"
                        feedbackMessage = "Esecuzione interrotta."
                    } else {
                        executionStatus = "Failed (exit \(exitCode))"
                        feedbackMessage = "Comando terminato con errore."
                    }

                    appendToLog("\n\n[Process finished with exit code \(exitCode)]\n")
                }
            }
        } catch {
            runningProcess = nil
            isRunning = false
            executionStatus = "Launch failed"
            executionErrorMessage = error.localizedDescription
            showExecutionError = true
            feedbackMessage = "Esecuzione fallita."
            appendToLog("\n[Launch error] \(error.localizedDescription)\n")
        }
    }

    private func stopRunningProcess() {
        runningProcess?.terminate()
        feedbackMessage = "Interruzione in corso..."
    }

    private func appendToLog(_ text: String) {
        executionLog += text
    }

    private func clearExecutionLog() {
        guard !isRunning else { return }
        executionLog = ""
        executionStatus = "Idle"
    }

    private func copyExecutionLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(executionLog, forType: .string)
    }

    private func buildCommandString() -> String {
        buildCommandComponents()
            .map(shellEscape)
            .joined(separator: " ")
    }

    private func buildCommandComponents() -> [String] {
        var components = ["slidescribe"]

        appendOption("--workdir", value: outputFolderPath, to: &components)
        appendOption("--youtube-url", value: inputURL, to: &components)
        appendOption("--video-basename", value: videoBasename, to: &components)
        appendOption("--lesson-topic", value: lessonTopic, to: &components)
        appendOption("--terminology-context", value: terminologyContext, to: &components)
        appendOption("--terminology-file", value: terminologyFile, to: &components)
        appendOption("--roi-mode", value: roiMode, to: &components)

        if enhanceSlide {
            components.append("--enhance-slide")
        }

        appendOption("--enhance-preset", value: enhancePreset, to: &components)
        appendOption("--chunk-size", value: chunkSize, to: &components)
        appendOption("--sub-langs", value: subLangs, to: &components)
        appendOption("--ytdlp-mode", value: ytdlpMode, to: &components)
        appendOption("--cookies-from-browser", value: cookiesFromBrowser, to: &components)
        appendOption("--model", value: model, to: &components)
        appendOption("--temperature", value: temperature, to: &components)
        appendOption("--max-output-tokens", value: maxOutputTokens, to: &components)
        appendOption("--effort", value: effort, to: &components)
        appendOption("--verbosity", value: verbosity, to: &components)
        appendOption("--script-verbosity", value: scriptVerbosity, to: &components)
        appendOption("--llm-verbosity", value: llmVerbosity, to: &components)
        appendOption("--prompt-file", value: promptFile, to: &components)

        if useDefaultConfig {
            components.append("--config")
        }

        appendOption("--config-file", value: configFile, to: &components)

        if skipDownload {
            components.append("--skip-download")
        }
        if skipSubs {
            components.append("--skip-subs")
        }
        if skipScreenshots {
            components.append("--skip-screenshots")
        }
        if skipLLM {
            components.append("--skip-llm")
        }
        if skipPDF {
            components.append("--skip-pdf")
        }

        appendOption("--from-step", value: fromStep, to: &components)

        if forceAll {
            components.append("--force-all")
        }
        if keepIntermediateSrts {
            components.append("--keep-intermediate-srts")
        }
        if keepRawJSON {
            components.append("--keep-raw-json")
        }
        if keepTemp {
            components.append("--keep-temp")
        }
        if nonInteractive {
            components.append("--non-interactive")
        }
        if dryRun {
            components.append("--dry-run")
        }
        if manual {
            components.append("--manual")
        }

        return components
    }

    private func appendOption(_ flag: String, value: String, to components: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        components.append(flag)
        components.append(trimmed)
    }

    private func shellEscape(_ component: String) -> String {
        guard !component.isEmpty else { return "''" }

        let safeCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/:=")
        if component.unicodeScalars.allSatisfy({ safeCharacterSet.contains($0) }) {
            return component
        }

        return "'" + component.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private struct ExecutionLogSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isPresented: Bool
    @Binding var logText: String
    let statusText: String
    let isRunning: Bool
    let onStop: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Execution Log")
                        .font(.title3.weight(.semibold))

                    HStack(spacing: 10) {
                        StatusBadge(statusText: statusText, isRunning: isRunning)

                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if isRunning {
                        Button(role: .destructive) {
                            onStop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                    }

                    Button {
                        onCopy()
                    } label: {
                        Label("Copy Log", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))

                    Button("Clear") {
                        onClear()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .disabled(isRunning || logText.isEmpty)

                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .disabled(isRunning)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText.isEmpty ? "Nessun output ancora." : logText)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(logText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: colorScheme == .dark ? .textBackgroundColor : .controlBackgroundColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 10, y: 4)
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
                .onChange(of: logText) { _, _ in
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct ValidationMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private struct OutputDropZone: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let isTargeted: Bool
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, minHeight: 162)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    Color(nsColor: colorScheme == .dark ? .underPageBackgroundColor : .controlBackgroundColor)
                        .opacity(colorScheme == .dark ? 0.7 : 0.9)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isTargeted ? Color.accentColor.opacity(0.72) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    lineWidth: isTargeted ? 1.5 : 1
                )
        )
        .shadow(
            color: isTargeted ? Color.accentColor.opacity(0.15) : Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: isTargeted ? 10 : 5,
            y: isTargeted ? 5 : 2
        )
        .scaleEffect(isTargeted ? 1.006 : (isHovered ? 1.003 : 1.0))
        .animation(.easeOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

private struct OptionsSheet: View {
    @Binding var videoBasename: String
    @Binding var lessonTopic: String
    @Binding var terminologyContext: String
    @Binding var terminologyFile: String
    @Binding var roiMode: String
    @Binding var enhanceSlide: Bool
    @Binding var enhancePreset: String
    @Binding var chunkSize: String
    @Binding var subLangs: String
    @Binding var ytdlpMode: String
    @Binding var cookiesFromBrowser: String
    @Binding var model: String
    @Binding var temperature: String
    @Binding var maxOutputTokens: String
    @Binding var effort: String
    @Binding var verbosity: String
    @Binding var scriptVerbosity: String
    @Binding var llmVerbosity: String
    @Binding var promptFile: String
    @Binding var useDefaultConfig: Bool
    @Binding var configFile: String

    @Binding var skipDownload: Bool
    @Binding var skipSubs: Bool
    @Binding var skipScreenshots: Bool
    @Binding var skipLLM: Bool
    @Binding var skipPDF: Bool
    @Binding var fromStep: String
    @Binding var forceAll: Bool

    @Binding var keepIntermediateSrts: Bool
    @Binding var keepRawJSON: Bool
    @Binding var keepTemp: Bool
    @Binding var nonInteractive: Bool
    @Binding var dryRun: Bool
    @Binding var manual: Bool

    let onPickTerminologyFile: () -> Void
    let onPickPromptFile: () -> Void
    let onPickConfigFile: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Opzioni")
                    .font(.title3)
                    .fontWeight(.semibold)

                Group {
                    FieldHeader(title: "Video basename", description: "Nome base del video/file output senza estensione.")
                    TextField("es. lezione_capitolo_01", text: $videoBasename)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Lesson topic", description: "Override manuale dell'argomento della lezione.")
                    TextField("Argomento lezione", text: $lessonTopic)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Terminology context", description: "Contesto terminologico aggiuntivo passato al flusso LLM.")
                    TextField("Contesto terminologico", text: $terminologyContext)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Terminology file", description: "File di glossario da anteporre al contesto terminologico.")
                    HStack {
                        TextField("/percorso/glossario.txt", text: $terminologyFile)
                            .textFieldStyle(.roundedBorder)
                        Button("Scegli") { onPickTerminologyFile() }
                    }
                }

                Group {
                    FieldHeader(title: "ROI mode", description: "Sceglie se usare un'area condivisa o separata per il rilevamento slide.")
                    Picker("ROI mode", selection: $roiMode) {
                        Text("Default").tag("")
                        Text("shared").tag("shared")
                        Text("separate").tag("separate")
                    }
                    .pickerStyle(.menu)

                    Toggle(isOn: $enhanceSlide) {
                        OptionLabel(title: "--enhance-slide", description: "Abilita l'enhancement degli screenshot delle slide.")
                    }

                    FieldHeader(title: "Enhance preset", description: "Intensita dell'enhancement: mild, medium o strong.")
                    Picker("Enhance preset", selection: $enhancePreset) {
                        Text("Default").tag("")
                        Text("mild").tag("mild")
                        Text("medium").tag("medium")
                        Text("strong").tag("strong")
                    }
                    .pickerStyle(.menu)

                    FieldHeader(title: "Chunk size", description: "Numero di slide elaborate per chunk dal passaggio LLM.")
                    TextField("es. 20", text: $chunkSize)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Sub langs", description: "Lista lingue sottotitoli per yt-dlp, ad esempio en,it.")
                    TextField("es. en,it", text: $subLangs)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    FieldHeader(title: "yt-dlp mode", description: "Strategia per trovare ed eseguire yt-dlp.")
                    Picker("yt-dlp mode", selection: $ytdlpMode) {
                        Text("Default").tag("")
                        Text("auto").tag("auto")
                        Text("system").tag("system")
                        Text("fallback").tag("fallback")
                    }
                    .pickerStyle(.menu)

                    FieldHeader(title: "Cookies from browser", description: "Passa i cookie del browser selezionato a yt-dlp.")
                    TextField("es. chrome", text: $cookiesFromBrowser)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Model", description: "Modello usato dal wrapper chatgpt.")
                    TextField("es. gpt-4.1", text: $model)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Temperature", description: "Temperatura del modello LLM.")
                    TextField("es. 0.2", text: $temperature)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Max output tokens", description: "Limite massimo di token in output dal wrapper.")
                    TextField("es. 3000", text: $maxOutputTokens)
                        .textFieldStyle(.roundedBorder)

                    FieldHeader(title: "Effort", description: "Livello di effort richiesto al wrapper chatgpt.")
                    TextField("es. medium", text: $effort)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    FieldHeader(title: "Verbosity", description: "Livello verbosita generale dello script.")
                    Picker("Verbosity", selection: $verbosity) {
                        Text("Default").tag("")
                        Text("quiet").tag("quiet")
                        Text("normal").tag("normal")
                        Text("verbose").tag("verbose")
                        Text("debug").tag("debug")
                    }
                    .pickerStyle(.menu)

                    FieldHeader(title: "Script verbosity", description: "Alias esplicito di --verbosity.")
                    Picker("Script verbosity", selection: $scriptVerbosity) {
                        Text("Default").tag("")
                        Text("quiet").tag("quiet")
                        Text("normal").tag("normal")
                        Text("verbose").tag("verbose")
                        Text("debug").tag("debug")
                    }
                    .pickerStyle(.menu)

                    FieldHeader(title: "LLM verbosity", description: "Livello di dettaglio del passaggio LLM.")
                    Picker("LLM verbosity", selection: $llmVerbosity) {
                        Text("Default").tag("")
                        Text("low").tag("low")
                        Text("medium").tag("medium")
                        Text("high").tag("high")
                    }
                    .pickerStyle(.menu)

                    FieldHeader(title: "Prompt file", description: "Prompt custom completo al posto del built-in.")
                    HStack {
                        TextField("/percorso/prompt.txt", text: $promptFile)
                            .textFieldStyle(.roundedBorder)
                        Button("Scegli") { onPickPromptFile() }
                    }

                    Toggle(isOn: $useDefaultConfig) {
                        OptionLabel(title: "--config", description: "Usa il config di default config/slidescribe.conf.")
                    }

                    FieldHeader(title: "Config file", description: "Usa un file di configurazione esplicito.")
                    HStack {
                        TextField("/percorso/slidescribe.conf", text: $configFile)
                            .textFieldStyle(.roundedBorder)
                        Button("Scegli") { onPickConfigFile() }
                    }
                }

                Divider()

                Group {
                    Toggle(isOn: $skipDownload) {
                        OptionLabel(title: "--skip-download", description: "Salta il download del video.")
                    }
                    Toggle(isOn: $skipSubs) {
                        OptionLabel(title: "--skip-subs", description: "Salta il download dei sottotitoli.")
                    }
                    Toggle(isOn: $skipScreenshots) {
                        OptionLabel(title: "--skip-screenshots", description: "Salta Screenshot_grabber.")
                    }
                    Toggle(isOn: $skipLLM) {
                        OptionLabel(title: "--skip-llm", description: "Salta la pipeline LLM.")
                    }
                    Toggle(isOn: $skipPDF) {
                        OptionLabel(title: "--skip-pdf", description: "Salta la generazione PDF e DOCX.")
                    }

                    FieldHeader(title: "From step", description: "Fa partire la pipeline da screenshots, llm oppure pdf.")
                    Picker("From step", selection: $fromStep) {
                        Text("Default").tag("")
                        Text("screenshots").tag("screenshots")
                        Text("llm").tag("llm")
                        Text("pdf").tag("pdf")
                    }
                    .pickerStyle(.menu)

                    Toggle(isOn: $forceAll) {
                        OptionLabel(title: "--force-all", description: "Riesegue anche step con checkpoint gia presenti.")
                    }
                }

                Divider()

                Group {
                    Toggle(isOn: $keepIntermediateSrts) {
                        OptionLabel(title: "--keep-intermediate-srts", description: "Non elimina gli SRT intermedi.")
                    }
                    Toggle(isOn: $keepRawJSON) {
                        OptionLabel(title: "--keep-raw-json", description: "Salva il raw JSON del wrapper chatgpt.")
                    }
                    Toggle(isOn: $keepTemp) {
                        OptionLabel(title: "--keep-temp", description: "Conserva eventuali file temporanei futuri.")
                    }
                    Toggle(isOn: $nonInteractive) {
                        OptionLabel(title: "--non-interactive", description: "Disabilita domande interattive.")
                    }
                    Toggle(isOn: $dryRun) {
                        OptionLabel(title: "--dry-run", description: "Mostra config e piano senza eseguire.")
                    }
                    Toggle(isOn: $manual) {
                        OptionLabel(title: "--manual", description: "Mostra il manuale esteso.")
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 680)
    }
}

private struct FieldHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OptionLabel: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ToolbarPill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct IconOnlyButton: View {
    let icon: String
    let helpText: String
    var tint: Color = .primary
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 26)
                .background(isHovering ? Color.accentColor.opacity(0.1) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .scaleEffect(isPressed ? 0.97 : (isHovering ? 1.01 : 1.0))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

private struct StatusRow: View {
    let statusText: String
    let detailText: String
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 10) {
            StatusBadge(statusText: statusText, isRunning: isRunning)

            if !detailText.isEmpty {
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

private struct StatusBadge: View {
    let statusText: String
    let isRunning: Bool

    private var presentation: ExecutionStatusPresentation {
        ExecutionStatusPresentation(statusText: statusText, isRunning: isRunning)
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(presentation.dotColor)
                .frame(width: 7, height: 7)

            Text(presentation.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(presentation.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(presentation.fillColor)
        )
        .overlay(
            Capsule()
                .stroke(presentation.strokeColor, lineWidth: 1)
        )
    }
}

private struct ExecutionStatusPresentation {
    let label: String
    let dotColor: Color
    let fillColor: Color
    let strokeColor: Color
    let textColor: Color

    init(statusText: String, isRunning: Bool) {
        let normalized = statusText.lowercased()

        if isRunning || normalized.contains("running") {
            label = "Running"
            dotColor = .accentColor
            fillColor = Color.accentColor.opacity(0.12)
            strokeColor = Color.accentColor.opacity(0.22)
            textColor = .primary
        } else if normalized.contains("finished") {
            label = "Finished"
            dotColor = Color.green.opacity(0.9)
            fillColor = Color.green.opacity(0.11)
            strokeColor = Color.green.opacity(0.18)
            textColor = .primary
        } else if normalized.contains("stopped") {
            label = "Stopped"
            dotColor = Color.orange.opacity(0.9)
            fillColor = Color.orange.opacity(0.11)
            strokeColor = Color.orange.opacity(0.18)
            textColor = .primary
        } else if normalized.contains("failed") || normalized.contains("launch failed") {
            label = "Failed"
            dotColor = Color.red.opacity(0.9)
            fillColor = Color.red.opacity(0.1)
            strokeColor = Color.red.opacity(0.16)
            textColor = .primary
        } else {
            label = "Idle"
            dotColor = .secondary.opacity(0.9)
            fillColor = Color.secondary.opacity(0.1)
            strokeColor = Color.secondary.opacity(0.12)
            textColor = .secondary
        }
    }
}

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
}
