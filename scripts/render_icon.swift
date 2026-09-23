import CoreGraphics
import Foundation
import ImageIO

// 绘制 1024x1024 的应用图标，输出为 PNG。
// 用法: swift scripts/render_icon.swift <输出png路径>

let S: CGFloat = 1024

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("用法: swift render_icon.swift <输出png路径>\n".data(using: .utf8)!)
    exit(2)
}
let outPath = CommandLine.arguments[1]

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil,
    width: Int(S), height: Int(S),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

func cgColor(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(colorSpace: colorSpace, components: [r, g, b, alpha])!
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ path: CGPath, _ color: CGColor) {
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
}

func sparkle(center: CGPoint, outer: CGFloat, inner: CGFloat) {
    let path = CGMutablePath()
    for i in 0..<8 {
        let r = (i % 2 == 0) ? outer : inner
        let a = CGFloat(i) * (.pi / 4) - .pi / 2
        let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    fill(path, cgColor(0xFFFFFF))
}

let white = cgColor(0xFFFFFF)
let keyColor = cgColor(0x3B82F6)

// 1. 背景：squircle 圆角矩形 + 天空蓝渐变
let bgPath = roundedRect(CGRect(x: 0, y: 0, width: S, height: S), radius: 228)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [cgColor(0x7DD3FC), cgColor(0x2563EB)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
ctx.restoreGState()

// 2. 键盘主体（白色，带柔和投影）
let body = CGRect(x: 192, y: 376, width: 640, height: 272)
let bodyPath = roundedRect(body, radius: 40)

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -18),
    blur: 42,
    color: cgColor(0x0B2A6B, 0.30)
)
fill(bodyPath, white)
ctx.restoreGState()

// 3. 键帽（蓝色，4 行 x 6 列）
let padX: CGFloat = 28
let padTop: CGFloat = 26
let padBottom: CGFloat = 26
let gap: CGFloat = 14
let rows = 4
let cols = 6
let keyW = (body.width - padX * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)
let keyH = (body.height - padTop - padBottom - gap * CGFloat(rows - 1)) / CGFloat(rows)

for r in 0..<rows {
    for c in 0..<cols {
        let x = body.minX + padX + CGFloat(c) * (keyW + gap)
        let y = body.maxY - padTop - keyH - CGFloat(r) * (keyH + gap)
        fill(roundedRect(CGRect(x: x, y: y, width: keyW, height: keyH), radius: 12), keyColor)
    }
}

// 4. 星星点缀（表示“清洁/闪亮”）
sparkle(center: CGPoint(x: 792, y: 668), outer: 48, inner: 21)
sparkle(center: CGPoint(x: 234, y: 336), outer: 40, inner: 17)
sparkle(center: CGPoint(x: 302, y: 722), outer: 26, inner: 11)

// 5. 输出 PNG
guard let img = ctx.makeImage() else {
    FileHandle.standardError.write("生成图像失败\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
    FileHandle.standardError.write("创建输出文件失败\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("写入 PNG 失败\n".data(using: .utf8)!)
    exit(1)
}
print("已生成图标: \(outPath)")
