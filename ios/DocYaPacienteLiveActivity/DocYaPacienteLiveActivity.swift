import ActivityKit
import SwiftUI
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable { }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

private let sharedDefaults = UserDefaults(suiteName: "group.com.docya.paciente.liveactivities")!

private func sharedString(_ context: ActivityViewContext<LiveActivitiesAppAttributes>, _ key: String, fallback: String = "") -> String {
    sharedDefaults.string(forKey: context.attributes.prefixedKey(key)) ?? fallback
}

private struct DocYaLiveActivityView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    private var profesional: String {
        sharedString(context, "professionalName", fallback: "Profesional asignado")
    }

    private var rol: String {
        sharedString(context, "professionalRole", fallback: "Profesional")
    }

    private var estado: String {
        sharedString(context, "statusText", fallback: "En camino")
    }

    private var direccion: String {
        sharedString(context, "address", fallback: "Direccion en curso")
    }

    private var eta: String {
        sharedString(context, "etaText", fallback: "Calculando")
    }

    private var distancia: String {
        sharedString(context, "distanceText", fallback: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.08, green: 0.72, blue: 0.65))
                        .frame(width: 40, height: 40)
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(estado)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(rol) • \(profesional)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                Label(eta, systemImage: "clock.fill")
                if !distancia.isEmpty {
                    Label(distancia, systemImage: "location.fill")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.08, green: 0.82, blue: 0.76))

            Text(direccion)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .padding(18)
        .activityBackgroundTint(Color(red: 0.06, green: 0.13, blue: 0.16))
        .activitySystemActionForegroundColor(.white)
    }
}

struct DocYaPacienteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            DocYaLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sharedString(context, "professionalRole", fallback: "Profesional"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(sharedString(context, "professionalName", fallback: "Asignado"))
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ETA")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(sharedString(context, "etaText", fallback: "--"))
                            .font(.title3.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sharedString(context, "statusText", fallback: "En camino"))
                            .font(.subheadline.weight(.semibold))
                        Text(sharedString(context, "address", fallback: "Direccion en curso"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(Color(red: 0.08, green: 0.82, blue: 0.76))
            } compactTrailing: {
                Text(sharedString(context, "etaText", fallback: "--"))
                    .font(.caption2.weight(.bold))
            } minimal: {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(Color(red: 0.08, green: 0.82, blue: 0.76))
            }
        }
    }
}
