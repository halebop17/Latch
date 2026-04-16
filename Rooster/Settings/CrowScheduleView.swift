import SwiftUI

struct CrowScheduleView: View {

    @ObservedObject private var service = CrowScheduleService.shared
    @State private var showAddSheet = false
    @State private var editingSchedule: CrowSchedule?

    var body: some View {
        VStack(spacing: 0) {
            if service.schedules.isEmpty {
                emptyState
            } else {
                scheduleList
            }

            Divider()

            HStack {
                Text("Rooster activates automatically during enabled windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Schedule") { showAddSheet = true }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddSheet) {
            ScheduleFormView(schedule: CrowSchedule()) { service.add($0) }
        }
        .sheet(item: $editingSchedule) { s in
            ScheduleFormView(schedule: s) { service.update($0) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Schedules")
                .font(.headline)
            Text("Add a schedule to auto-activate Rooster\nduring set hours on specific days.")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scheduleList: some View {
        List {
            ForEach(service.schedules) { (schedule: CrowSchedule) in
                scheduleRow(for: schedule)
            }
            .onDelete { service.remove(at: $0) }
        }
        .listStyle(.inset)
    }

    private func scheduleRow(for schedule: CrowSchedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .fontWeight(.medium)
                Text("\(schedule.startTimeString) – \(schedule.endTimeString)  ·  \(schedule.weekdaysShortString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding<Bool>(
                get: { schedule.isEnabled },
                set: { newVal in
                    var copy = schedule
                    copy.isEnabled = newVal
                    service.update(copy)
                }
            ))
            .labelsHidden()
            Button("Edit") { editingSchedule = schedule }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add / Edit form

struct ScheduleFormView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var schedule: CrowSchedule
    private let onSave: (CrowSchedule) -> Void

    init(schedule: CrowSchedule, onSave: @escaping (CrowSchedule) -> Void) {
        _schedule = State(initialValue: schedule)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.headline)

            Form {
                TextField("Name", text: $schedule.name)

                HStack {
                    Text("Start")
                    Spacer()
                    hourPicker(hour: $schedule.startHour, minute: $schedule.startMinute)
                }

                HStack {
                    Text("End")
                    Spacer()
                    hourPicker(hour: $schedule.endHour, minute: $schedule.endMinute)
                }

                Section("Days") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            dayToggle(day: day)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(schedule.name.isEmpty || schedule.weekdays.isEmpty)
            }
        }
        .padding()
        .frame(width: 340)
    }

    private func hourPicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 58)

            Text(":").padding(.horizontal, 2)

            Picker("", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 58)
        }
    }

    private func dayToggle(day: Int) -> some View {
        let name = CrowSchedule.weekdayNames[day - 1]
        let isOn = schedule.weekdays.contains(day)
        return Button(name) {
            if isOn { schedule.weekdays.remove(day) }
            else    { schedule.weekdays.insert(day) }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(isOn ? .accentColor : .secondary)
    }
}
