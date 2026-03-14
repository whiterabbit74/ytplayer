import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    @Published var history: [Track] = []
    private let limit = 100
    private let storageKey = "musicplay_listening_history"
    private let ioQueue = DispatchQueue(label: "com.musicplay.history.io", qos: .background)
    
    init() {
        loadHistory()
    }
    
    func addTrack(_ track: Track) {
        let currentHistory = self.history // Capture on main actor
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Perform logic on background using captured state
            var updatedHistory = currentHistory
            updatedHistory.removeAll { $0.id == track.id }
            updatedHistory.insert(track, at: 0)
            
            if updatedHistory.count > self.limit {
                updatedHistory.removeLast()
            }
            
            let data = try? JSONEncoder().encode(updatedHistory)
            
            // Update state on main
            DispatchQueue.main.async {
                self.history = updatedHistory
                if let data = data {
                    UserDefaults.standard.set(data, forKey: self.storageKey)
                }
            }
        }
    }
    
    func clearHistory() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.removeObject(forKey: self.storageKey)
            DispatchQueue.main.async {
                self.history.removeAll()
            }
        }
    }
    
    func removeTrack(id: String) {
        let currentHistory = self.history // Capture on main actor
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            var updatedHistory = currentHistory
            updatedHistory.removeAll { $0.id == id }
            let data = try? JSONEncoder().encode(updatedHistory)
            
            DispatchQueue.main.async {
                self.history = updatedHistory
                if let data = data {
                    UserDefaults.standard.set(data, forKey: self.storageKey)
                }
            }
        }
    }
    
    private func loadHistory() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let data = UserDefaults.standard.data(forKey: self.storageKey) else { return }
            do {
                let decoded = try JSONDecoder().decode([Track].self, from: data)
                DispatchQueue.main.async {
                    self.history = decoded
                }
            } catch {
                print("Failed to load history: \(error)")
            }
        }
    }
}
