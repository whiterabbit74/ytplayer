import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var animateItems = false

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [
                Color(hex: "0F172A"),
                Color(hex: "1E293B"),
                Color(hex: "020617")
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            // Animated background elements
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 400, height: 400)
                .offset(x: animateItems ? 150 : 250, y: animateItems ? -100 : -200)
                .blur(radius: 80)
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 300, height: 300)
                .offset(x: animateItems ? -150 : -250, y: animateItems ? 200 : 300)
                .blur(radius: 80)

            VStack(spacing: 32) {
                Spacer()
                
                // Logo & Title
                VStack(spacing: 12) {
                    Image(systemName: "music.note.curve")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        .scaleEffect(animateItems ? 1.0 : 0.8)
                    
                    Text("login_title")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(1)
                        .scaleEffect(animateItems ? 1.0 : 0.9)
                }
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                
                // Login Card
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        CustomTextField(
                            icon: "envelope.fill",
                            placeholder: NSLocalizedString("email_placeholder", comment: ""),
                            text: $email
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        
                        CustomSecureField(
                            icon: "lock.fill",
                            placeholder: NSLocalizedString("password_placeholder", comment: ""),
                            text: $password
                        )
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.system(size: 13, weight: .medium))
                            .padding(.top, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Button {
                        Task { await login() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("login_button")
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.blue, Color(hex: "4F46E5")], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    .scaleEffect(isLoading ? 0.98 : 1)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                
                Spacer()
                
                // Bottom Tools
                HStack(spacing: 20) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 20)
                .opacity(animateItems ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
                animateItems = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .injectEnvironment(appState: appState)
        }
    }

    @MainActor
    private func login() async {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        
        isLoading = true
        errorMessage = nil
        do {
            _ = try await appState.apiClient.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            appState.refreshAuthState()
        } catch {
            errorMessage = NSLocalizedString("error_login_failed", comment: "")
        }
        isLoading = false
    }
}

// MARK: - Components

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
