// PaywallView.swift
// BioNaural
//
// Premium upgrade screen. Shown as a soft paywall after the user's first
// completed session. Fully dismissible — never blocks usage. All layout
// values sourced from Theme tokens. Native StoreKit 2 purchase flow.

import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProductID: String? = SubscriptionProduct.annual
    @State private var isPurchasing = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xxl) {
                    headerSection
                    learningTimeline
                    pricingSection
                    legalFooter
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.top, Theme.Spacing.xxxl)
                .padding(.bottom, Theme.Spacing.jumbo)
            }
            .background {
                NebulaBokehBackground()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong. Please try again.")
            }
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Text("It gets smarter\nevery session.")
            .font(Theme.Typography.title)
            .foregroundStyle(Theme.Colors.textPrimary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Learning Timeline

    /// Timeline milestones showing how BioNaural improves over time.
    /// Uses a ZStack with a continuous vertical line behind aligned dots
    /// to guarantee perfect left-edge alignment across all rows.
    private var learningTimeline: some View {
        let milestones: [(time: String, title: String, description: String, color: Color)] = [
            ("Day 1", "Calibrating", "BioNaural reads your baseline HR and HRV", Theme.Colors.accent),
            ("Week 1", "Learning your patterns", "Sound adapts to your unique response", Theme.Colors.focus),
            ("Month 1", "Personalized to you", "Frequencies tuned to your brain\u{2019}s preferences", Theme.Colors.relaxation),
            ("Month 3+", "Anticipates your needs", "Learns your daily rhythm, suggests optimal modes", Theme.Colors.energize)
        ]

        let dotSize = Theme.Spacing.md
        let dotColumnWidth = Theme.Spacing.xl

        return HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            // Fixed-width dot + line column
            ZStack(alignment: .top) {
                // Continuous vertical line
                Rectangle()
                    .fill(Theme.Colors.divider)
                    .frame(width: Theme.Radius.glassStroke)
                    .padding(.top, dotSize / 2)
                    .padding(.bottom, Theme.Spacing.xxl + dotSize / 2)

                // Dots spaced evenly
                VStack(spacing: 0) {
                    ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                        Circle()
                            .fill(milestone.color)
                            .frame(width: dotSize, height: dotSize)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.canvas, lineWidth: Theme.Radius.glassStroke * 2)
                            )

                        if index < milestones.count - 1 {
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: dotColumnWidth)
            .accessibilityHidden(true)

            // Text column — perfectly aligned
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(milestone.time.uppercased())
                            .font(Theme.Typography.small)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .foregroundStyle(milestone.color)

                        Text(milestone.title)
                            .font(Theme.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(milestone.description)
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if index < milestones.count - 1 {
                        Spacer()
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if subscriptionManager.isLoadingProducts {
                ProgressView()
                    .tint(Theme.Colors.accent)
                    .padding(Theme.Spacing.xxl)
            } else if subscriptionManager.products.isEmpty {
                Text("Unable to load pricing. Please check your connection.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Spacing.xxl)

                Button {
                    Task {
                        await subscriptionManager.loadProducts()
                    }
                } label: {
                    Text("Retry")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.accent)
                }
            } else {
                // Hero annual price
                if let annual = subscriptionManager.annualProduct {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(annual.displayPrice + "/year")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Start free for 7 days")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .padding(.bottom, Theme.Spacing.sm)
                }

                // CTA — always purchases the selected product (annual by default)
                purchaseButton

                // Alt pricing line with restore
                altPricingLine
            }
        }
    }

    /// Compact alternative pricing line: monthly · lifetime · restore.
    private var altPricingLine: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let monthly = subscriptionManager.monthlyProduct {
                Button {
                    withAnimation(Theme.Animation.press) {
                        selectedProductID = monthly.id
                    }
                } label: {
                    Text(monthly.displayPrice + "/mo")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Text("\u{00B7}")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .accessibilityHidden(true)
            }

            if let lifetime = subscriptionManager.lifetimeProduct {
                Button {
                    withAnimation(Theme.Animation.press) {
                        selectedProductID = lifetime.id
                    }
                } label: {
                    Text(lifetime.displayPrice + " lifetime")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Text("\u{00B7}")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .accessibilityHidden(true)
            }

            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.isPremium {
                        showPurchaseConfirmation()
                    }
                }
            } label: {
                Text("Restore")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                await handlePurchase()
            }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(Theme.Colors.textOnAccent)
                } else {
                    Text("Start Free Trial")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Capsule().fill(
                    selectedProductID != nil
                        ? Theme.Colors.accent
                        : Theme.Colors.accent.opacity(Theme.Opacity.medium)
                )
            )
        }
        .disabled(selectedProductID == nil || isPurchasing)
        .padding(.top, Theme.Spacing.sm)
        .accessibilityLabel("Start free trial")
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. " +
                "Manage in Settings > Subscriptions.")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.md) {
                Link("Terms of Use", destination: Constants.termsURL)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text("|")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .accessibilityHidden(true)

                Link("Privacy Policy", destination: Constants.privacyURL)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Restore (inline in altPricingLine)

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.accent)

            Text("Welcome to Premium")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas.opacity(Theme.Opacity.translucent).ignoresSafeArea())
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Purchase Handling

    private func handlePurchase() async {
        guard let productID = selectedProductID else { return }
        guard let product = subscriptionManager.products.first(where: { $0.id == productID }) else { return }

        isPurchasing = true

        do {
            try await subscriptionManager.purchase(product: product)
            showPurchaseConfirmation()
        } catch SubscriptionManager.PurchaseError.cancelled {
            // User cancelled — do nothing.
        } catch SubscriptionManager.PurchaseError.pending {
            errorMessage = "Your purchase is pending approval. You'll get access once it's confirmed."
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func showPurchaseConfirmation() {
        withAnimation(Theme.Animation.standard) {
            showConfirmation = true
        }

        // Auto-dismiss after a brief delay.
        Task {
            try? await Task.sleep(for: .seconds(Theme.Animation.Duration.sheet + 1.0))
            dismiss()
        }
    }

}

// MARK: - Paywall Trigger Logic

extension PaywallView {

    /// Key used to track whether the user has completed at least one session.
    static let hasCompletedFirstSessionKey = "com.bionaural.hasCompletedFirstSession"

    /// Key used to track whether the paywall has been shown after the first session.
    static let hasShownPostFirstSessionPaywallKey = "com.bionaural.hasShownPostFirstSessionPaywall"

    /// Call after a session completes to determine whether to show the paywall.
    ///
    /// Returns `true` if:
    /// - The user is not already premium.
    /// - The user has completed at least one session.
    /// - The paywall has not yet been shown after the first session.
    static func shouldShowAfterSession() -> Bool {
        guard !SubscriptionManager.shared.isPremium else { return false }

        let defaults = UserDefaults.standard
        let hasCompleted = defaults.bool(forKey: hasCompletedFirstSessionKey)
        let hasShown = defaults.bool(forKey: hasShownPostFirstSessionPaywallKey)

        return hasCompleted && !hasShown
    }

    /// Marks that the user has completed their first session.
    static func markFirstSessionCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedFirstSessionKey)
    }

    /// Marks that the post-first-session paywall has been shown.
    static func markPaywallShown() {
        UserDefaults.standard.set(true, forKey: hasShownPostFirstSessionPaywallKey)
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .preferredColorScheme(.dark)
}
