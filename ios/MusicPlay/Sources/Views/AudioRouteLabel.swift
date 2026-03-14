import SwiftUI
import AVFoundation

struct AudioRouteLabel: View {
    @State private var routeName: String = "iPhone"
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            AirPlayButton()
                .frame(width: 18, height: 18)
            Text(routeName)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.8))
        .onAppear(perform: updateRoute)
        .onReceive(timer) { _ in updateRoute() }
    }
    
    private func updateRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        if let output = route.outputs.first {
            routeName = output.portName
        }
    }
}
