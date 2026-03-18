import SwiftUI
import UmiCoreKit

/// Settings view for selecting preferred measurement units.
struct UnitPreferencesView: View {
    @AppStorage(UnitPreferenceKeys.temperatureUnit) private var tempUnit: String = TemperatureUnit.celsius.rawValue
    @AppStorage(UnitPreferenceKeys.distanceUnit) private var distUnit: String = DistanceUnit.meters.rawValue

    var body: some View {
        List {
            Section {
                Picker("Temperature", selection: $tempUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit.rawValue)
                    }
                }

                Picker("Depth & Visibility", selection: $distUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit.rawValue)
                    }
                }
            } header: {
                Text("Measurement Units")
            } footer: {
                Text("All data is stored in metric (°C, meters). Your preferred units are used for display and input.")
            }
        }
        .navigationTitle("Units")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        UnitPreferencesView()
    }
}
#endif
