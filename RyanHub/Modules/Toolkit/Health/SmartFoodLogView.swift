import SwiftUI
import PhotosUI

// MARK: - Smart Food Log View

/// AI-powered food logging — type what you ate in natural language or snap a photo.
/// Claude analyzes the food and estimates calories + macros automatically.
struct SmartFoodLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: HealthViewModel

    @State private var foodDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var analysisResult: FoodAnalysisResult?
    @State private var analysisService = FoodAnalysisService()
    @State private var showCamera = false
    @State private var date = Date()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    inputSection
                    if let image = selectedImage {
                        imagePreview(image)
                    }
                    if analysisService.isAnalyzing {
                        analyzingIndicator
                    }
                    if let error = analysisService.analysisError {
                        errorBanner(error)
                    }
                    if let result = analysisResult {
                        analysisResultView(result)
                    }
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hubPrimary)
                }
            }
            .onAppear { isInputFocused = true }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { await loadPhoto(newValue) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    selectedImage = image
                    Task { await analyzeCurrentInput() }
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "What did you eat?")

            // Natural language input
            VStack(spacing: 0) {
                TextField("e.g., 'Beef noodles and bubble tea' or '一碗牛肉面加一杯奶茶'",
                          text: $foodDescription, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // Action bar
                HStack(spacing: 12) {
                    // Photo picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }

                    // Camera
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }

                    Spacer()

                    // Date picker (compact)
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.hubPrimary)
                        .scaleEffect(0.85)

                    // Analyze button
                    Button {
                        Task { await analyzeCurrentInput() }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(
                                    canAnalyze
                                        ? Color.hubPrimary
                                        : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3)
                                )
                            )
                    }
                    .disabled(!canAnalyze || analysisService.isAnalyzing)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )

            Text("Describe your meal in any language. AI will estimate calories and nutrition.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private var canAnalyze: Bool {
        !foodDescription.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil
    }

    // MARK: - Image Preview

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius))

            Button {
                selectedImage = nil
                selectedPhoto = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .padding(8)
        }
    }

    // MARK: - Analyzing Indicator

    private var analyzingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.hubPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing your meal...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("AI is estimating calories and nutrition")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(Color.hubPrimary.opacity(0.08))
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.hubAccentYellow)
            Text(error)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.hubAccentYellow.opacity(0.1))
        )
    }

    // MARK: - Analysis Result

    private func analysisResultView(_ result: FoodAnalysisResult) -> some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Analysis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.hubPrimary)
                    Text(result.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.hubPrimary)
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(Color.hubPrimary.opacity(0.06))
            )

            // Calories + macros
            HStack(spacing: 12) {
                macroCard(label: "Calories", value: "\(result.totalCalories)", unit: "kcal", color: .hubAccentYellow)
                macroCard(label: "Protein", value: "\(result.totalProtein)", unit: "g", color: .hubAccentRed)
                macroCard(label: "Carbs", value: "\(result.totalCarbs)", unit: "g", color: .hubPrimary)
                macroCard(label: "Fat", value: "\(result.totalFat)", unit: "g", color: .hubAccentGreen)
            }

            // Individual items
            if result.items.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Items")
                    ForEach(result.items) { item in
                        itemRow(item)
                    }
                }
            }

            // Save button
            HubButton("Save Meal", icon: "checkmark.circle.fill") {
                saveMeal(result)
            }
        }
    }

    private func macroCard(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    private func itemRow(_ item: AnalyzedFoodItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.hubPrimary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(item.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            if let portion = item.portion {
                Text("(\(portion))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Text("\(item.calories) cal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.hubAccentYellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
    }

    // MARK: - Actions

    private func analyzeCurrentInput() async {
        isInputFocused = false
        if let image = selectedImage {
            let context = foodDescription.isEmpty ? nil : foodDescription
            analysisResult = await analysisService.analyzeImage(image, context: context)
        } else {
            analysisResult = await analysisService.analyzeText(foodDescription)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    private func saveMeal(_ result: FoodAnalysisResult) {
        viewModel.addFoodFromAnalysis(result, description: foodDescription, date: date)
        dismiss()
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    SmartFoodLogView(viewModel: HealthViewModel())
}
