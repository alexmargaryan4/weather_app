import SwiftUI

/// Переводит код иконки погоды от OpenWeatherMap (например "01d", "10n") в
/// SwiftUI View. Логика соответствия групп кодов идентична
/// WidgetIconMapper.kt на Android — тот же набор из 9 состояний погоды.
enum WeatherWidgetIcon {
    @ViewBuilder
    static func view(for iconCode: String) -> some View {
        let code = String(iconCode.prefix(2))
        let isNight = iconCode.hasSuffix("n")

        switch code {
        case "01":
            if isNight { ClearNightIcon() } else { ClearDayIcon() }
        case "02":
            if isNight { PartlyCloudyNightIcon() } else { PartlyCloudyDayIcon() }
        case "03", "04":
            CloudyIcon()
        case "09", "10":
            RainIcon()
        case "11":
            ThunderstormIcon()
        case "13":
            SnowIcon()
        case "50":
            FogIcon()
        default:
            ClearDayIcon()
        }
    }
}

// Все иконки нарисованы во viewBox 48x48 — тех же координатах, что и
// исходные Android vector drawable (android/.../res/drawable/ic_widget_*.xml),
// поэтому формы и относительные пропорции идентичны.

private struct ClearDayIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            let sunColor = Color(red: 1.0, green: 0.788, blue: 0.290) // #FFC94A
            context.fill(Path(ellipseIn: CGRect(x: 16, y: 16, width: 16, height: 16)), with: .color(sunColor))

            var rays = Path()
            let rayLines: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 24, y: 6), CGPoint(x: 24, y: 10)),
                (CGPoint(x: 24, y: 38), CGPoint(x: 24, y: 42)),
                (CGPoint(x: 42, y: 24), CGPoint(x: 38, y: 24)),
                (CGPoint(x: 10, y: 24), CGPoint(x: 6, y: 24)),
                (CGPoint(x: 35.31, y: 12.69), CGPoint(x: 32.48, y: 15.52)),
                (CGPoint(x: 15.52, y: 32.48), CGPoint(x: 12.69, y: 35.31)),
                (CGPoint(x: 35.31, y: 35.31), CGPoint(x: 32.48, y: 32.48)),
                (CGPoint(x: 15.52, y: 15.52), CGPoint(x: 12.69, y: 12.69)),
            ]
            for (from, to) in rayLines {
                rays.move(to: from)
                rays.addLine(to: to)
            }
            context.stroke(rays, with: .color(sunColor), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
    }
}

private struct ClearNightIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            var moon = Path()
            moon.move(to: CGPoint(x: 31, y: 10))
            moon.addCurve(to: CGPoint(x: 19, y: 22), control1: CGPoint(x: 24.4, y: 10), control2: CGPoint(x: 19, y: 15.4))
            moon.addCurve(to: CGPoint(x: 31, y: 34), control1: CGPoint(x: 19, y: 28.6), control2: CGPoint(x: 24.4, y: 34))
            moon.addCurve(to: CGPoint(x: 36.76, y: 32.49), control1: CGPoint(x: 33.1, y: 34), control2: CGPoint(x: 35.06, y: 33.45))
            moon.addCurve(to: CGPoint(x: 31.9, y: 24.3), control1: CGPoint(x: 33.86, y: 30.9), control2: CGPoint(x: 31.9, y: 27.83))
            moon.addCurve(to: CGPoint(x: 40.2, y: 14.87), control1: CGPoint(x: 31.9, y: 19.47), control2: CGPoint(x: 35.53, y: 15.48))
            moon.addCurve(to: CGPoint(x: 31, y: 10), control1: CGPoint(x: 37.94, y: 11.95), control2: CGPoint(x: 34.69, y: 10))
            moon.closeSubpath()
            context.fill(moon, with: .color(Color(red: 0.796, green: 0.835, blue: 0.910))) // #CBD5E8
        }
    }
}

private struct PartlyCloudyDayIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            let sunColor = Color(red: 1.0, green: 0.788, blue: 0.290) // #FFC94A
            context.fill(Path(ellipseIn: CGRect(x: 11.5, y: 10.5, width: 13, height: 13)), with: .color(sunColor))

            var rays = Path()
            let rayLines: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 18, y: 4), CGPoint(x: 18, y: 7.2)),
                (CGPoint(x: 8.06, y: 17), CGPoint(x: 4.86, y: 17)),
                (CGPoint(x: 11.14, y: 10.14), CGPoint(x: 8.88, y: 7.88)),
                (CGPoint(x: 24.94, y: 10.14), CGPoint(x: 27.2, y: 7.88)),
            ]
            for (from, to) in rayLines {
                rays.move(to: from)
                rays.addLine(to: to)
            }
            context.stroke(rays, with: .color(sunColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            context.fill(cloudPath(), with: .color(Color(red: 0.906, green: 0.925, blue: 0.961))) // #E7ECF5
        }
    }
}

private struct PartlyCloudyNightIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            var moon = Path()
            moon.move(to: CGPoint(x: 20, y: 9))
            moon.addCurve(to: CGPoint(x: 12, y: 17), control1: CGPoint(x: 15.7, y: 9), control2: CGPoint(x: 12, y: 12.44))
            moon.addCurve(to: CGPoint(x: 12.39, y: 19.45), control1: CGPoint(x: 12, y: 17.86), control2: CGPoint(x: 12.14, y: 18.68))
            moon.addCurve(to: CGPoint(x: 8.9, y: 25.66), control1: CGPoint(x: 10.3, y: 20.7), control2: CGPoint(x: 8.9, y: 23.02))
            moon.addCurve(to: CGPoint(x: 8.98, y: 26.71), control1: CGPoint(x: 8.9, y: 26.02), control2: CGPoint(x: 8.93, y: 26.37))
            moon.addCurve(to: CGPoint(x: 16.3, y: 21.8), control1: CGPoint(x: 10.13, y: 23.83), control2: CGPoint(x: 12.98, y: 21.8))
            moon.addCurve(to: CGPoint(x: 17.25, y: 21.86), control1: CGPoint(x: 16.62, y: 21.8), control2: CGPoint(x: 16.94, y: 21.82))
            moon.addCurve(to: CGPoint(x: 20.66, y: 18.65), control1: CGPoint(x: 17.94, y: 20.4), control2: CGPoint(x: 19.16, y: 19.24))
            moon.addCurve(to: CGPoint(x: 20.66, y: 13.35), control1: CGPoint(x: 20.24, y: 17.35), control2: CGPoint(x: 19.9, y: 15.28))
            moon.addCurve(to: CGPoint(x: 24.2, y: 9.55), control1: CGPoint(x: 21.32, y: 11.65), control2: CGPoint(x: 22.6, y: 10.32))
            moon.addCurve(to: CGPoint(x: 20, y: 9), control1: CGPoint(x: 22.99, y: 9.2), control2: CGPoint(x: 21.6, y: 9))
            moon.closeSubpath()
            context.fill(moon, with: .color(Color(red: 0.796, green: 0.835, blue: 0.910))) // #CBD5E8

            context.fill(cloudPath(), with: .color(Color(red: 0.906, green: 0.925, blue: 0.961))) // #E7ECF5
        }
    }
}

/// Общая форма облака для partly-cloudy иконок (день/ночь) —
/// идентична пути в ic_widget_partly_cloudy_*.xml.
private func cloudPath() -> Path {
    var cloud = Path()
    cloud.move(to: CGPoint(x: 32, y: 20))
    cloud.addCurve(to: CGPoint(x: 26.3, y: 23.54), control1: CGPoint(x: 29.5, y: 20), control2: CGPoint(x: 27.34, y: 21.44))
    cloud.addCurve(to: CGPoint(x: 20.2, y: 30), control1: CGPoint(x: 22.9, y: 23.72), control2: CGPoint(x: 20.2, y: 26.53))
    cloud.addCurve(to: CGPoint(x: 26.7, y: 36.5), control1: CGPoint(x: 20.2, y: 33.59), control2: CGPoint(x: 23.11, y: 36.5))
    cloud.addLine(to: CGPoint(x: 34.5, y: 36.5))
    cloud.addCurve(to: CGPoint(x: 41, y: 30), control1: CGPoint(x: 38.09, y: 36.5), control2: CGPoint(x: 41, y: 33.59))
    cloud.addCurve(to: CGPoint(x: 35.08, y: 23.53), control1: CGPoint(x: 41, y: 26.6), control2: CGPoint(x: 38.4, y: 23.81))
    cloud.addCurve(to: CGPoint(x: 32, y: 20), control1: CGPoint(x: 34.55, y: 21.5), control2: CGPoint(x: 32.75, y: 20))
    cloud.closeSubpath()
    return cloud
}

private struct CloudyIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            var back = Path()
            back.move(to: CGPoint(x: 15, y: 16))
            back.addCurve(to: CGPoint(x: 8, y: 23), control1: CGPoint(x: 11.13, y: 16), control2: CGPoint(x: 8, y: 19.13))
            back.addCurve(to: CGPoint(x: 8.24, y: 24.79), control1: CGPoint(x: 8, y: 23.62), control2: CGPoint(x: 8.08, y: 24.22))
            back.addCurve(to: CGPoint(x: 4, y: 31.1), control1: CGPoint(x: 5.78, y: 25.79), control2: CGPoint(x: 4, y: 28.24))
            back.addCurve(to: CGPoint(x: 10.9, y: 38), control1: CGPoint(x: 4, y: 34.85), control2: CGPoint(x: 7.15, y: 38))
            back.addLine(to: CGPoint(x: 16, y: 38))
            back.addLine(to: CGPoint(x: 16, y: 16.35))
            back.addCurve(to: CGPoint(x: 15, y: 16), control1: CGPoint(x: 15.68, y: 16.12), control2: CGPoint(x: 15.34, y: 16))
            back.closeSubpath()
            context.fill(back, with: .color(Color(red: 0.682, green: 0.725, blue: 0.800))) // #AEB9CC

            var front = Path()
            front.move(to: CGPoint(x: 28, y: 12))
            front.addCurve(to: CGPoint(x: 18, y: 22), control1: CGPoint(x: 22.48, y: 12), control2: CGPoint(x: 18, y: 16.48))
            front.addCurve(to: CGPoint(x: 18.41, y: 24.81), control1: CGPoint(x: 18, y: 22.98), control2: CGPoint(x: 18.15, y: 23.92))
            front.addCurve(to: CGPoint(x: 12.1, y: 33.26), control1: CGPoint(x: 14.77, y: 25.9), control2: CGPoint(x: 12.1, y: 29.27))
            front.addCurve(to: CGPoint(x: 16.88, y: 38), control1: CGPoint(x: 12.1, y: 35.9), control2: CGPoint(x: 14.24, y: 38))
            front.addLine(to: CGPoint(x: 36, y: 38))
            front.addCurve(to: CGPoint(x: 44, y: 30), control1: CGPoint(x: 40.42, y: 38), control2: CGPoint(x: 44, y: 34.42))
            front.addCurve(to: CGPoint(x: 37.31, y: 22.11), control1: CGPoint(x: 44, y: 26.03), control2: CGPoint(x: 41.11, y: 22.73))
            front.addCurve(to: CGPoint(x: 28, y: 12), control1: CGPoint(x: 36.52, y: 16.4), control2: CGPoint(x: 32.71, y: 12))
            front.closeSubpath()
            context.fill(front, with: .color(Color(red: 0.780, green: 0.816, blue: 0.878))) // #C7D0E0
        }
    }
}

/// Общая форма облака-основы для rain/thunderstorm/snow — идентична пути
/// в ic_widget_rain.xml / ic_widget_thunderstorm.xml / ic_widget_snow.xml
/// (у них небольшие вариации точек, поэтому передаём их параметром).
private func rainCloudBasePath(topY: Double, bottomY: Double) -> Path {
    var cloud = Path()
    cloud.move(to: CGPoint(x: 28, y: topY))
    cloud.addCurve(to: CGPoint(x: 18, y: topY + 10), control1: CGPoint(x: 22.48, y: topY), control2: CGPoint(x: 18, y: topY + 4.48))
    cloud.addCurve(to: CGPoint(x: 18.32, y: topY + 12.4), control1: CGPoint(x: 18, y: topY + 10.83), control2: CGPoint(x: 18.12, y: topY + 11.63))
    cloud.addCurve(to: CGPoint(x: 12, y: topY + 20.6), control1: CGPoint(x: 14.71, y: topY + 13.32), control2: CGPoint(x: 12, y: topY + 16.64))
    cloud.addCurve(to: CGPoint(x: 12.28, y: topY + 22.74), control1: CGPoint(x: 12, y: topY + 21.34), control2: CGPoint(x: 12.11, y: topY + 22.05))
    cloud.addCurve(to: CGPoint(x: 16.86, y: bottomY), control1: CGPoint(x: 13.63, y: topY + 23.53), control2: CGPoint(x: 15.19, y: bottomY))
    cloud.addLine(to: CGPoint(x: 34.9, y: bottomY))
    cloud.addCurve(to: CGPoint(x: 43, y: bottomY - 4.1), control1: CGPoint(x: 39.37, y: bottomY), control2: CGPoint(x: 43, y: bottomY - 3.63))
    cloud.addCurve(to: CGPoint(x: 37.03, y: topY + 8.17), control1: CGPoint(x: 43, y: topY + 12.19), control2: CGPoint(x: 40.45, y: topY + 9.08))
    cloud.addCurve(to: CGPoint(x: 28, y: topY), control1: CGPoint(x: 36.11, y: topY + 3.48), control2: CGPoint(x: 32.47, y: topY))
    cloud.closeSubpath()
    return cloud
}

private struct RainIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            context.fill(rainCloudBasePath(topY: 8, bottomY: 32), with: .color(Color(red: 0.604, green: 0.655, blue: 0.769))) // #9AA7C4

            var drops = Path()
            let dropLines: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 18, y: 35), CGPoint(x: 15.5, y: 41)),
                (CGPoint(x: 27, y: 35), CGPoint(x: 24.5, y: 41)),
                (CGPoint(x: 36, y: 35), CGPoint(x: 33.5, y: 41)),
            ]
            for (from, to) in dropLines {
                drops.move(to: from)
                drops.addLine(to: to)
            }
            context.stroke(drops, with: .color(Color(red: 0.357, green: 0.553, blue: 0.937)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round)) // #5B8DEF
        }
    }
}

private struct ThunderstormIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            context.fill(rainCloudBasePath(topY: 7, bottomY: 35.7), with: .color(Color(red: 0.482, green: 0.541, blue: 0.659))) // #7B8AA8

            var bolt = Path()
            bolt.move(to: CGPoint(x: 27, y: 22))
            bolt.addLine(to: CGPoint(x: 20, y: 32))
            bolt.addLine(to: CGPoint(x: 25, y: 32))
            bolt.addLine(to: CGPoint(x: 23, y: 41))
            bolt.addLine(to: CGPoint(x: 32, y: 29))
            bolt.addLine(to: CGPoint(x: 26.5, y: 29))
            bolt.closeSubpath()
            context.fill(bolt, with: .color(Color(red: 1.0, green: 0.788, blue: 0.290))) // #FFC94A
        }
    }
}

private struct SnowIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            context.fill(rainCloudBasePath(topY: 8, bottomY: 32), with: .color(Color(red: 0.718, green: 0.761, blue: 0.855))) // #B7C2DA

            let snowColor = Color(red: 0.749, green: 0.878, blue: 1.0) // #BFE0FF
            var flake1 = Path()
            flake1.move(to: CGPoint(x: 18, y: 35)); flake1.addLine(to: CGPoint(x: 18, y: 42))
            flake1.move(to: CGPoint(x: 14.9, y: 36.6)); flake1.addLine(to: CGPoint(x: 21.1, y: 40.4))
            flake1.move(to: CGPoint(x: 21.1, y: 36.6)); flake1.addLine(to: CGPoint(x: 14.9, y: 40.4))
            context.stroke(flake1, with: .color(snowColor), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            var flake2 = Path()
            flake2.move(to: CGPoint(x: 33, y: 35)); flake2.addLine(to: CGPoint(x: 33, y: 42))
            flake2.move(to: CGPoint(x: 29.9, y: 36.6)); flake2.addLine(to: CGPoint(x: 36.1, y: 40.4))
            flake2.move(to: CGPoint(x: 36.1, y: 36.6)); flake2.addLine(to: CGPoint(x: 29.9, y: 40.4))
            context.stroke(flake2, with: .color(snowColor), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

private struct FogIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            context.transform = CGAffineTransform(scaleX: scale, y: scale)

            var lines = Path()
            let fogLines: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 8, y: 16), CGPoint(x: 40, y: 16)),
                (CGPoint(x: 6, y: 24), CGPoint(x: 42, y: 24)),
                (CGPoint(x: 8, y: 32), CGPoint(x: 34, y: 32)),
                (CGPoint(x: 12, y: 40), CGPoint(x: 36, y: 40)),
            ]
            for (from, to) in fogLines {
                lines.move(to: from)
                lines.addLine(to: to)
            }
            context.stroke(lines, with: .color(Color(red: 0.682, green: 0.725, blue: 0.800)), style: StrokeStyle(lineWidth: 3, lineCap: .round)) // #AEB9CC
        }
    }
}
