import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationManager.notificationHour
                components.minute = notificationManager.notificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notificationManager.notificationHour = components.hour ?? 8
                notificationManager.notificationMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("알림") {
                    Toggle("매일 아침 알림", isOn: $notificationManager.notificationsEnabled)
                    if notificationManager.notificationsEnabled {
                        DatePicker("알림 시간", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                    if !notificationManager.isAuthorized {
                        Text("알림 권한이 꺼져 있어요. 설정 앱에서 허용해주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MananaTheme.paper.opacity(0.35))
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
