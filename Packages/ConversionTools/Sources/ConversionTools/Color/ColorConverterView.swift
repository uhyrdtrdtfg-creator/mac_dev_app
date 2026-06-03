import SwiftUI
import AppKit
import DevAppCore

public struct ColorConverterView: View {
    @State private var inputText = "#3B82F6"
    @State private var color = RGBColor(r: 59, g: 130, b: 246)
    @State private var picker = Color(red: 59/255, green: 130/255, blue: 246/255)
    @State private var compareWhite = true
    @State private var syncing = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Color Converter").font(.title2).fontWeight(.semibold)
                Text("Convert between HEX, RGB, HSL, HSB and check WCAG contrast")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: Double(color.r)/255, green: Double(color.g)/255, blue: Double(color.b)/255))
                    .frame(width: 80, height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    TextField("#RRGGBB or rgb(r,g,b)", text: $inputText)
                        .font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    ColorPicker("Pick a color", selection: $picker, supportsOpacity: false)
                        .labelsHidden()
                }
            }

            VStack(spacing: 6) {
                formatRow("HEX", ColorConverter.toHex(color))
                formatRow("HEX+A", ColorConverter.toHex(color, includeAlpha: true))
                formatRow("RGB", ColorConverter.toRGBString(color))
                formatRow("HSL", hslString)
                formatRow("HSB", hsbString)
            }

            // Contrast
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("WCAG Contrast vs").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Picker("", selection: $compareWhite) {
                        Text("White").tag(true)
                        Text("Black").tag(false)
                    }.pickerStyle(.segmented).frame(width: 140)
                }
                let bg = compareWhite ? RGBColor(r: 255, g: 255, b: 255) : RGBColor(r: 0, g: 0, b: 0)
                let ratio = ColorConverter.contrastRatio(color, bg)
                HStack {
                    Text(String(format: "%.2f : 1", ratio)).font(.system(.title3, design: .monospaced))
                    Spacer()
                    badge("AA", ratio >= 4.5)
                    badge("AA Large", ratio >= 3)
                    badge("AAA", ratio >= 7)
                }
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .onChange(of: inputText) { _, _ in
            guard !syncing else { return }
            if let parsed = ColorConverter.parse(inputText) {
                syncing = true
                color = parsed
                picker = Color(red: Double(parsed.r)/255, green: Double(parsed.g)/255, blue: Double(parsed.b)/255)
                syncing = false
            }
        }
        .onChange(of: picker) { _, newValue in
            guard !syncing else { return }
            if let components = NSColor(newValue).usingColorSpace(.sRGB) {
                syncing = true
                color = RGBColor(r: Int((components.redComponent * 255).rounded()),
                                 g: Int((components.greenComponent * 255).rounded()),
                                 b: Int((components.blueComponent * 255).rounded()))
                inputText = ColorConverter.toHex(color)
                syncing = false
            }
        }
    }

    private var hslString: String {
        let h = ColorConverter.toHSL(color); return "hsl(\(h.h), \(h.s)%, \(h.l)%)"
    }
    private var hsbString: String {
        let h = ColorConverter.toHSB(color); return "hsb(\(h.h), \(h.s)%, \(h.b)%)"
    }

    private func formatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
            CopyButton(text: value)
        }
        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func badge(_ label: String, _ pass: Bool) -> some View {
        Text(label).font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((pass ? Color.green : Color.red).opacity(0.18))
            .foregroundStyle(pass ? .green : .red)
            .clipShape(Capsule())
    }
}

extension ColorConverterView {
    public static let descriptor = ToolDescriptor(
        id: "color-converter",
        name: "Color Converter",
        icon: "paintpalette",
        category: .developer,
        searchKeywords: ["color", "colour", "hex", "rgb", "hsl", "hsb", "contrast", "wcag", "颜色", "调色"]
    )
}
