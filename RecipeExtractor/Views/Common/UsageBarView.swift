import SwiftUI

struct UsageBarView: View {
    let used: Int
    let limit: Int
    let tier: SubscriptionTier

    private var fraction: Double {
        guard limit > 0 else { return 1.0 }
        return min(Double(used) / Double(limit), 1.0)
    }

    private var barColor: Color {
        fraction >= 1.0 ? .red : fraction >= 0.8 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tier == .pro ? "Unlimited extractions" : "\(used) of \(limit) extractions used")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(tier.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tierColor.opacity(0.15))
                    .foregroundStyle(tierColor)
                    .clipShape(Capsule())
            }
            if tier != .pro {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: geo.size.width * fraction, height: 8)
                            .animation(.easeInOut(duration: 0.4), value: fraction)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private var tierColor: Color {
        switch tier {
        case .free: return .secondary
        case .premium: return .blue
        case .pro: return .purple
        }
    }
}
