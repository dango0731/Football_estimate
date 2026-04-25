import SwiftUI

// ============================================================
// MARK: - MATCH ROW CARD（試合一覧のカード）
// ============================================================

struct MatchRowCard: View {
    let match: Match
    var avgRating: Double {
        let s = match.players.filter{$0.isStarter}; guard !s.isEmpty else { return 0 }
        return s.reduce(0.0){$0+$1.rating}/Double(s.count)
    }
    var body: some View {
        HStack(spacing:16) {
            RoundedRectangle(cornerRadius:4).fill(match.isFinished ? Color.green : Color.orange).frame(width:5)
            VStack(alignment:.leading,spacing:6) {
                HStack {
                    Text("vs \(match.opponent)").font(.headline.weight(.bold))
                    Spacer()
                    if match.isFinished && !match.players.isEmpty {
                        Text(String(format:"平均 %.2f",avgRating)).font(.subheadline.weight(.semibold)).foregroundColor(ratingColor(avgRating))
                    }
                }
                HStack(spacing:8) {
                    Text(match.dateString).font(.caption).foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
                    Text("\(match.players.count)名").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(match.isFinished ? "終了" : "進行中")
                        .font(.caption.weight(.semibold)).padding(.horizontal,10).padding(.vertical,4)
                        .background(match.isFinished ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(match.isFinished ? .green : .orange).clipShape(Capsule())
                }
            }
            Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundColor(.secondary.opacity(0.4))
        }
        .padding(16).background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius:16,style:.continuous))
        .shadow(color:.black.opacity(0.06),radius:8,x:0,y:3)
    }
}

// ============================================================
// MARK: - NEW MATCH SHEET（新しい試合を作成）
// ============================================================

struct NewMatchSheet: View {
    let onConfirm: (String, Date) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var opponent = ""
    @State private var date = Date()
    @FocusState private var focused: Bool
    var canCreate: Bool { !opponent.trimmingCharacters(in:.whitespaces).isEmpty }

    var body: some View {
        VStack(spacing:0) {
            HStack {
                Button("キャンセル") { dismiss() }.foregroundColor(.secondary)
                Spacer()
                Text("新しい試合").font(.headline.weight(.bold))
                Spacer()
                Button("作成") { onConfirm(opponent,date) }.fontWeight(.bold)
                    .foregroundColor(canCreate ? .green : .secondary).disabled(!canCreate)
            }.padding(.horizontal,20).padding(.top,20).padding(.bottom,16)
            Divider()

            ScrollView {
                VStack(spacing:28) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.12)).frame(width:90,height:90)
                        Image(systemName:"sportscourt.fill").font(.system(size:40)).foregroundColor(.green)
                    }.padding(.top,24)

                    VStack(spacing:16) {
                        VStack(alignment:.leading,spacing:8) {
                            Label("対戦相手",systemImage:"person.2.fill").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                            TextField("例: FC東京",text:$opponent).font(.title3).padding(14)
                                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:12)).focused($focused)
                        }
                        VStack(alignment:.leading,spacing:8) {
                            Label("試合日時",systemImage:"calendar").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                            DatePicker("",selection:$date,displayedComponents:[.date,.hourAndMinute])
                                .datePickerStyle(.compact).labelsHidden().padding(14)
                                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:12))
                        }
                    }.padding(.horizontal,24)

                    Button { guard canCreate else { return }; onConfirm(opponent,date) } label: {
                        Text("試合を作成して選手登録へ →").font(.headline.weight(.bold)).frame(maxWidth:.infinity).padding(.vertical,18)
                            .background(canCreate ? Color.green : Color.gray).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius:14))
                    }.disabled(!canCreate).padding(.horizontal,24).padding(.bottom,32)
                }
            }
        }
        .presentationDetents([.medium,.large]).onAppear { focused = true }
    }
}
