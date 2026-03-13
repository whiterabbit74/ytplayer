import Foundation
import Combine

final class HistoryStore: ObservableObject {
    @Published var history: [Track] = []
    private let limit = 100
    private let storageKey = "musicplay_listening_history"
    private let ioQueue = DispatchQueue(label: "com.musicplay.history.io", qos: .background)
    
    init() {
        loadHistory()
    }
    
    func addTrack(_ track: Track) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Perform logic on background
            var currentHistory = self.history
            currentHistory.removeAll { $0.id == track.id }
            currentHistory.insert(track, at: 0)
            
            if currentHistory.count > self.limit {
                currentHistory.removeLast()
            }
            
            let data = try? JSONEncoder().encode(currentHistory)
            
            // Update state on main
            DispatchQueue.main.async {
                self.history = currentHistory
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
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            var currentHistory = self.history
            currentHistory.removeAll { $0.id == id }
            let data = try? JSONEncoder().encode(currentHistory)
            
            DispatchQueue.main.async {
                self.history = currentHistory
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
