// ExportProgressView.swift
// BioNaural
//
// Renders the in-flight portion of the export flow: a determinate
// progress bar driven by `RenderProgress`, plus a Cancel button. The
// parent owns the cancel callback so this view stays presentation-only.
//
// All visual values from Theme tokens.

import SwiftUI

struct ExportProgressView: View {

    @Bindable var progress: RenderProgress
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Text("Rendering")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(percentLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .monospacedDigit()
            }

            progressBar
                .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            Button(action: onCancel) {
                Text("Cancel")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.surface)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                        lineWidth: Theme.Radius.glassStroke
                                    )
                            )
                    )
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private var percentLabel: String {
        let percent = Int((progress.fraction * 100).rounded())
        return "\(percent)%"
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.divider.opacity(Theme.Opacity.glassStroke))
                Capsule()
                    .fill(Theme.Colors.accent)
                    .frame(width: proxy.size.width * CGFloat(progress.fraction))
                    .animation(Theme.Animation.standard, value: progress.fraction)
            }
        }
        .frame(height: Theme.Radius.segmentHeight)
    }
}
