import SwiftUI

struct SessionLogView: View {

    @ObservedObject private var logService = SessionLogService.shared

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if logService.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Sessions Yet")
                        .font(.headline)
                    Text("Your awake sessions will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(logService.sessions) { session in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(Self.dateFormatter.string(from: session.startDate))
                                .fontWeight(.medium)
                            Text("→")
                                .foregroundStyle(.secondary)
                            Text(session.endDate, style: .time)
                        }
                        .font(.caption)

                        HStack {
                            Text(formatDuration(session.durationSeconds))
                            Text("·")
                            Text(session.reason)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)

                Divider()

                HStack {
                    Text("\(logService.sessions.count) session(s) recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Log") { logService.clear() }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }
}
