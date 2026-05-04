import SwiftUI

@main
struct FuelTrackerApp: App {
    @StateObject private var dataStore = DataStore()
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some Scene {
        WindowGroup {
            VehicleListView()
                .environmentObject(dataStore)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
