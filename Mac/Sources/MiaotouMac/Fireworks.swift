import SwiftUI

struct FireworksCanvas: View {
    let time: Double
    private let colors: [Color] = [Color(red: 0.14, green: 0.5, blue: 0.45), Color(red: 0.70, green: 0.51, blue: 0.18), Color(red: 0.28, green: 0.62, blue: 0.61), Color(red: 0.78, green: 0.44, blue: 0.34)]
    var body: some View {
        Canvas { context, size in
            guard time < 4.3 else { return }
            let center = size.height * 0.44
            let specs: [(Double, Double, Double)] = [(0.20, -110, 0.08), (0.82, -85, 0.27), (0.08, 8, 0.63), (0.90, 30, 0.8), (0.48, -160, 1.06), (0.17, -40, 1.39), (0.77, -130, 1.59), (0.5, 150, 1.78)]
            for (index, spec) in specs.enumerated() {
                let age = time - spec.2
                guard age >= 0 else { continue }
                let x = size.width * spec.0
                let y = max(30, min(size.height - 35, center + spec.1))
                let ascent = 0.48 + Double(index % 3) * 0.05
                let color = colors[index % colors.count]
                if age < ascent {
                    let p = age / ascent
                    let origin = size.width * (index % 2 == 0 ? 0.12 : 0.88)
                    func point(_ value: Double) -> CGPoint {
                        let eased = 1 - pow(1 - max(0, value), 2)
                        return CGPoint(x: origin + (x-origin)*eased, y: size.height + (y-size.height)*eased)
                    }
                    for segment in 0..<8 {
                        var trail = Path(); trail.move(to: point(p - Double(segment) * 0.018)); trail.addLine(to: point(p - Double(segment+1) * 0.018))
                        context.stroke(trail, with: .color(color.opacity(1-Double(segment)/8)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    }
                } else {
                    let e = age - ascent
                    for spark in 0..<64 {
                        let variation = Double((spark * 37 + index * 19) % 100) / 100
                        let life = 1.0 + variation * 0.65
                        guard e < life else { continue }
                        let angle = Double(spark) * .pi * 2 / 64
                        let speed = (spark % 3 == 0 ? 164.0 : 108.0) * (0.72 + variation * 0.5)
                        func point(_ age: Double) -> CGPoint {
                            let a = max(0, age), travel = (1 - exp(-a * 1.65)) / 1.65
                            return CGPoint(x: x + cos(angle)*speed*travel, y: y + sin(angle)*speed*travel + 32*a*a)
                        }
                        let alpha = pow(1 - e/life, 0.7)
                        for segment in 0..<4 {
                            var trail = Path(); trail.move(to: point(e-Double(segment)*0.055)); trail.addLine(to: point(e-Double(segment+1)*0.055))
                            context.stroke(trail, with: .color(color.opacity(alpha*(1-Double(segment)/4)*0.88)), style: StrokeStyle(lineWidth: spark % 3 == 0 ? 2.1 : 1.55, lineCap: .round))
                        }
                    }
                }
            }
        }
    }
}
