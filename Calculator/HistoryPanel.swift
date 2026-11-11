import SwiftUI

/// The history surface is intentionally independent of presentation so it can be
/// embedded beside the keypad on iPad or presented as a sheet on a narrow screen.
struct HistoryPanel: View {
    let history: [CalculatorModel.HistoryEntry]
    let onRecall: (CalculatorModel.HistoryEntry) -> Void
    let onDelete: (UUID) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    @State private var isEditing = false
    @State private var selection: Set<UUID> = []
    @State private var confirmsClear = false

    private struct DayGroup: Identifiable {
        let id: Date
        let title: String
        let entries: [CalculatorModel.HistoryEntry]
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        // Undated, migrated entries belong to a separate group, never a fabricated day.
        let buckets = Dictionary(grouping: history) { entry in
            entry.date.map { calendar.startOfDay(for: $0) } ?? .distantPast
        }
        return buckets.keys.sorted(by: >).map { day in
            let title: String
            if day == .distantPast { title = "Earlier" }
            else if calendar.isDateInToday(day) { title = "Today" }
            else if calendar.isDateInYesterday(day) { title = "Yesterday" }
            else { title = day.formatted(date: .abbreviated, time: .omitted) }
            return DayGroup(id: day, title: title, entries: buckets[day] ?? [])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    selection.removeAll()
                }
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(Capsule().fill(Color.white.opacity(0.025)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                .buttonStyle(.plain)
                .disabled(history.isEmpty)
                .accessibilityIdentifier("history.edit")

                Button(action: onClose) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 25, weight: .regular))
                }
                .buttonStyle(CalculatorToolbarButtonStyle(background: Color.white.opacity(0.025)))
                .accessibilityLabel("Close History")
                .accessibilityIdentifier("history.close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 44)

            if history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 32, weight: .light))
                    Text("No History").font(.title3)
                    Text("Your calculations will appear here.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            Text(group.title)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.38))
                                .padding(.top, group.id == groups.first?.id ? 0 : 44)
                                .padding(.bottom, 22)
                                .accessibilityAddTraits(.isHeader)
                            separator
                            ForEach(group.entries) { entry in
                                historyRow(entry)
                                separator
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }

            if isEditing && !history.isEmpty {
                HStack {
                    Button("Clear All", role: .destructive) { confirmsClear = true }
                        .accessibilityIdentifier("history.clearAll")
                    Spacer()
                    Button(selection.isEmpty ? "Delete" : "Delete (\(selection.count))", role: .destructive) {
                        selection.forEach(onDelete)
                        selection.removeAll()
                    }
                    .disabled(selection.isEmpty)
                    .accessibilityIdentifier("history.deleteSelected")
                }
                .font(.system(size: 16, weight: .medium))
                .padding(22)
                .background(Color.black.opacity(0.12))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color(red: 0.245, green: 0.235, blue: 0.22).opacity(0.94))
                .ignoresSafeArea()
        }
        .confirmationDialog("Clear all calculation history?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear All History", role: .destructive) {
                onClear()
                selection.removeAll()
                isEditing = false
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: history.map(\.id)) { _, ids in
            selection.formIntersection(Set(ids))
            if ids.isEmpty { isEditing = false }
        }
    }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.17)).frame(height: 1)
            .padding(.leading, 6)
    }

    private func historyRow(_ entry: CalculatorModel.HistoryEntry) -> some View {
        Button {
            if isEditing {
                if selection.contains(entry.id) { selection.remove(entry.id) }
                else { selection.insert(entry.id) }
            } else { onRecall(entry) }
        } label: {
            HStack(spacing: 12) {
                if isEditing {
                    Image(systemName: selection.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23))
                        .foregroundStyle(selection.contains(entry.id) ? Color.orange : Color.white.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.expression)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(formattedResult(entry.result))
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 6)
            .padding(.vertical, 21)
            .frame(minHeight: 90, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.expression) equals \(entry.result)")
        .accessibilityHint(isEditing ? "Select calculation" : "Recall calculation")
        .accessibilityAddTraits(selection.contains(entry.id) ? [.isSelected] : [])
        .contextMenu {
            Button("Recall", systemImage: "arrow.uturn.backward") { onRecall(entry) }
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(entry.id) }
        }
    }

    private func formattedResult(_ value: String) -> String {
        guard !value.lowercased().contains("e") else { return value }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard let whole = parts.first else { return value }
        let negative = whole.hasPrefix("-")
        let digits = negative ? String(whole.dropFirst()) : String(whole)
        guard digits.allSatisfy(\.isNumber) else { return value }
        let grouped = String(digits.reversed()).enumerated().map {
            ($0.offset > 0 && $0.offset % 3 == 0 ? "," : "") + String($0.element)
        }.joined()
        return (negative ? "−" : "") + String(grouped.reversed()) + (parts.count > 1 ? "." + parts[1] : "")
    }
}

/// Vector artwork avoids depending on a calculator SF Symbol that is absent on
/// some supported OS versions. Its proportions match the reference toolbar icon.
struct CalculatorModeGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let height = min(geometry.size.height, geometry.size.width * 1.45)
            let width = height * 0.69
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.17)
                    .fill(.white)
                VStack(spacing: height * 0.065) {
                    RoundedRectangle(cornerRadius: width * 0.065)
                        .fill(Color(white: 0.12))
                        .frame(height: height * 0.24)
                    VStack(spacing: height * 0.045) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: width * 0.065) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle().fill(Color(white: 0.12))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, width * 0.12)
                .padding(.vertical, height * 0.09)
            }
            .frame(width: width, height: height)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: 24, height: 28)
        .accessibilityHidden(true)
    }
}

struct CalculatorToolbarButtonStyle: ButtonStyle {
    var background: Color = Color(white: 0.13)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(background))
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.025), .white.opacity(0.13)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.8
                )
            }
            .brightness(configuration.isPressed ? 0.12 : 0)
            .contentShape(Circle())
    }
}
