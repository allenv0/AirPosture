import SwiftUI
import Charts

// MARK: - View Model
@MainActor
class SessionHistoryViewModel: ObservableObject {
    @Published private(set) var visibleSessions: [SessionData] = []
    @Published private(set) var averagePoorPosture: Int = 0
    @Published private(set) var maxDuration: Double = 60
    @Published var selectedTimeframe: Timeframe = .week
    @Published var isLoading = false
    @Published var canLoadMore = true
    
    private var allSessions: [Session] = []
    private var currentPage = 0
    private let pageSize = 10
    private let sessionStore: SessionStore
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    init(sessionStore: SessionStore = .shared) {
        self.sessionStore = sessionStore
        loadSessions()
    }
    
    func loadSessions() {
        allSessions = sessionStore.sessions
        resetPagination()
    }
    
    func loadMoreSessions() async {
        guard !isLoading && canLoadMore else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate network/database fetch
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
        
        let filtered = filterSessions()
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, filtered.count)
        
        guard startIndex < endIndex else {
            await MainActor.run {
                canLoadMore = false
                isLoading = false
            }
            return
        }
        
        let newSessions = filtered[startIndex..<endIndex].map(SessionData.init)
        
        await MainActor.run {
            visibleSessions.append(contentsOf: newSessions)
            currentPage += 1
            canLoadMore = endIndex < filtered.count
            updateStats()
            isLoading = false
        }
    }
    
    func refreshSessions() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate network refresh
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        
        let filtered = filterSessions()
        let newSessions = Array(filtered.prefix(pageSize).map(SessionData.init))
        
        await MainActor.run {
            visibleSessions = newSessions
            currentPage = 1
            canLoadMore = filtered.count > pageSize
            updateStats()
            isLoading = false
        }
    }
    
    private func filterSessions() -> [Session] {
        let now = Date()
        let calendar = Calendar.current
        
        return allSessions.filter { session in
            switch selectedTimeframe {
            case .day: return calendar.isDateInToday(session.startTime)
            case .week: return calendar.dateComponents([.day], from: session.startTime, to: now).day ?? 0 <= 7
            case .month: return calendar.dateComponents([.month], from: session.startTime, to: now).month ?? 0 <= 1
            case .all: return true
            }
        }
    }
    
    private func updateStats() {
        guard !visibleSessions.isEmpty else {
            averagePoorPosture = 0
            maxDuration = 60
            return
        }
        
        // Calculate average poor posture percentage
        let total = visibleSessions.reduce(0) { $0 + $1.poorPosturePercentage }
        averagePoorPosture = total / visibleSessions.count
        
        // Find max duration for chart scaling
        maxDuration = (visibleSessions.map(\.totalDuration).max() ?? 60) * 1.2 // Add 20% padding
    }
    
    private func resetPagination() {
        currentPage = 0
        visibleSessions = []
        canLoadMore = true
    }
    
    func handleTimeframeChange() {
        resetPagination()
        Task {
            await refreshSessions()
        }
    }
}

// MARK: - Session Data Model
struct SessionData: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let totalDuration: TimeInterval
    let poorDuration: TimeInterval
    let poorPosturePercentage: Int
    let goodPosturePercentage: Int
    
    init(from session: Session) {
        self.id = session.id
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.totalDuration = session.totalDuration / 60 // Convert to minutes
        self.poorDuration = session.poorPostureDuration / 60 // Convert to minutes
        self.poorPosturePercentage = session.poorPosturePercentage
        self.goodPosturePercentage = 100 - session.poorPosturePercentage
    }
}

// MARK: - SessionHistoryView
struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            if viewModel.isLoading && viewModel.visibleSessions.isEmpty {
                loadingView
            } else if viewModel.visibleSessions.isEmpty {
                emptyStateView
            } else {
                sessionChartView
                    .refreshable {
                        await viewModel.refreshSessions()
                    }
                
                sessionListView
            }
        }
        .padding(.vertical)
        .onChange(of: viewModel.selectedTimeframe) { _ in
            viewModel.handleTimeframeChange()
        }
        .onAppear {
            Task {
                await viewModel.refreshSessions()
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session History")
                    .font(.title2.bold())
                
                Spacer()
                
                Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                    ForEach(SessionHistoryViewModel.Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if !viewModel.visibleSessions.isEmpty {
                Text("Average poor posture: \(viewModel.averagePoorPosture)%")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading sessions...")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No session data available")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
    }
    
    private var sessionChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Session Duration")
                    .font(.headline)
                
                Spacer()
                
                // Poor posture percentage display
                if let average = viewModel.visibleSessions.first?.poorPosturePercentage {
                    VStack(alignment: .center, spacing: 2) {
                        Text("POOR POSTURE")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(4)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(average)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                            Text("%")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .padding(.bottom, 4)
                        }
                        
                        Text("of your time")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 4)
            
            Chart {
                ForEach(viewModel.visibleSessions) { data in
                    // Good posture segment
                    BarMark(
                        x: .value("Good", data.totalDuration - data.poorDuration),
                        y: .value("Session", data.startTime, unit: .day)
                    )
                    .foregroundStyle(Color.green.opacity(0.7))
                    .accessibilityLabel("\(data.goodPosturePercentage)% good posture")
                    
                    // Poor posture segment
                    if data.poorDuration > 0 {
                        BarMark(
                            x: .value("Poor", data.poorDuration),
                            y: .value("Session", data.startTime, unit: .day)
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                        .accessibilityLabel("\(data.poorPosturePercentage)% poor posture")
                        .annotation(
                            position: .trailing,
                            spacing: 4,
                            overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                        ) {
                            Text("\(data.poorPosturePercentage)%")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                                .fixedSize()
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, style: .date)
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartXScale(domain: 0...(viewModel.maxDuration * 1.1))
            .frame(height: min(CGFloat(viewModel.visibleSessions.count) * 40 + 40, 400))
            .padding(.trailing, 8)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var sessionListView: some View {
        List {
            Section(header: Text("Recent Sessions")) {
                ForEach(viewModel.visibleSessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text("\(session.poorPosturePercentage)%")
                                .foregroundColor(session.poorPosturePercentage > 30 ? .red : .green)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("\(Int(session.totalDuration)) min total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(session.poorDuration)) min poor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .onAppear {
                        // Load more when reaching the end of the list
                        if session.id == viewModel.visibleSessions.last?.id {
                            Task {
                                await viewModel.loadMoreSessions()
                            }
                        }
                    }
                }
                
                if viewModel.isLoading && !viewModel.visibleSessions.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
//        .listStyle(.insetGrouped) // not supported on macOS, comment out for now
    }
}

#Preview {
    NavigationView {
        SessionHistoryView()
            .environmentObject(SessionStore())
    }
}
