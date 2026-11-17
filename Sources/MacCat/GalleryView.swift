import SwiftUI

private let cream = Color(nsColor: .hex("FAF8F3"))
private let ink = Color(nsColor: .hex("454C40"))
private let muted = Color(nsColor: .hex("8C8E80"))
private let green = Color(nsColor: .hex("718266"))

struct GalleryView: View {
    @ObservedObject var state: AppState
    var onRecall: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "pawprint.fill").font(.system(size: 15))
                Text("MacCat").font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Circle().fill(state.hidden ? muted : green).frame(width: 6, height: 6)
                Text(state.hidden ? "잠시 숨어 있어요" : state.paused || state.reduceMotion ? "느긋하게 쉬는 중" : state.activity.label)
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            .foregroundStyle(green)
            .padding(.bottom, 25)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("당신의 화면에, 작은 고양이 한 마리.")
                        .font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-1.1)
                    Text("사뿐사뿐 걷고, 꾸벅꾸벅 졸고. 바쁜 하루를 함께할 친구를 만나보세요.")
                        .font(.system(size: 12)).foregroundStyle(muted)
                }
                Spacer()
                Text("MEET YOUR CAT").font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5).foregroundStyle(muted).padding(.bottom, 2)
            }
            .padding(.bottom, 24)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CatDesign.allCases) { design in
                    CatCard(design: design, selected: state.design == design) { state.design = design }
                }
            }
            .padding(.bottom, 22)

            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    settingLabel("발걸음의 크기", symbol: "pawprint")
                    Picker("고양이 크기", selection: $state.size) {
                        ForEach(CatSize.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 180)
                }
                Rectangle().fill(ink.opacity(0.09)).frame(width: 1, height: 44)
                VStack(alignment: .leading, spacing: 9) {
                    settingLabel("산책하는 곳", symbol: "rectangle.dashed")
                    Picker("산책 영역", selection: $state.area) {
                        ForEach(RoamingArea.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 190)
                }
                Rectangle().fill(ink.opacity(0.09)).frame(width: 1, height: 44)
                VStack(alignment: .leading, spacing: 5) {
                    settingLabel("느긋하게, 또는 발랄하게", symbol: "wind")
                    Slider(value: $state.speed, in: 22...70)
                        .tint(green).frame(width: 170).accessibilityLabel("산책 속도")
                }
            }
            .padding(18)
            .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 20)
            HStack {
                HStack(spacing: 13) {
                    Label("클릭해서 쓰담쓰담", systemImage: "heart")
                    Label("드래그로 자리 옮기기", systemImage: "hand.draw")
                    Label("우클릭으로 메뉴", systemImage: "cursorarrow")
                }
                .font(.system(size: 10)).foregroundStyle(muted)
                Spacer()
                Button(action: onRecall) {
                    Label("이리 와", systemImage: "location")
                }.buttonStyle(SoftButton())
                Button { state.paused.toggle() } label: {
                    Image(systemName: state.paused ? "play.fill" : "pause.fill")
                        .frame(width: 14)
                }
                .buttonStyle(SoftButton())
                .help(state.paused ? "산책 계속하기" : "잠깐 쉬기")
                .accessibilityLabel(state.paused ? "산책 계속하기" : "잠깐 쉬기")
            }
            if state.reduceMotion {
                Text("macOS의 ‘동작 줄이기’가 켜져 있어요. 고양이가 조용히 곁에 머물러요.")
                    .font(.system(size: 10)).foregroundStyle(muted).padding(.top, 10)
            }
        }
        .padding(28)
        .frame(width: 800, height: 644)
        .background(cream)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
    }

    private func settingLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(ink.opacity(0.8))
    }
}

private struct CatCard: View {
    let design: CatDesign
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: CatRenderer.image(design: design, size: CGSize(width: 192, height: 160)))
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(height: 119).frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17)).foregroundStyle(green)
                            .background(.white, in: Circle()).padding(10)
                    }
                }
                Text(design.name).font(.system(size: 13, weight: .semibold)).padding(.top, 2)
                Text(design.subtitle).font(.system(size: 9)).foregroundStyle(muted).padding(.top, 4)
            }
            .padding(.horizontal, 13).padding(.bottom, 14)
            .background(Color(nsColor: design.palette.backdrop).opacity(selected || hovered ? 0.85 : 0.48),
                        in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selected ? green : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("\(design.name), \(design.subtitle)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SoftButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(green.opacity(configuration.isPressed ? 0.2 : 0.10), in: Capsule())
            .foregroundStyle(green)
    }
}
