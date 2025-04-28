import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Dashboard")
                }

            InsightsView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Insights")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Settings")
                }
        }
    }
}
