import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    private let floatingSidebarWidth: CGFloat = 350

    private enum VideoInputMode: String, CaseIterable, Identifiable {
        case youtubeURL
        case localFile

        var id: Self { self }
    }

    private enum RightPanelMode {
        case terminal
        case options
        case manual
    }

    private enum FocusedField: Hashable {
        case youtubeURL
    }

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: FocusedField?

    @State private var outputFolderPath: String = ""
    @State private var resolvedOutputFolderPath: String = ""
    @State private var videoInputMode: VideoInputMode = .youtubeURL
    @State private var inputURL: String = ""
    @State private var inputMKV: String = ""
    @State private var generatedCommand: String = ""
    @State private var feedbackMessage: String = ""
    @State private var executionErrorMessage: String = ""
    @State private var showExecutionError: Bool = false
    @State private var rightPanelMode: RightPanelMode = .terminal
    @State private var isDropTargeted: Bool = false
    @State private var isDropHovered: Bool = false
    @State private var isVideoFileDropTargeted: Bool = false

    @State private var executionLog: String = ""
    @State private var executionStatus: String = "Idle"
    @State private var runningProcess: Process?
    @State private var isRunning: Bool = false

    @State private var videoBasename: String = ""
    @State private var lessonTopic: String = ""
    @State private var terminologyContext: String = ""
    @State private var terminologyFile: String = ""
    @State private var roiMode: String = "shared"
    @State private var enhanceSlide: Bool = true
    @State private var enhancePreset: String = ""
    @State private var chunkSize: String = ""
    @State private var skipFirstSec: String = ""
    @State private var skipLastSec: String = ""
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
    @State private var summaryModel: String = ""
    @State private var promptFile: String = ""
    @State private var summaryPromptFile: String = ""
    @State private var useDefaultConfig: Bool = false
    @State private var configFile: String = ""

    @State private var skipDownload: Bool = false
    @State private var skipSubs: Bool = false
    @State private var skipScreenshots: Bool = false
    @State private var skipLLM: Bool = false
    @State private var skipSummary: Bool = false
    @State private var skipPDF: Bool = false
    @State private var fromStep: String = ""
    @State private var forceAll: Bool = false

    @State private var deleteIntermediateSrts: Bool = false
    @State private var deleteRawJSON: Bool = false
    @State private var deleteTemp: Bool = false
    @State private var dryRun: Bool = false
    @State private var manual: Bool = false
    @State private var manualOutput: String = ""
    @State private var manualStatus: String = "Ready"
    @State private var isManualLoading: Bool = false
    @State private var manualProcess: Process?

    var body: some View {
        ZStack(alignment: .topLeading) {
            WindowBackground()
                .ignoresSafeArea()

            mainPanel
                .padding(.leading, floatingSidebarWidth + 38)
                .padding(.trailing, 18)
                .padding(.vertical, 18)

            sidebar
                .padding(.leading, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
        }
        .frame(minWidth: 835, minHeight: 620)
        .background(shortcutCommands)
        .onReceive(NotificationCenter.default.publisher(for: .slideScribeCommand)) { notification in
            guard let action = notification.userInfo?[SlideScribeMenuAction.userInfoKey] as? SlideScribeMenuAction else {
                return
            }

            handleMenuAction(action)
        }
        .alert("Errore esecuzione", isPresented: $showExecutionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(executionErrorMessage)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 12) {
                        Spacer(minLength: 0)

                        HStack(spacing: 4) {
                            SidebarUtilityIconButton(
                                icon: "eye",
                                title: "Reveal in Finder",
                                tint: .primary,
                                isEnabled: !effectiveWorkdirPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && effectiveWorkdirValidationMessage == nil
                            ) {
                                openWorkdirInFinder()
                            }

                            SidebarUtilityIconButton(icon: "folder", title: "Choose working directory", tint: .primary) {
                                pickOutputFolder()
                            }

                            SidebarUtilityIconButton(icon: "slider.horizontal.3", title: "Options", tint: .primary) {
                                toggleOptionsPanel()
                            }

                            SidebarUtilityIconButton(icon: "arrow.counterclockwise", title: "Reset", tint: .primary) {
                                resetInputs()
                            }

                            SidebarUtilityIconButton(icon: "questionmark", title: "Show SlideScribe manual", tint: .primary) {
                                toggleManualPanel()
                            }
                        }
                    }
                    .padding(.bottom, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "Input video", subtitle: "Choose a YouTube link or a local MKV file for the workflow.")

                        Picker("Video source", selection: $videoInputMode) {
                            Text("YouTube URL").tag(VideoInputMode.youtubeURL)
                            Text("Local file").tag(VideoInputMode.localFile)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .font(.system(size: 12.5))

                        if videoInputMode == .youtubeURL {
                            TextField("Paste YouTube URL", text: $inputURL)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5))
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .youtubeURL)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(inputBackgroundColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(videoInputFieldBorderColor, lineWidth: 1)
                                )
                        } else {
                            HStack(spacing: 8) {
                                Text(inputMKVDisplayText)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(inputMKV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.primary.opacity(0.9))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button("Choose…") {
                                    pickInputMKV()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.075) : Color.white.opacity(0.86))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(videoInputFieldBorderColor, lineWidth: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color.accentColor.opacity(isVideoFileDropTargeted ? 0.55 : 0), lineWidth: 1.5)
                            )
                            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isVideoFileDropTargeted) { providers in
                                handleInputMKVDrop(providers: providers)
                            }
                        }

                        if shouldShowVideoInputWarning {
                            WarningMessage(text: activeVideoInputValidationMessage ?? "Invalid input")
                        }
                    }

                    Spacer(minLength: 2)

                    VStack(spacing: 8) {
                        Button {
                            runCommand()
                        } label: {
                            Label(isRunning ? "Running…" : "Run workflow", systemImage: isRunning ? "hourglass" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .keyboardShortcut("r", modifiers: [.command])
                        .disabled(isRunning || workdirValidationMessage != nil || activeVideoInputValidationMessage != nil)

                        Button {
                            generateCommand()
                        } label: {
                            Label("Generate command", systemImage: "wand.and.stars")
                                .font(.system(size: 12.5, weight: .medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .keyboardShortcut("g", modifiers: [.command])
                        .tint(.secondary)
                        .opacity(workdirValidationMessage != nil || activeVideoInputValidationMessage != nil ? 0.68 : 0.88)
                        .disabled(workdirValidationMessage != nil || activeVideoInputValidationMessage != nil)

                        if isRunning {
                            Button(role: .destructive) {
                                stopRunningProcess()
                            } label: {
                                Label("Stop process", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                            .keyboardShortcut(".", modifiers: [.command])
                        }
                    }

                    Spacer(minLength: 12)

                    compactCommandPreview

                    Spacer(minLength: 12)
                }
                .padding(20)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                StatusBadge(statusText: executionStatus, isRunning: isRunning)

                if !feedbackMessage.isEmpty {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: floatingSidebarWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            SidebarSurface(colorScheme: colorScheme)
        )
        .onHover { hovering in
            isDropHovered = hovering
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(sidebarStrokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, y: 8)
    }

    private var mainPanel: some View {
        ZStack {
            if rightPanelMode == .options {
                optionsPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if rightPanelMode == .manual {
                manualPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                terminalCard
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: rightPanelMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var optionsPanel: some View {
        OptionsSheet(
            videoBasename: $videoBasename,
            lessonTopic: $lessonTopic,
            terminologyContext: $terminologyContext,
            terminologyFile: $terminologyFile,
            roiMode: $roiMode,
            enhanceSlide: $enhanceSlide,
            enhancePreset: $enhancePreset,
            chunkSize: $chunkSize,
            skipFirstSec: $skipFirstSec,
            skipLastSec: $skipLastSec,
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
            summaryModel: $summaryModel,
            promptFile: $promptFile,
            summaryPromptFile: $summaryPromptFile,
            useDefaultConfig: $useDefaultConfig,
            configFile: $configFile,
            skipDownload: $skipDownload,
            skipSubs: $skipSubs,
            skipScreenshots: $skipScreenshots,
            skipLLM: $skipLLM,
            skipSummary: $skipSummary,
            skipPDF: $skipPDF,
            fromStep: $fromStep,
            forceAll: $forceAll,
            deleteIntermediateSrts: $deleteIntermediateSrts,
            deleteRawJSON: $deleteRawJSON,
            deleteTemp: $deleteTemp,
            dryRun: $dryRun,
            manual: $manual,
            onPickTerminologyFile: {
                terminologyFile = pickFilePath() ?? terminologyFile
            },
            onPickPromptFile: {
                promptFile = pickFilePath() ?? promptFile
            },
            onPickSummaryPromptFile: {
                summaryPromptFile = pickFilePath() ?? summaryPromptFile
            },
            onPickConfigFile: {
                configFile = pickFilePath() ?? configFile
            },
            onReset: {
                resetOptions()
            },
            onClose: {
                rightPanelMode = .terminal
            }
        )
    }

    private var manualPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelHeader(
                    title: "Manual",
                    subtitle: isManualLoading ? "Loading slidescribe --manual..." : manualStatus
                )

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        copyManualOutput()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(PanelToolbarIconButtonStyle())
                    .disabled(manualOutput.isEmpty)
                    .help("Copy manual output")

                    Button {
                        loadManualContent()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(PanelToolbarIconButtonStyle())
                    .disabled(isManualLoading)
                    .help("Reload manual")

                    Button {
                        rightPanelMode = .terminal
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(PanelToolbarIconButtonStyle())
                    .help("Close manual")
                }
            }
            .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .frame(height: 1)
                .padding(.horizontal, 8)

            ScrollView {
                Text(manualOutput.isEmpty ? "SlideScribe manual output will appear here." : manualOutput)
                    .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactCommandPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Command preview")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.68))

            ScrollView {
                Text(generatedCommand.isEmpty ? "The generated command will appear here once the input is valid or after pressing Generate command." : generatedCommand)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(generatedCommand.isEmpty ? Color.secondary : Color.primary.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
            }
            .frame(minHeight: 76, maxHeight: 96)
            .background(compactCommandWell)
        }
    }

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PanelHeader(
                    title: "Terminal",
                    subtitle: isRunning ? "Streaming live process output." : "Live process output and command logs."
                )

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        copyExecutionLog()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(PanelToolbarIconButtonStyle())
                    .disabled(executionLog.isEmpty)
                    .help("Copy terminal output")

                    Button {
                        clearExecutionLog()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(PanelToolbarIconButtonStyle())
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(isRunning || executionLog.isEmpty)
                    .help("Clear terminal output")
                }
            }
            .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .frame(height: 1)
                .padding(.horizontal, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(executionLog.isEmpty ? terminalPlaceholder : executionLog)
                        .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(executionLog.isEmpty ? Color.secondary : terminalForegroundColor)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(18)

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
                .onChange(of: executionLog) { _, _ in
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var terminalPlaceholder: String {
        """
        SlideScribe terminal is ready.

        - Choose a working directory in the sidebar
        - Paste a valid YouTube URL or choose a local MKV in Options
        - Generate the command or run the workflow

        Live process output will stream here.
        """
    }

    private var shortcutCommands: some View {
        Group {
            Button(action: handleOpenInputShortcut) {
                EmptyView()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button(action: pickOutputFolder) {
                EmptyView()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button(action: showOptionsPanel) {
                EmptyView()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button(action: switchToYouTubeInput) {
                EmptyView()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(action: switchToLocalFileInput) {
                EmptyView()
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button(action: focusYouTubeURLField) {
                EmptyView()
            }
            .keyboardShortcut("l", modifiers: [.command])
        }
        .hidden()
    }

    private func handleMenuAction(_ action: SlideScribeMenuAction) {
        switch action {
        case .openInput:
            handleOpenInputShortcut()
        case .openWorkdir:
            pickOutputFolder()
        case .toggleOptions:
            showOptionsPanel()
        case .runWorkflow:
            runCommand()
        case .stopWorkflow:
            stopRunningProcess()
        case .clearTerminal:
            clearExecutionLog()
        case .generateCommand:
            generateCommand()
        case .switchToYouTubeURL:
            switchToYouTubeInput()
        case .switchToLocalFile:
            switchToLocalFileInput()
        case .focusYouTubeURLField:
            focusYouTubeURLField()
        case .showManual:
            showManualPanel()
        }
    }

    private var outputFolderDisplayName: String {
        let effectivePath = effectiveWorkdirPath
        if effectivePath.isEmpty {
            return "Choose Working Directory"
        }
        return URL(fileURLWithPath: effectivePath).lastPathComponent
    }

    private var outputFolderHeroSubtitle: String {
        if let effectiveWorkdirValidationMessage {
            return effectiveWorkdirValidationMessage
        }
        return outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !resolvedOutputFolderPath.isEmpty
            ? "Workdir resolved from script output"
            : "Project workspace ready"
    }

    private var effectiveWorkdirPath: String {
        let explicitPath = outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitPath.isEmpty {
            return explicitPath
        }

        return resolvedOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveWorkdirValidationMessage: String? {
        validateDirectoryPath(effectiveWorkdirPath)
    }

    private var statusBadgeText: String {
        ExecutionStatusPresentation(statusText: executionStatus, isRunning: isRunning).label
    }

    private var workdirValidationMessage: String? {
        validateDirectoryPath(outputFolderPath)
    }

    private func validateDirectoryPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            return "The workdir must be an existing folder"
        }

        return nil
    }

    private var requiresYouTubeURL: Bool {
        videoInputMode == .youtubeURL && !(skipDownload && skipSubs)
    }

    private var inputMKVValidationMessage: String? {
        let trimmed = inputMKV.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory)
        if !exists || isDirectory.boolValue {
            return "The selected MKV file is no longer available"
        }

        if URL(fileURLWithPath: trimmed).pathExtension.lowercased() != "mkv" {
            return "Choose a valid MKV file"
        }

        return nil
    }

    private var urlValidationMessage: String? {
        guard videoInputMode == .youtubeURL else { return nil }

        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return requiresYouTubeURL ? "Paste a valid YouTube URL" : nil
        }

        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return "Invalid URL"
        }

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return nil
        }

        return "Use a YouTube URL"
    }

    private var activeVideoInputValidationMessage: String? {
        switch videoInputMode {
        case .youtubeURL:
            return urlValidationMessage
        case .localFile:
            let trimmed = inputMKV.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Choose a local MKV file"
            }
            return inputMKVValidationMessage
        }
    }

    private var shouldShowWorkdirWarning: Bool {
        !outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && workdirValidationMessage != nil
    }

    private var shouldShowVideoInputWarning: Bool {
        switch videoInputMode {
        case .youtubeURL:
            return !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && urlValidationMessage != nil
        case .localFile:
            return !inputMKV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && inputMKVValidationMessage != nil
        }
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.82)
    }

    private var videoInputFieldBorderColor: Color {
        let isInvalid: Bool
        switch videoInputMode {
        case .youtubeURL:
            isInvalid = !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && urlValidationMessage != nil
        case .localFile:
            isInvalid = !inputMKV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && inputMKVValidationMessage != nil
        }

        if !isInvalid {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        }
        return Color.orange.opacity(0.35)
    }

    private var inputMKVDisplayText: String {
        let trimmed = inputMKV.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No file selected" }
        return trimmed
    }

    private var workdirFieldBorderColor: Color {
        if workdirValidationMessage == nil || outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        }
        return Color.orange.opacity(0.35)
    }

    private var sidebarStrokeColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.55)
        }

        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.42)
    }

    private var commandWell: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private var compactCommandWell: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1)
            )
    }

    private var terminalWell: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(terminalBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(terminalStrokeColor, lineWidth: 1)
            )
    }

    private var terminalBackgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.32)
            : Color.black.opacity(0.90)
    }

    private var terminalStrokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.07)
    }

    private var terminalForegroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolderPath = url.path
        resolvedOutputFolderPath = ""
    }

    private func handleOpenInputShortcut() {
        switch videoInputMode {
        case .youtubeURL:
            focusYouTubeURLField()
        case .localFile:
            pickInputMKV()
        }
    }

    private func openWorkdirInFinder() {
        let trimmed = effectiveWorkdirPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url = URL(fileURLWithPath: trimmed)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func resetInputs() {
        outputFolderPath = ""
        resolvedOutputFolderPath = ""
        videoInputMode = .youtubeURL
        inputURL = ""
        generatedCommand = ""
        feedbackMessage = ""

        resetOptions()
    }

    private func resetOptions() {
        videoBasename = ""
        lessonTopic = ""
        terminologyContext = ""
        terminologyFile = ""
        inputMKV = ""
        roiMode = "shared"
        enhanceSlide = true
        enhancePreset = ""
        chunkSize = ""
        skipFirstSec = ""
        skipLastSec = ""
        subLangs = ""
        ytdlpMode = ""
        cookiesFromBrowser = ""
        model = ""
        temperature = ""
        maxOutputTokens = ""
        effort = ""
        verbosity = ""
        scriptVerbosity = ""
        llmVerbosity = ""
        summaryModel = ""
        promptFile = ""
        summaryPromptFile = ""
        useDefaultConfig = false
        configFile = ""

        skipDownload = false
        skipSubs = false
        skipScreenshots = false
        skipLLM = false
        skipSummary = false
        skipPDF = false
        fromStep = ""
        forceAll = false

        deleteIntermediateSrts = false
        deleteRawJSON = false
        deleteTemp = false
        dryRun = false
        manual = false
        videoInputMode = .youtubeURL
    }

    private func showOptionsPanel() {
        toggleOptionsPanel()
    }

    private func toggleOptionsPanel() {
        rightPanelMode = rightPanelMode == .options ? .terminal : .options
    }

    private func switchToYouTubeInput() {
        focusYouTubeURLField()
    }

    private func switchToLocalFileInput() {
        videoInputMode = .localFile
        focusedField = nil
    }

    private func pickFilePath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func pickInputMKV() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = UTType(filenameExtension: "mkv").map { [$0] } ?? []

        guard panel.runModal() == .OK, let path = panel.url?.path else {
            return
        }

        videoInputMode = .localFile
        inputMKV = path
    }

    private func focusYouTubeURLField() {
        videoInputMode = .youtubeURL

        DispatchQueue.main.async {
            focusedField = .youtubeURL
        }
    }

    private func handleInputMKVDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists, !isDirectory.boolValue, url.pathExtension.lowercased() == "mkv" else {
                return
            }

            DispatchQueue.main.async {
                videoInputMode = .localFile
                inputMKV = url.path
            }
        }

        return true
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
        guard workdirValidationMessage == nil, activeVideoInputValidationMessage == nil else {
            feedbackMessage = "Fix the workdir or video input before running."
            return
        }

        rightPanelMode = .terminal
        generatedCommand = buildCommandString()
        executionLog = ""
        if outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedOutputFolderPath = ""
        }
        executionStatus = "Running"
        isRunning = true
        feedbackMessage = "Execution in progress…"

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
                        feedbackMessage = "Command completed."
                    } else if exitCode == 15 {
                        executionStatus = "Stopped"
                        feedbackMessage = "Execution interrupted."
                    } else {
                        executionStatus = "Failed (exit \(exitCode))"
                        feedbackMessage = "Command failed."
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
            feedbackMessage = "Launch failed."
            appendToLog("\n[Launch error] \(error.localizedDescription)\n")
        }
    }

    private func generateCommand() {
        guard workdirValidationMessage == nil, activeVideoInputValidationMessage == nil else {
            feedbackMessage = "Fix the workdir or video input before generating the command."
            return
        }

        generatedCommand = buildCommandString()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedCommand, forType: .string)
        executionStatus = isRunning ? executionStatus : "Idle"
        feedbackMessage = "Command generated and copied to the clipboard."
    }

    private func stopRunningProcess() {
        runningProcess?.terminate()
        feedbackMessage = "Stopping process…"
    }

    private func appendToLog(_ text: String) {
        executionLog += text
        updateResolvedWorkdirFromLog()
    }

    private func updateResolvedWorkdirFromLog() {
        guard outputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let pattern = #"(?m)^\[[^\]]+\]\s+Cartella di lavoro:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(executionLog.startIndex..<executionLog.endIndex, in: executionLog)
        guard let match = regex.matches(in: executionLog, range: range).last,
              let pathRange = Range(match.range(at: 1), in: executionLog) else {
            return
        }

        let path = executionLog[pathRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        resolvedOutputFolderPath = path
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

    private func showManualPanel() {
        toggleManualPanel()
    }

    private func toggleManualPanel() {
        if rightPanelMode == .manual {
            rightPanelMode = .terminal
            return
        }

        rightPanelMode = .manual
        if manualOutput.isEmpty && !isManualLoading {
            loadManualContent()
        }
    }

    private func loadManualContent() {
        manualProcess?.terminate()
        manualOutput = ""
        manualStatus = "Loading manual..."
        isManualLoading = true

        do {
            manualProcess = try TerminalExecutor.execute(command: "slidescribe --manual") { event in
                switch event {
                case .stdout(let text), .stderr(let text):
                    manualOutput += text

                case .finished(let exitCode):
                    manualProcess = nil
                    isManualLoading = false
                    manualStatus = exitCode == 0 ? "slidescribe --manual" : "Manual failed (exit \(exitCode))"

                    if exitCode != 0 && manualOutput.isEmpty {
                        manualOutput = "[Process finished with exit code \(exitCode)]"
                    }
                }
            }
        } catch {
            manualProcess = nil
            isManualLoading = false
            manualStatus = "Manual launch failed"
            manualOutput = error.localizedDescription
        }
    }

    private func copyManualOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manualOutput, forType: .string)
    }

    private func buildCommandString() -> String {
        buildCommandComponents()
            .map(shellEscape)
            .joined(separator: " ")
    }

    private func buildCommandComponents() -> [String] {
        var components = ["slidescribe"]
        let localMKVPath = inputMKV.trimmingCharacters(in: .whitespacesAndNewlines)
        let youtubeURL = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)

        appendOption("--workdir", value: outputFolderPath, to: &components)
        if videoInputMode == .youtubeURL, !youtubeURL.isEmpty {
            appendOption("--youtube-url", value: youtubeURL, to: &components)
        } else if videoInputMode == .localFile, !localMKVPath.isEmpty {
            appendOption("--input-mkv", value: localMKVPath, to: &components)
            components.append("--whisper")
        }
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
        appendOption("--skip-first-sec", value: skipFirstSec, to: &components)
        appendOption("--skip-last-sec", value: skipLastSec, to: &components)
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
        appendOption("--summary-model", value: summaryModel, to: &components)
        appendOption("--prompt-file", value: promptFile, to: &components)
        appendOption("--summary-prompt-file", value: summaryPromptFile, to: &components)

        if useDefaultConfig {
            components.append("--config")
        }

        appendOption("--config-file", value: configFile, to: &components)

        if skipDownload { components.append("--skip-download") }
        if skipSubs { components.append("--skip-subs") }
        if skipScreenshots { components.append("--skip-screenshots") }
        if skipLLM { components.append("--skip-llm") }
        if skipSummary { components.append("--skip-summary") }
        if skipPDF { components.append("--skip-pdf") }

        appendOption("--from-step", value: fromStep, to: &components)

        if forceAll { components.append("--force-all") }
        if deleteIntermediateSrts { components.append("--delete-intermediate-srts") }
        if deleteRawJSON { components.append("--delete-raw-json") }
        if deleteTemp { components.append("--delete-temp") }
        if dryRun { components.append("--dry-run") }
        if manual { components.append("--manual") }

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

private struct WindowBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .windowBackground, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.accentColor.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct SidebarSurface: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .sidebar, blendingMode: .behindWindow)

            LinearGradient(
                colors: colorScheme == .dark
                ? [Color.white.opacity(0.045), Color.white.opacity(0.015)]
                : [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.015 : 0.05))
                .blendMode(.plusLighter)
        }
    }
}

private struct ContentCardBackground: View {
    let colorScheme: ColorScheme
    let emphasize: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(emphasize ? 0.76 : 0.68))

            RoundedRectangle(cornerRadius: 28)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05), radius: 14, y: 6)
    }
}

private struct SectionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SidebarHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let pathText: String
    let isTargeted: Bool
    let isHovered: Bool
    let isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isTargeted ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
                        .frame(width: 46, height: 46)

                    Image(systemName: isValid ? "folder.fill" : "folder.badge.plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isTargeted ? Color.accentColor : .primary)
                }

                Spacer(minLength: 0)

                if isValid {
                    MiniStatusPill(text: "Ready", tint: .green)
                } else {
                    MiniStatusPill(text: "Required", tint: .orange)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !pathText.isEmpty {
                Text(pathText)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.60))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isTargeted ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.06), lineWidth: isTargeted ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04), radius: 12, y: 5)
        .scaleEffect(isTargeted ? 1.01 : (isHovered ? 1.004 : 1))
        .animation(.easeOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

private struct SidebarUtilityIconButton: View {
    let icon: String
    let title: String
    let tint: Color
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovering = false
    @State private var isShowingTooltip = false
    @State private var tooltipTask: DispatchWorkItem?

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : .secondary)
                .frame(width: 26, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(SidebarIconButtonStyle())
        .disabled(!isEnabled)
        .overlay(alignment: .bottomTrailing) {
            if isShowingTooltip {
                TooltipBubble(text: title)
                    .allowsHitTesting(false)
                    .offset(x: 6, y: 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .contentShape(Rectangle())
        .zIndex(isShowingTooltip ? 1 : 0)
        .onHover { hovering in
            isHovering = hovering
            tooltipTask?.cancel()

            if hovering {
                let task = DispatchWorkItem {
                    guard isHovering else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        isShowingTooltip = true
                    }
                }
                tooltipTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: task)
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    isShowingTooltip = false
                }
            }
        }
        .onDisappear {
            tooltipTask?.cancel()
        }
    }
}

private struct SidebarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.07) : Color.primary.opacity(0.022))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.035), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            .fixedSize()
    }
}

private struct PanelHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.72))
        }
    }
}

private struct PanelToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.045), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct MiniStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
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

private struct WarningMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.red)
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
    @Binding var skipFirstSec: String
    @Binding var skipLastSec: String
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
    @Binding var summaryModel: String
    @Binding var promptFile: String
    @Binding var summaryPromptFile: String
    @Binding var useDefaultConfig: Bool
    @Binding var configFile: String

    @Binding var skipDownload: Bool
    @Binding var skipSubs: Bool
    @Binding var skipScreenshots: Bool
    @Binding var skipLLM: Bool
    @Binding var skipSummary: Bool
    @Binding var skipPDF: Bool
    @Binding var fromStep: String
    @Binding var forceAll: Bool

    @Binding var deleteIntermediateSrts: Bool
    @Binding var deleteRawJSON: Bool
    @Binding var deleteTemp: Bool
    @Binding var dryRun: Bool
    @Binding var manual: Bool

    let onPickTerminologyFile: () -> Void
    let onPickPromptFile: () -> Void
    let onPickSummaryPromptFile: () -> Void
    let onPickConfigFile: () -> Void
    let onReset: () -> Void
    let onClose: () -> Void

    @State private var searchText: String = ""

    private var normalizedSearchText: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private var isSearching: Bool {
        !normalizedSearchText.isEmpty
    }

    private func matchesSearch(_ values: String...) -> Bool {
        guard isSearching else { return true }

        let haystack = values.joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return haystack.contains(normalizedSearchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PanelHeader(
                        title: "Options",
                        subtitle: "Advanced pipeline settings and execution behavior."
                    )

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        Button {
                            onReset()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(PanelToolbarIconButtonStyle())

                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .buttonStyle(PanelToolbarIconButtonStyle())

                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(PanelToolbarIconButtonStyle())
                    }
                }
                .padding(.bottom, 4)

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search options or flags", text: $searchText)
                        .textFieldStyle(.plain)

                    if isSearching {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                if matchesSearch("Content", "Metadata, lesson context, and terminology overrides.", "video basename", "lesson topic", "terminology context", "terminology file") {
                    OptionsSection(title: "Content", subtitle: "Metadata, lesson context, and terminology overrides.") {
                        if matchesSearch("Video basename", "Base name used for the video and generated files.", "--video-basename") {
                            OptionFieldBlock(title: "Video basename", description: "Base name used for the video and generated files.", flag: "--video-basename") {
                                TextField("e.g. lesson_chapter_01", text: $videoBasename)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Lesson topic", "Lesson topic with manual override.", "--lesson-topic") {
                            OptionFieldBlock(title: "Lesson topic", description: "Lesson topic with manual override.", flag: "--lesson-topic") {
                                TextField("Lesson topic", text: $lessonTopic)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Terminology context", "Additional terminology context passed into the workflow.", "--terminology-context") {
                            OptionFieldBlock(title: "Terminology context", description: "Additional terminology context passed into the workflow.", flag: "--terminology-context") {
                                TextField("Terminology context", text: $terminologyContext)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Terminology file", "Glossary or terminology file prepended to the context.", "--terminology-file", "glossary") {
                            FilePickerField(
                                title: "Terminology file",
                                description: "Glossary or terminology file prepended to the context.",
                                flag: "--terminology-file",
                                text: $terminologyFile,
                                placeholder: "/path/to/glossary.txt",
                                buttonTitle: "Choose",
                                action: onPickTerminologyFile
                            )
                        }
                    }
                }

                if matchesSearch("Image Processing", "Slide detection and screenshot enhancement.", "roi mode", "enhance", "skip first", "skip last") {
                    OptionsSection(title: "Image Processing", subtitle: "Slide detection and screenshot enhancement.") {
                        if matchesSearch("ROI mode", "Use a shared or separate region for slide detection.", "--roi-mode", "shared", "separate") {
                            OptionFieldBlock(title: "ROI mode", description: "Use a shared or separate region for slide detection.", flag: "--roi-mode") {
                                Picker("", selection: $roiMode) {
                                    Text("Default").tag("")
                                    Text("shared").tag("shared")
                                    Text("separate").tag("separate")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Enhance slide screenshots", "Enable automatic enhancement for slide screenshots.", "--enhance-slide") {
                            ToggleOptionRow(
                                title: "Enhance slide screenshots",
                                description: "Enable automatic enhancement for slide screenshots.",
                                flag: "--enhance-slide",
                                isOn: $enhanceSlide
                            )
                        }

                        if matchesSearch("Enhance preset", "Enhancement intensity applied to screenshots.", "--enhance-preset", "mild", "medium", "strong") {
                            OptionFieldBlock(title: "Enhance preset", description: "Enhancement intensity applied to screenshots.", flag: "--enhance-preset") {
                                Picker("", selection: $enhancePreset) {
                                    Text("Default").tag("")
                                    Text("mild").tag("mild")
                                    Text("medium").tag("medium")
                                    Text("strong").tag("strong")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Skip first seconds", "Skip the first N seconds of the video during the screenshot step.", "--skip-first-sec") {
                            OptionFieldBlock(title: "Skip first seconds", description: "Skip the first N seconds of the video during the screenshot step.", flag: "--skip-first-sec") {
                                TextField("e.g. 15", text: $skipFirstSec)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Skip last seconds", "Exclude the last N seconds of the video during the screenshot step.", "--skip-last-sec") {
                            OptionFieldBlock(title: "Skip last seconds", description: "Exclude the last N seconds of the video during the screenshot step.", flag: "--skip-last-sec") {
                                TextField("e.g. 10", text: $skipLastSec)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }

                if matchesSearch("Download & AI", "Subtitles, yt-dlp behavior, and model tuning.", "subtitle", "yt-dlp", "model", "summary", "prompt", "llm") {
                    OptionsSection(title: "Download & AI", subtitle: "Subtitles, yt-dlp behavior, and model tuning.") {
                        if matchesSearch("Subtitle languages", "Subtitle language list passed to yt-dlp.", "--sub-langs") {
                            OptionFieldBlock(title: "Subtitle languages", description: "Subtitle language list passed to yt-dlp.", flag: "--sub-langs") {
                                TextField("e.g. en,it", text: $subLangs)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("yt-dlp mode", "Strategy used to locate and run yt-dlp.", "--ytdlp-mode", "auto", "system", "fallback") {
                            OptionFieldBlock(title: "yt-dlp mode", description: "Strategy used to locate and run yt-dlp.", flag: "--ytdlp-mode") {
                                Picker("", selection: $ytdlpMode) {
                                    Text("Default").tag("")
                                    Text("auto").tag("auto")
                                    Text("system").tag("system")
                                    Text("fallback").tag("fallback")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Cookies from browser", "Pass browser cookies through to yt-dlp.", "--cookies-from-browser") {
                            OptionFieldBlock(title: "Cookies from browser", description: "Pass browser cookies through to yt-dlp.", flag: "--cookies-from-browser") {
                                TextField("e.g. chrome", text: $cookiesFromBrowser)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Chunk size", "Number of slides processed per LLM chunk.", "--chunk-size") {
                            OptionFieldBlock(title: "Chunk size", description: "Number of slides processed per LLM chunk.", flag: "--chunk-size") {
                                TextField("e.g. 20", text: $chunkSize)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Model", "Model used by the chatgpt wrapper.", "--model") {
                            OptionFieldBlock(title: "Model", description: "Model used by the chatgpt wrapper.", flag: "--model") {
                                TextField("e.g. gpt-4.1", text: $model)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Temperature", "Temperature used by the chatgpt wrapper.", "--temperature") {
                            OptionFieldBlock(title: "Temperature", description: "Temperature used by the chatgpt wrapper.", flag: "--temperature") {
                                TextField("e.g. 0.2", text: $temperature)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Max output tokens", "Maximum output token limit for the wrapper.", "--max-output-tokens") {
                            OptionFieldBlock(title: "Max output tokens", description: "Maximum output token limit for the wrapper.", flag: "--max-output-tokens") {
                                TextField("e.g. 3000", text: $maxOutputTokens)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Effort", "Effort level requested from the chatgpt wrapper.", "--effort") {
                            OptionFieldBlock(title: "Effort", description: "Effort level requested from the chatgpt wrapper.", flag: "--effort") {
                                TextField("e.g. medium", text: $effort)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("LLM verbosity", "Detail level used for the LLM step.", "--llm-verbosity", "low", "medium", "high") {
                            OptionFieldBlock(title: "LLM verbosity", description: "Detail level used for the LLM step.", flag: "--llm-verbosity") {
                                Picker("", selection: $llmVerbosity) {
                                    Text("Default").tag("")
                                    Text("low").tag("low")
                                    Text("medium").tag("medium")
                                    Text("high").tag("high")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Summary model", "Model used only for the final summary.", "--summary-model", "summary") {
                            OptionFieldBlock(title: "Summary model", description: "Model used only for the final summary.", flag: "--summary-model") {
                                TextField("e.g. gpt-4.1-mini", text: $summaryModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if matchesSearch("Prompt file", "Use a complete custom prompt instead of the built-in one.", "--prompt-file") {
                            FilePickerField(
                                title: "Prompt file",
                                description: "Use a complete custom prompt instead of the built-in one.",
                                flag: "--prompt-file",
                                text: $promptFile,
                                placeholder: "/path/to/prompt.txt",
                                buttonTitle: "Choose",
                                action: onPickPromptFile
                            )
                        }

                        if matchesSearch("Summary prompt file", "Custom prompt used only for the final summary.", "--summary-prompt-file", "summary") {
                            FilePickerField(
                                title: "Summary prompt file",
                                description: "Custom prompt used only for the final summary.",
                                flag: "--summary-prompt-file",
                                text: $summaryPromptFile,
                                placeholder: "/path/to/summary-prompt.txt",
                                buttonTitle: "Choose",
                                action: onPickSummaryPromptFile
                            )
                        }
                    }
                }

                if matchesSearch("Configuration", "Verbosity, prompt customization, and config sources.", "verbosity", "config") {
                    OptionsSection(title: "Configuration", subtitle: "Verbosity, prompt customization, and config sources.") {
                        if matchesSearch("Verbosity", "Overall verbosity level for the script.", "--verbosity", "quiet", "normal", "verbose", "debug") {
                            OptionFieldBlock(title: "Verbosity", description: "Overall verbosity level for the script.", flag: "--verbosity") {
                                Picker("", selection: $verbosity) {
                                    Text("Default").tag("")
                                    Text("quiet").tag("quiet")
                                    Text("normal").tag("normal")
                                    Text("verbose").tag("verbose")
                                    Text("debug").tag("debug")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Script verbosity", "Explicit alias for the general verbosity setting.", "--script-verbosity", "quiet", "normal", "verbose", "debug") {
                            OptionFieldBlock(title: "Script verbosity", description: "Explicit alias for the general verbosity setting.", flag: "--script-verbosity") {
                                Picker("", selection: $scriptVerbosity) {
                                    Text("Default").tag("")
                                    Text("quiet").tag("quiet")
                                    Text("normal").tag("normal")
                                    Text("verbose").tag("verbose")
                                    Text("debug").tag("debug")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Use default config", "Use the built-in config at config/slidescribe.conf.", "--config") {
                            ToggleOptionRow(
                                title: "Use default config",
                                description: "Use the built-in config at config/slidescribe.conf.",
                                flag: "--config",
                                isOn: $useDefaultConfig
                            )
                        }

                        if matchesSearch("Config file", "Use an explicit config file.", "--config-file") {
                            FilePickerField(
                                title: "Config file",
                                description: "Use an explicit config file.",
                                flag: "--config-file",
                                text: $configFile,
                                placeholder: "/path/to/slidescribe.conf",
                                buttonTitle: "Choose",
                                action: onPickConfigFile
                            )
                        }
                    }
                }

                if matchesSearch("Pipeline Control", "Skip parts of the workflow or restart from a specific step.", "skip", "from step", "summary", "force all") {
                    OptionsSection(title: "Pipeline Control", subtitle: "Skip parts of the workflow or restart from a specific step.") {
                        if matchesSearch("Skip video download", "Skip downloading the video.", "--skip-download") {
                            ToggleOptionRow(
                                title: "Skip video download",
                                description: "Skip downloading the video.",
                                flag: "--skip-download",
                                isOn: $skipDownload
                            )
                        }

                        if matchesSearch("Skip subtitles", "Skip downloading subtitles.", "--skip-subs") {
                            ToggleOptionRow(
                                title: "Skip subtitles",
                                description: "Skip downloading subtitles.",
                                flag: "--skip-subs",
                                isOn: $skipSubs
                            )
                        }

                        if matchesSearch("Skip screenshots", "Skip the screenshot extraction step.", "--skip-screenshots") {
                            ToggleOptionRow(
                                title: "Skip screenshots",
                                description: "Skip the screenshot extraction step.",
                                flag: "--skip-screenshots",
                                isOn: $skipScreenshots
                            )
                        }

                        if matchesSearch("Skip LLM pipeline", "Skip the LLM pipeline.", "--skip-llm") {
                            ToggleOptionRow(
                                title: "Skip LLM pipeline",
                                description: "Skip the LLM pipeline.",
                                flag: "--skip-llm",
                                isOn: $skipLLM
                            )
                        }

                        if matchesSearch("Skip final summary", "Skip the final summary generated from slide_texts.json.", "--skip-summary", "summary") {
                            ToggleOptionRow(
                                title: "Skip final summary",
                                description: "Skip the final summary generated from slide_texts.json.",
                                flag: "--skip-summary",
                                isOn: $skipSummary
                            )
                        }

                        if matchesSearch("Skip PDF and DOCX export", "Skip PDF and DOCX generation.", "--skip-pdf") {
                            ToggleOptionRow(
                                title: "Skip PDF and DOCX export",
                                description: "Skip PDF and DOCX generation.",
                                flag: "--skip-pdf",
                                isOn: $skipPDF
                            )
                        }

                        if matchesSearch("Start from step", "Start the pipeline from an intermediate step.", "--from-step", "screenshots", "llm", "pdf") {
                            OptionFieldBlock(title: "Start from step", description: "Start the pipeline from an intermediate step.", flag: "--from-step") {
                                Picker("", selection: $fromStep) {
                                    Text("Default").tag("")
                                    Text("screenshots").tag("screenshots")
                                    Text("llm").tag("llm")
                                    Text("pdf").tag("pdf")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if matchesSearch("Force all steps", "Re-run steps even when checkpoints already exist.", "--force-all") {
                            ToggleOptionRow(
                                title: "Force all steps",
                                description: "Re-run steps even when checkpoints already exist.",
                                flag: "--force-all",
                                isOn: $forceAll
                            )
                        }
                    }
                }

                if matchesSearch("Cleanup & Debug", "Cleanup behavior, diagnostics, and execution inspection.", "delete", "dry run", "manual") {
                    OptionsSection(title: "Cleanup & Debug", subtitle: "Cleanup behavior, diagnostics, and execution inspection.") {
                        if matchesSearch("Delete intermediate SRT files", "Delete intermediate SRT files at the end of the pipeline.", "--delete-intermediate-srts") {
                            ToggleOptionRow(
                                title: "Delete intermediate SRT files",
                                description: "Delete intermediate SRT files at the end of the pipeline.",
                                flag: "--delete-intermediate-srts",
                                isOn: $deleteIntermediateSrts
                            )
                        }

                        if matchesSearch("Delete raw JSON output", "Delete raw JSON output from the chatgpt wrapper at the end of the pipeline.", "--delete-raw-json") {
                            ToggleOptionRow(
                                title: "Delete raw JSON output",
                                description: "Delete raw JSON output from the chatgpt wrapper at the end of the pipeline.",
                                flag: "--delete-raw-json",
                                isOn: $deleteRawJSON
                            )
                        }

                        if matchesSearch("Delete temporary files", "Delete temporary files managed by the pipeline.", "--delete-temp") {
                            ToggleOptionRow(
                                title: "Delete temporary files",
                                description: "Delete temporary files managed by the pipeline.",
                                flag: "--delete-temp",
                                isOn: $deleteTemp
                            )
                        }

                        if matchesSearch("Dry run", "Show the config and plan without executing.", "--dry-run") {
                            ToggleOptionRow(
                                title: "Dry run",
                                description: "Show the config and plan without executing.",
                                flag: "--dry-run",
                                isOn: $dryRun
                            )
                        }

                        if matchesSearch("Extended manual mode", "Request the extended manual in the CLI.", "--manual") {
                            ToggleOptionRow(
                                title: "Extended manual mode",
                                description: "Request the extended manual in the CLI.",
                                flag: "--manual",
                                isOn: $manual
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct OptionsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: 28, height: 3)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.68))
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .controlSize(.small)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct OptionFieldBlock<Content: View>: View {
    let title: String
    let description: String
    let flag: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.74))

                if let flag, !flag.isEmpty {
                    Text(flag)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.56))
                }
            }

            content
        }
    }
}

private struct FilePickerField: View {
    let title: String
    let description: String
    let flag: String
    @Binding var text: String
    let placeholder: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        OptionFieldBlock(title: title, description: description, flag: flag) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)

                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

private struct ToggleOptionRow: View {
    let title: String
    let description: String
    let flag: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.74))
                Text(flag)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.56))
            }
        }
        .toggleStyle(.checkbox)
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
