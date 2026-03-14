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
                Section {
                    if appState.isAuthenticated {
                        Button(role: .destructive) {
                            logout()
                        } label: {
                            Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        NavigationLink {
                            LoginView()
                        } label: {
                            Label("Войти", systemImage: "person.crop.circle")
                        }
                    }
                } header: {
                    Text("Аккаунт")
                } footer: {
                    Text("Управление вашей учетной записью и доступом к библиотеке.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Тип сервера", selection: Binding(
                            get: { appState.serverType },
                            set: { appState.setServerType($0) }
                        )) {
                            ForEach(AppState.ServerType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                    }

                    if appState.serverType == .custom {
                        TextField("URL сервера", text: Binding(
                            get: { appState.baseURL },
                            set: { appState.updateBaseURL($0) }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    } else {
                        HStack {
                            Label("Адрес", systemImage: "network")
                            Spacer()
                            Text(appState.baseURL)
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } header: {
                    Text("Соединение")
                } footer: {
                    Text("Выберите, как приложение будет подключаться к вашему серверу музыки.")
                }

                Section {
                    Picker(selection: Binding(
                        get: { appState.audioQuality },
                        set: { appState.updateAudioQuality($0) }
                    )) {
                        Label("Высокое (m4a)", systemImage: "waveform.circle.fill").tag("high")
                        Label("Низкое (WebM)", systemImage: "waveform.circle").tag("low")
                    } label: {
                        Label("Качество звука", systemImage: "music.note.list")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: { appState.crossfadeEnabled },
                            set: { appState.updateCrossfade(enabled: $0, duration: appState.crossfadeDuration) }
                        )) {
                            Label("Кроссфейд", systemImage: "arrow.triangle.merge")
                        }
                        
                        if appState.crossfadeEnabled {
                            HStack {
                                Text("\(Int(appState.crossfadeDuration)) сек")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { appState.crossfadeDuration },
                                    set: { appState.updateCrossfade(enabled: appState.crossfadeEnabled, duration: $0) }
                                ), in: 2...12, step: 1)
                            }
                            .padding(.leading, 32)
                        }
                    }
                } header: {
                    Text("Воспроизведение")
                } footer: {
                    Text("Настройте качество звука и плавность переходов между треками.")
                }

                Section {
                    Picker(selection: Binding(
                        get: { appState.coverStyle },
                        set: { appState.updateCoverStyle($0) }
                    )) {
                        ForEach(AppState.CoverStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    } label: {
                        Label("Стиль обложки", systemImage: "photo.on.rectangle")
                    }

                    Toggle(isOn: Binding(
                        get: { appState.dynamicBackgroundEnabled },
                        set: { appState.updateDynamicBackground(enabled: $0) }
                    )) {
                        Label("Динамический фон", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Интерфейс")
                } footer: {
                    Text("Персонализируйте внешний вид плеера под ваш вкус.")
                }

                Section {
                    HStack {
                        Label("Занято место", systemImage: "internaldrive")
                        Spacer()
                        Text(cacheSizeString)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        AudioCacheService.shared.clearCache()
                        appState.downloadsStore.clearAll()
                    } label: {
                        Label("Очистить кеш и загрузки", systemImage: "trash")
                    }
                } header: {
                    Text("Хранилище")
                } footer: {
                    Text("Управление локальными файлами и временными данными.")
                }

                Section {
                    ConnectionStatusView()
                } header: {
                    Text("Диагностика")
                } footer: {
                    Text("Проверка стабильности связи с сервером.")
                }

                Section {
                    HStack {
                        Label("Версия", systemImage: "info.circle")
                        Spacer()
                        Text("1.2.5")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("О приложении")
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
