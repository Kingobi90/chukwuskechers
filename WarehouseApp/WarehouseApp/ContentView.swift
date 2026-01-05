import SwiftUI

struct ContentView: View {
    @EnvironmentObject var apiService: APIService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            WorkflowView()
                .tabItem {
                    Label("Workflow", systemImage: "arrow.triangle.branch")
                }
                .tag(1)
            
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "list.bullet")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(.primary)
    }
}

struct HomeView: View {
    @State private var showingSeasonalDrop = false
    @State private var showingVisualShelves = false
    @State private var showingLocations = false
    @State private var showingSearch = false
    @State private var showingStatistics = false
    @State private var showingAnalytics = false
    @State private var showingBulkScan = false
    @State private var searchText = ""
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("SMAC Inventory System")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        HomeButton(
                            title: "Search",
                            icon: "magnifyingglass",
                            color: .black,
                            action: { showingSearch = true }
                        )
                        
                        HomeButton(
                            title: "Visual Shelves",
                            icon: "square.grid.3x3",
                            color: .black,
                            action: { showingVisualShelves = true }
                        )
                        
                        HomeButton(
                            title: "Locations",
                            icon: "building.2",
                            color: .black,
                            action: { showingLocations = true }
                        )
                        
                        HomeButton(
                            title: "Bulk Scan",
                            icon: "qrcode.viewfinder",
                            color: .black,
                            action: { showingBulkScan = true }
                        )
                        
                        HomeButton(
                            title: "Seasonal Drops",
                            icon: "calendar.badge.exclamationmark",
                            color: .black,
                            action: { showingSeasonalDrop = true }
                        )
                        
                        HomeButton(
                            title: "Analytics",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .black,
                            action: { showingAnalytics = true }
                        )
                        
                        HomeButton(
                            title: "Statistics",
                            icon: "chart.bar",
                            color: .black,
                            action: { showingStatistics = true }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSeasonalDrop) {
                SeasonalDropView()
            }
            .sheet(isPresented: $showingVisualShelves) {
                VisualShelvesView()
            }
            .sheet(isPresented: $showingLocations) {
                LocationsView()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(initialQuery: searchQuery)
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showingBulkScan) {
                BulkLocationScanView()
            }
        }
    }
}

struct HomeSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 2)
    }
}

struct CompactButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }
}

struct HomeButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(color)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Server")) {
                    HStack {
                        Text("Server URL")
                        Spacer()
                        Text("warehouse.obinnachukwu.org")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("App Info")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct WorkflowView: View {
    @State private var showingBulkScan = false
    @State private var showingBatchTagScan = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Workflow Management")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    VStack(spacing: 16) {
                        WorkflowCard(
                            title: "Bulk Location Scan",
                            description: "Quickly scan multiple items into a specific location",
                            icon: "qrcode.viewfinder",
                            color: .black,
                            action: { showingBulkScan = true }
                        )
                        
                        WorkflowCard(
                            title: "Batch Tag Scanner",
                            description: "Scan multiple tags and export to CSV",
                            icon: "barcode.viewfinder",
                            color: Color(.darkGray),
                            action: { showingBatchTagScan = true }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Workflow")
            .sheet(isPresented: $showingBulkScan) {
                BulkLocationScanView()
            }
            .sheet(isPresented: $showingBatchTagScan) {
                BatchTagScanView()
            }
        }
    }
}

struct WorkflowCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
