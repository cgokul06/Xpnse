//
//  SFSymbolPickerView.swift
//  Xpnse
//

import SwiftUI

enum CuratedSFSymbols {
    static let all: [String] = [
        "fork.knife", "cup.and.saucer.fill", "car.fill", "bus.fill", "tram.fill", "airplane",
        "bag.fill", "cart.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "building.2.fill", "house.fill", "bolt.fill", "flame.fill", "drop.fill",
        "wifi", "phone.fill", "tv.fill", "gamecontroller.fill", "film.fill", "music.note",
        "book.fill", "graduationcap.fill", "briefcase.fill", "stethoscope", "medical.thermometer",
        "heart.fill", "pills.fill", "figure.run", "dumbbell.fill", "pawprint.fill",
        "tshirt.fill", "scissors", "gift.fill", "star.fill", "sparkles",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "percent", "tag.fill",
        "text.pad.header", "doc.text.fill", "envelope.fill", "calendar",
        "map.fill", "location.fill", "fuelpump.fill", "parkingsign.circle.fill",
        "wrench.and.screwdriver.fill", "hammer.fill", "leaf.fill", "tree.fill",
        "sun.max.fill", "moon.fill", "cloud.fill", "umbrella.fill",
        "camera.fill", "photo.fill", "paintbrush.fill", "theatermasks.fill",
        "person.fill", "person.2.fill", "figure.child", "baby.fill",
        "ellipsis.circle.fill", "questionmark.circle.fill", "plus.circle.fill",
        "minus.circle.fill", "checkmark.circle.fill", "xmark.circle.fill"
    ]
}

struct SFSymbolPickerView: View {
    @Binding var selectedSymbol: String
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 52), spacing: 12)
    ]

    private var filteredSymbols: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return CuratedSFSymbols.all }
        return CuratedSFSymbols.all.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: selectedSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("Search symbols", text: $searchText)
                    .textFieldStyle(XpnseTextFieldStyle())
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    selectedSymbol == symbol
                                        ? XpnseColorKey.secondaryButtonBGColor.color
                                        : Color.white.opacity(0.12)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 220)
        }
    }
}
