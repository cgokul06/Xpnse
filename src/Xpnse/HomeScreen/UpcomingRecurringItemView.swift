//
//  UpcomingRecurringItemView.swift
//  Xpnse
//

import SwiftUI

struct UpcomingRecurringItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTapped = false

    let item: UpcomingRecurringItem
    var subtitle: TransactionItemSubtitle = .date
    var showsLeadingCategoryIcon: Bool = true
    var onTap: () -> Void

    private static let emojiSize: CGFloat = 30
    private static let accentSideInset: CGFloat = 10
    private static let contentLeadingGap: CGFloat = 12

    private var category: CategoryDefinition {
        CategoryStore.shared.resolve(id: item.categoryId)
    }

    private var categoryColor: Color {
        Color(hex: category.colorHex)
    }

    private var accentBandWidth: CGFloat {
        Self.accentSideInset + Self.emojiSize + Self.accentSideInset
    }

    private var formattedAmount: String {
        AmountFormatter.format(
            item.amount,
            currencyCode: CurrencyManager.shared.selectedCurrency.code
        )
    }

    private var formattedDate: String {
        Self.mediumDateFormatter.string(from: item.occurrenceDate)
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            if showsLeadingCategoryIcon {
                categoryAccentBand
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.rule.title)
                        .font(.system(size: 16, weight: .semibold))
                        .xpnseAdaptiveForeground()
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        switch subtitle {
                        case .date:
                            Text(formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .xpnseAdaptiveForeground(muted: true)
                        case .category:
                            Text(CategoryStore.shared.localizedName(for: category))
                                .font(.system(size: 12, weight: .medium))
                                .xpnseAdaptiveForeground(muted: true)
                        }

                        Text(L10n.tr("home.upcoming"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 8)

                Text(formattedAmount)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .xpnseAdaptiveForeground()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.leading, showsLeadingCategoryIcon ? Self.contentLeadingGap : 12)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(
            AdaptiveBrandSurface.elevatedSurfaceBackground(for: colorScheme).opacity(0.55),
            in: XpnseOutlinedPanelMetrics.shape
        )
        .clipShape(XpnseOutlinedPanelMetrics.shape)
        .overlay(
            XpnseOutlinedPanelMetrics.shape
                .strokeBorder(
                    (showsLeadingCategoryIcon ? categoryColor : AdaptiveBrandSurface.fieldBorder(for: colorScheme))
                        .opacity(0.55),
                    style: StrokeStyle(lineWidth: XpnseOutlinedPanelMetrics.borderWidth, dash: [6, 4])
                )
        )
        .opacity(0.72)
        .scaleEffect(isTapped ? 0.98 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isTapped)
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                isTapped = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    isTapped = false
                }
                onTap()
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.openUpcomingRecurring,
                    source: AppAnalytics.Screen.home
                )
            }
        }
        .accessibilityLabel(
            Text("\(item.rule.title), \(L10n.tr("home.upcoming")), \(formattedAmount)")
        )
    }

    private var categoryAccentBand: some View {
        ZStack {
            categoryColor.opacity(0.55)

            CategoryIconBadge(
                symbolName: category.symbolName,
                colorHex: category.colorHex,
                size: Self.emojiSize,
                showsColorBackground: false
            )
            .opacity(0.85)
        }
        .frame(width: accentBandWidth)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(seamHighlight)
                .frame(width: 1)
        }
    }

    private var seamHighlight: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.white.opacity(0.35)
    }
}
