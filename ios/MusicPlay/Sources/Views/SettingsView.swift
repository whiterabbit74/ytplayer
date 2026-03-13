import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var cacheSize: UInt64 = AudioCacheService.shared.getCacheSize()

    private var cacheSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(cacheSize))
    }

    var body: some View {
        NavigationStack {
            List {
                if appState.isAuthenticated {
                    Section("Account") {
                        Button(role: .destructive) {
                            logout()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
                            }
                        }
                    }
                }
                
                Section("Server") {
                    Picker("Connection", selection: Binding(
                        get: { appState.serverType },
                        set: { appState.setServerType($0) }
                    )) {
                        ForEach(AppState.ServerType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if appState.serverType == .custom {
                        TextField("Server URL", text: Binding(
                            get: { appState.baseURL },
                            set: { appState.updateBaseURL($0) }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    } else {
                        HStack {
                            Text("Address")
                            Spacer()
                            Text(appState.baseURL)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Playback") {
                    Picker("Audio Quality", selection: Binding(
                        get: { appState.audioQuality },
                        set: { appState.updateAudioQuality($0) }
                    )) {
                        Text("High (Best m4a)").tag("high")
                        Text("Low (Data saver)").tag("low")
                    }
                    
                    Toggle("Crossfade", isOn: Binding(
                        get: { appState.crossfadeEnabled },
                        set: { appState.updateCrossfade(enabled: $0, duration: appState.crossfadeDuration) }
                    ))
                    
                    if appState.crossfadeEnabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text("\(Int(appState.crossfadeDuration))s")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { appState.crossfadeDuration },
                                set: { appState.updateCrossfade(enabled: appState.crossfadeEnabled, duration: $0) }
                            ), in: 2...12, step: 1)
                        }
                    }
                }
                
                Section("Display") {
                    Picker("Cover Style", selection: Binding(
                        get: { appState.coverStyle },
                        set: { appState.updateCoverStyle($0) }
                    )) {
                        ForEach(AppState.CoverStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Dynamic Background", isOn: Binding(
                        get: { appState.dynamicBackgroundEnabled },
                        set: { appState.updateDynamicBackground(enabled: $0) }
                    ))
                    .padding(.top, 4)
                }
                
                Section("Storage & Cache") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Audio Cache")
                            Text("Unlimited storage for streamed tracks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(cacheSizeString)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        AudioCacheService.shared.clearCache()
                        appState.downloadsStore.clearAll()
                    } label: {
                        Text("Clear All Downloads & Cache")
                    }
                }

                Section("Diagnostics") {
                    ConnectionStatusView()
                }

                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.2.5")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateCacheSize()
                NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadProgress"), object: nil, queue: .main) { _ in
                    updateCacheSize()
                }
                NotificationCenter.default.addObserver(forName: NSNotification.Name("CacheCleared"), object: nil, queue: .main) { _ in
                    updateCacheSize()
                }
            }
        }
    }

    private func updateCacheSize() {
        cacheSize = AudioCacheService.shared.getCacheSize()
    }

    private func logout() {
        Task {
            // Stop player and sync
            appState.playerSyncService.stop()
            appState.playerService.stop()
            appState.playerStore.clearQueue()
            
            try? await appState.apiClient.logout()
            await MainActor.run {
                appState.refreshAuthState()
                dismiss()
            }
        }
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTesting = false
    @State private var debugInfo: [String: String]?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                testConnection()
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .padding(.trailing, 5)
                    } else {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                    }
                    Text(isTesting ? "Testing..." : "Test Connection")
                        .fontWeight(.medium)
                }
            }
            .disabled(isTesting)

            if let info = debugInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Connection OK", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.bottom, 2)

                    ForEach(info.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key).foregroundStyle(.secondary)
                            Spacer()
                            Text(info[key] ?? "").font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .padding(.top, 5)
            } else if let error = error {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Connection Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 4)
    }

    private func testConnection() {
        isTesting = true
        debugInfo = nil
        error = nil
        
        let start = Date()
        let url = URL(string: appState.baseURL + "/api/health")!
        
        URLSession.shared.dataTask(with: url) { data, response, err in
            DispatchQueue.main.async {
                isTesting = false
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                
                if let err = err {
                    self.error = err.localizedDescription
                    return
                }
                
                if let httpRes = response as? HTTPURLResponse {
                    var info: [String: String] = [:]
                    info["Latency"] = "\(latency)ms"
                    info["Status"] = "\(httpRes.statusCode)"
                    info["Endpoint"] = url.absoluteString
                    
                    if let data = data, let str = String(data: data, encoding: .utf8) {
                        info["Response"] = str
                    }
                    
                    self.debugInfo = info
                }
            }
        }.resume()
    }
}
