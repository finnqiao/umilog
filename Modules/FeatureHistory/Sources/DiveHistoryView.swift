import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit

public struct DiveHistoryView: View {
    @StateObject private var viewModel = DiveHistoryViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.dives.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredDives.isEmpty {
                // Fix UX-013: Add action CTA to empty state
                ContentUnavailableView {
                    Label("No Dives Found", systemImage: "fish")
                } description: {
                    Text(viewModel.searchText.isEmpty ? "Log your first dive to see it here" : "No dives match your search")
                } actions: {
                    if viewModel.searchText.isEmpty {
                        Button {
                            Haptics.soft()
                            NotificationCenter.default.post(name: .showLogLauncher, object: nil)
                        } label: {
                            Text("Start Logging")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.oceanBlue)
                    }
                }
            } else {
                List {
                    ForEach(viewModel.filteredDives) { dive in
                        NavigationLink {
                            DiveDetailView(dive: dive, site: viewModel.getSite(for: dive))
                        } label: {
                            DiveHistoryRow(dive: dive, site: viewModel.getSite(for: dive))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteDive(dive)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Dive History")
        .searchable(text: $viewModel.searchText, prompt: "Search dives, sites, or notes")
        .refreshable {
            await viewModel.refresh()
        }
    }
}

private struct DiveHistoryRow: View {
    let dive: DiveLog
    let site: DiveSite?
    
    private var isRecentlyLogged: Bool {
        // Check if dive was logged in the past 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return dive.date > sevenDaysAgo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let site = site {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name)
                            .font(.headline)
                        Text(site.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown Site")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isRecentlyLogged {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.seaGreen)
                            .cornerRadius(4)
                    }
                    
                    if dive.signed {
                        Image(systemName: "rosette")
                            .foregroundStyle(Color.seaGreen)
                    }
                }
            }
            
            // Stats
            HStack(spacing: 16) {
                Label(String(format: "%.1fm", dive.maxDepth), systemImage: "arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(Color.diveTeal)
                
                Label("\(dive.bottomTime)min", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Label(String(format: "%.0f°C", dive.temperature), systemImage: "thermometer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Date
            Text(formatDate(dive.date))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Notes preview
            if !dive.notes.isEmpty {
                Text(dive.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct DiveDetailView: View {
    let dive: DiveLog
    let site: DiveSite?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Site Info
                if let site = site {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(site.name)
                            .font(.title)
                            .bold()
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                            Text(site.location)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Dive Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dive Details")
                        .font(.headline)
                    
                    DetailRow(label: "Max Depth", value: String(format: "%.1f m", dive.maxDepth), icon: "arrow.down")
                    DetailRow(label: "Bottom Time", value: "\(dive.bottomTime) min", icon: "clock")
                    DetailRow(label: "Temperature", value: String(format: "%.0f°C", dive.temperature), icon: "thermometer")
                    DetailRow(label: "Visibility", value: String(format: "%.0f m", dive.visibility), icon: "eye")
                    DetailRow(label: "Current", value: dive.current.rawValue, icon: "wind")
                    DetailRow(label: "Conditions", value: dive.conditions.rawValue, icon: "sun.max")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Tank Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tank Pressure")
                        .font(.headline)
                    
                    DetailRow(label: "Start", value: "\(dive.startPressure) bar", icon: "gauge.high")
                    DetailRow(label: "End", value: "\(dive.endPressure) bar", icon: "gauge.low")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Notes
                if !dive.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(dive.notes)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Instructor
                if let instructor = dive.instructorName {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructor Sign-off")
                            .font(.headline)
                        HStack {
                            Image(systemName: dive.signed ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundStyle(dive.signed ? Color.seaGreen : Color.gray)
                            VStack(alignment: .leading) {
                                Text(instructor)
                                if let number = dive.instructorNumber {
                                    Text(number)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(formatDate(dive.date))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

#Preview {
    NavigationStack {
        DiveHistoryView()
    }
}
