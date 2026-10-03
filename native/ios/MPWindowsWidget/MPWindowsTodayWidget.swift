import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.vn.mpwindows.crm"
private let payloadKey = "mpwindows_widget_payload"

struct MPWindowsWidgetPayload: Codable {
  struct NextAppointment: Codable {
    let title: String
    let time: String
    let customer: String
  }

  let date: String
  let appointmentCount: Int
  let taskCount: Int
  let customerCount: Int
  let nextAppointment: NextAppointment?

  static let empty = MPWindowsWidgetPayload(
    date: "--/--",
    appointmentCount: 0,
    taskCount: 0,
    customerCount: 0,
    nextAppointment: nil
  )
}

struct MPWindowsTodayEntry: TimelineEntry {
  let date: Date
  let payload: MPWindowsWidgetPayload
}

struct MPWindowsTodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> MPWindowsTodayEntry {
    MPWindowsTodayEntry(
      date: Date(),
      payload: MPWindowsWidgetPayload(
        date: "03/10",
        appointmentCount: 2,
        taskCount: 3,
        customerCount: 12,
        nextAppointment: .init(title: "Khảo sát công trình", time: "09:30", customer: "Anh Nam")
      )
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (MPWindowsTodayEntry) -> Void) {
    completion(MPWindowsTodayEntry(date: Date(), payload: loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MPWindowsTodayEntry>) -> Void) {
    let entry = MPWindowsTodayEntry(date: Date(), payload: loadPayload())
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
      ?? Date().addingTimeInterval(1800)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func loadPayload() -> MPWindowsWidgetPayload {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = defaults.data(forKey: payloadKey),
      let payload = try? JSONDecoder().decode(MPWindowsWidgetPayload.self, from: data)
    else {
      return .empty
    }
    return payload
  }
}

struct MPWindowsTodayWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: MPWindowsTodayEntry

  private let brandGold = Color(red: 0.69, green: 0.48, blue: 0.11)

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("MP WINDOWS")
          .font(.system(size: 13, weight: .black))
          .foregroundStyle(brandGold)
        Spacer()
        Text(entry.payload.date)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if family == .systemSmall {
        smallContent
      } else {
        mediumContent
      }
    }
    .containerBackground(for: .widget) {
      Color(.systemBackground)
    }
  }

  private var smallContent: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("\(entry.payload.appointmentCount) lịch hẹn", systemImage: "calendar")
        .font(.subheadline.weight(.semibold))
      Label("\(entry.payload.taskCount) việc cần làm", systemImage: "checklist")
        .font(.subheadline.weight(.semibold))

      Spacer(minLength: 2)

      if let next = entry.payload.nextAppointment {
        Text("Tiếp theo \(next.time)")
          .font(.caption.weight(.bold))
          .foregroundStyle(brandGold)
        Text(next.title)
          .font(.caption)
          .lineLimit(1)
      } else {
        Text("Không có lịch sắp tới")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var mediumContent: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Label("\(entry.payload.appointmentCount) lịch hẹn", systemImage: "calendar")
        Label("\(entry.payload.taskCount) việc cần làm", systemImage: "checklist")
        Label("\(entry.payload.customerCount) khách hàng", systemImage: "person.2")
      }
      .font(.subheadline.weight(.semibold))

      Divider()

      VStack(alignment: .leading, spacing: 4) {
        Text("LỊCH TIẾP THEO")
          .font(.caption2.weight(.bold))
          .foregroundStyle(brandGold)

        if let next = entry.payload.nextAppointment {
          Text("\(next.time) · \(next.title)")
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
          if !next.customer.isEmpty {
            Text(next.customer)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        } else {
          Text("Chưa có lịch sắp tới")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

@main
struct MPWindowsTodayWidget: Widget {
  let kind = "MPWindowsTodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MPWindowsTodayProvider()) { entry in
      MPWindowsTodayWidgetView(entry: entry)
    }
    .configurationDisplayName("MPWindows Hôm nay")
    .description("Lịch hẹn, công việc và khách hàng cần theo dõi.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
