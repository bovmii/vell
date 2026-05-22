#!/usr/bin/env swift
// Génère le fond du DMG : dégradé doux + flèche Vell → Applications + texte de licence.
// Usage: swift make_dmg_background.swift output.png

import Cocoa

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift make_dmg_background.swift <output.png>")
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let W: CGFloat = 520
let H: CGFloat = 340

let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// 1) Dégradé doux (lavande → bleu pâle)
let colors = [
    NSColor(red: 0.96, green: 0.94, blue: 1.00, alpha: 1).cgColor,
    NSColor(red: 0.85, green: 0.88, blue: 0.99, alpha: 1).cgColor
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: H),
                       end: CGPoint(x: W, y: 0),
                       options: [])

// 2) Titre en haut
let titleText = "Glissez Vell dans Applications"
let titlePara = NSMutableParagraphStyle(); titlePara.alignment = .center
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
    .foregroundColor: NSColor(red: 0.25, green: 0.20, blue: 0.50, alpha: 1),
    .paragraphStyle: titlePara
]
let titleStr = NSAttributedString(string: titleText, attributes: titleAttrs)
// y from bottom: top of image (y=340) minus 40 → text rect at y=295
titleStr.draw(in: NSRect(x: 0, y: H - 50, width: W, height: 30))

// 3) Flèche horizontale Vell (140) → Applications (380), à hauteur des icônes (150 from top)
// Y from bottom = H - 150 = 190
let arrowY: CGFloat = H - 150
let arrowStartX: CGFloat = 210
let arrowEndX: CGFloat = 320

ctx.setStrokeColor(NSColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.9).cgColor)
ctx.setFillColor(NSColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.9).cgColor)
ctx.setLineWidth(5)
ctx.setLineCap(.butt)   // pas de bouton arrondi qui dépasserait dans le triangle

// Pointe de flèche : on la dessine d'abord et on s'arrête net à sa base.
let headLen: CGFloat = 18
let headWidth: CGFloat = 11
let arrowTipX = arrowEndX
let arrowBaseX = arrowEndX - headLen

// Ligne qui s'arrête à la base du triangle (pas de dépassement).
ctx.beginPath()
ctx.move(to: CGPoint(x: arrowStartX, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowBaseX, y: arrowY))
ctx.strokePath()

// Triangle (rempli).
ctx.beginPath()
ctx.move(to: CGPoint(x: arrowTipX, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowBaseX, y: arrowY + headWidth))
ctx.addLine(to: CGPoint(x: arrowBaseX, y: arrowY - headWidth))
ctx.closePath()
ctx.fillPath()

// 4) Texte licence en bas
let licenseText = """
Vell est 100 % gratuit. Licence PolyForm Noncommercial 1.0.0. Revente interdite.
Copyright © 2026 @bovmii   ·   github.com/bovmii   ·   instagram.com/bovmii
"""

let licPara = NSMutableParagraphStyle()
licPara.alignment = .center
licPara.lineSpacing = 4

let licAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor(red: 0.30, green: 0.25, blue: 0.55, alpha: 0.9),
    .paragraphStyle: licPara
]
let licStr = NSAttributedString(string: licenseText, attributes: licAttrs)
licStr.draw(in: NSRect(x: 20, y: 25, width: W - 40, height: 60))

image.unlockFocus()

// Export PNG
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG"); exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("✓ Background image written to \(outputPath)")
} catch {
    print("Write failed: \(error)"); exit(1)
}
