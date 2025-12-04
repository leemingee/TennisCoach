import SwiftUI

/// View for securely managing the Gemini API key.
///
/// This view provides a user interface for saving, updating, and deleting
/// the API key from the secure Keychain storage. It should be presented
/// during onboarding or in the app settings.
@available(iOS 15.0, macOS 12.0, *)
struct APIKeySetupView: View {

    // MARK: - State Properties

    @State private var apiKey: String = ""
    @State private var isKeyStored: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var isLoading: Bool = false
    @State private var showPassword: Bool = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                Section {
                    headerSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    apiKeyInputSection
                } header: {
                    Text("API Key")
                } footer: {
                    footerText
                }

                Section {
                    actionButtons
                }

                if isKeyStored {
                    Section {
                        deleteButton
                    } header: {
                        Text("Danger Zone")
                    }
                }
            }
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                checkKeyStatus()
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue.gradient)
                .padding(.top, 20)

            Text("Gemini API Key")
                .font(.title2)
                .fontWeight(.bold)

            Text("Securely stored in your device's Keychain")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var apiKeyInputSection: some View {
        HStack {
            if showPassword {
                TextField("Enter your API key", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } else {
                SecureField("Enter your API key", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private var footerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Get your API key from:")
                .font(.caption)

            Link("Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)

            if isKeyStored {
                Label("API key is stored securely", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Button {
                saveKey()
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(isKeyStored ? "Update API Key" : "Save API Key")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(apiKey.isEmpty || isLoading)

            if isKeyStored {
                Button {
                    testKey()
                } label: {
                    HStack {
                        Spacer()
                        Label("Test Connection", systemImage: "network")
                        Spacer()
                    }
                }
                .disabled(isLoading)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            deleteKey()
        } label: {
            HStack {
                Spacer()
                Label("Delete API Key", systemImage: "trash")
                Spacer()
            }
        }
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func checkKeyStatus() {
        isKeyStored = SecureKeyManager.shared.hasGeminiAPIKey()

        if isKeyStored {
            // Load the key to display (masked)
            if let storedKey = try? SecureKeyManager.shared.getGeminiAPIKey() {
                // Show only last 8 characters for security
                let maskLength = max(0, storedKey.count - 8)
                let maskedKey = String(repeating: "•", count: maskLength) + storedKey.suffix(8)
                apiKey = maskedKey
            }
        }
    }

    private func saveKey() {
        guard !apiKey.isEmpty else { return }

        isLoading = true

        Task {
            do {
                try SecureKeyManager.shared.saveGeminiAPIKey(apiKey)

                await MainActor.run {
                    isLoading = false
                    isKeyStored = true
                    alertTitle = "Success"
                    alertMessage = "API key has been securely saved to your Keychain."
                    showingAlert = true
                    apiKey = "" // Clear the field
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertTitle = "Error"
                    alertMessage = "Failed to save API key: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    private func deleteKey() {
        isLoading = true

        Task {
            do {
                try SecureKeyManager.shared.deleteGeminiAPIKey()

                await MainActor.run {
                    isLoading = false
                    isKeyStored = false
                    apiKey = ""
                    alertTitle = "Deleted"
                    alertMessage = "API key has been removed from your Keychain."
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertTitle = "Error"
                    alertMessage = "Failed to delete API key: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    private func testKey() {
        isLoading = true

        Task {
            let result = await validateAPIKey()

            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let modelName):
                    alertTitle = "Connection Successful ✓"
                    alertMessage = "API key is valid!\n\nConnected to: \(modelName)"
                case .failure(let error):
                    alertTitle = "Connection Failed ✗"
                    alertMessage = error.localizedDescription
                }
                showingAlert = true
            }
        }
    }

    /// Validates the API key by making a test request to the Gemini API
    private func validateAPIKey() async -> Result<String, APIKeyValidationError> {
        guard let storedKey = try? SecureKeyManager.shared.getGeminiAPIKey(),
              !storedKey.isEmpty else {
            return .failure(.noKeyStored)
        }

        // Use the models.list endpoint to validate the key
        // This is a lightweight call that just lists available models
        let urlString = "\(Constants.API.geminiBaseURL)/\(Constants.API.apiVersion)/models"

        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(storedKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            switch httpResponse.statusCode {
            case 200:
                // Parse response to get model info
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]],
                   let firstModel = models.first,
                   let modelName = firstModel["displayName"] as? String ?? firstModel["name"] as? String {
                    return .success("Gemini API (\(models.count) models available)")
                }
                return .success("Gemini API")

            case 400:
                return .failure(.badRequest)

            case 401, 403:
                return .failure(.invalidAPIKey)

            case 404:
                return .failure(.endpointNotFound)

            case 429:
                return .failure(.rateLimited)

            case 500...599:
                return .failure(.serverError(httpResponse.statusCode))

            default:
                return .failure(.httpError(httpResponse.statusCode))
            }

        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                return .failure(.noInternet)
            case .timedOut:
                return .failure(.timeout)
            default:
                return .failure(.networkError(error.localizedDescription))
            }
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }
}

// MARK: - API Key Validation Errors

enum APIKeyValidationError: LocalizedError {
    case noKeyStored
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case badRequest
    case endpointNotFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case noInternet
    case timeout
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noKeyStored:
            return "No API key found. Please save your API key first."
        case .invalidURL:
            return "Invalid API URL configuration."
        case .invalidResponse:
            return "Received invalid response from server."
        case .invalidAPIKey:
            return "API key is invalid or expired.\n\nPlease check your key at:\nhttps://aistudio.google.com/apikey"
        case .badRequest:
            return "Bad request. The API key format may be incorrect."
        case .endpointNotFound:
            return "API endpoint not found. The service may have changed."
        case .rateLimited:
            return "Rate limited. Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Google's servers may be temporarily unavailable."
        case .httpError(let code):
            return "HTTP error \(code). Please try again."
        case .noInternet:
            return "No internet connection.\n\nPlease check your network and try again."
        case .timeout:
            return "Connection timed out.\n\nPlease check your network and try again."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Preview

#Preview {
    APIKeySetupView()
}
