import Algorithms
import SwiftDate
import SwiftUI

private enum PredictionType: Hashable {
    case iob
    case cob
    case zt
    case uam
}

struct DotInfo {
    let rect: CGRect
    let value: Decimal
}

struct AnnouncementDot {
    let rect: CGRect
    let value: Decimal
    let note: String
}

struct BolusInfo {
    let rect: CGRect
    let value: Decimal
    let issmb: Bool
}

struct ManBolusInfo {
    let rect: CGRect
    let value: Decimal
}

struct OverrideStruct {
    let start: Date
    let end: Date
    let glucose: Int
}

typealias GlucoseYRange = (minValue: Int, minY: CGFloat, maxValue: Int, maxY: CGFloat)

struct MainChartView: View {
    private enum Config {
        static let endID = "End"
        static let basalHeight: CGFloat = 70
        static let topYPadding: CGFloat = 20
        static let bottomYPadding: CGFloat = 40
        static let minAdditionalWidth: CGFloat = 150
        static let maxGlucose: Int = 240
        static let minGlucose: Int = 40
        static let yLinesCount = 5
        static let glucoseScale: CGFloat = 1 // default 2
        static let bolusSize: CGFloat = 8
        static let bolusScale: CGFloat = 2.5
        static let carbsSize: CGFloat = 10
        static let fpuSize: CGFloat = 5
        static let carbsScale: CGFloat = 0.3
        static let fpuScale: CGFloat = 2
        static let announcementSize: CGFloat = 8
        static let announcementScale: CGFloat = 2.5
        static let owlSeize: CGFloat = 25
        static let owlOffset: CGFloat = 70
        static let bolusOffSet: CGFloat = -1.5
        static let ManbolusOffSet: CGFloat = -55
        static let carbsOffSet: CGFloat = 20
        static let carbMaxSize: CGFloat = 80
        static let bolusMaxSize: CGFloat = 16
    }

    private enum Command {
        static let open = "closed"
        static let closed = "opened"
        static let suspend = "suspend"
        static let resume = "resume"
        static let tempbasal = "basal"
        static let bolus = " " // "💧"
        static let meal = "🍴"
        static let override = "👤"
    }

    @Binding var glucose: [BloodGlucose]
    @Binding var isManual: [BloodGlucose]
    @Binding var suggestion: Suggestion?
    @Binding var tempBasals: [PumpHistoryEvent]
    @Binding var boluses: [PumpHistoryEvent]
    @Binding var suspensions: [PumpHistoryEvent]
    @Binding var announcement: [Announcement]
    @Binding var hours: Int
    @Binding var maxBasal: Decimal
    @Binding var autotunedBasalProfile: [BasalProfileEntry]
    @Binding var basalProfile: [BasalProfileEntry]
    @Binding var tempTargets: [TempTarget]
    @Binding var carbs: [CarbsEntry]
    @Binding var timerDate: Date
    @Binding var units: GlucoseUnits
    @Binding var smooth: Bool
    @Binding var highGlucose: Decimal
    @Binding var lowGlucose: Decimal
    @Binding var screenHours: Int
    @Binding var displayXgridLines: Bool
    @Binding var displayYgridLines: Bool
    @Binding var thresholdLines: Bool
    @Binding var triggerUpdate: Bool
    @Binding var overrideHistory: [OverrideHistory]

    @State var didAppearTrigger = false
    @State private var glucoseDots: [CGRect] = []
    @State private var manualGlucoseDots: [CGRect] = []
    @State private var announcementDots: [AnnouncementDot] = []
    @State private var announcementPath = Path()
    @State private var manualGlucoseDotsCenter: [CGRect] = []
    @State private var unSmoothedGlucoseDots: [CGRect] = []
    @State private var predictionDots: [PredictionType: [CGRect]] = [:]
    // @State private var bolusDots: [DotInfo] = []
    @State private var bolusDots: [BolusInfo] = []
    @State private var bolusPath = Path()
    @State private var ManbolusDots: [ManBolusInfo] = []
    @State private var ManbolusPath = Path()
    @State private var tempBasalPath = Path()
    @State private var regularBasalPath = Path()
    @State private var tempTargetsPath = Path()
    @State private var overridesPath = Path()
    @State private var suspensionsPath = Path()
    @State private var carbsDots: [DotInfo] = []
    @State private var fpuDots: [DotInfo] = []
    @State private var glucoseYRange: GlucoseYRange = (0, 0, 0, 0)
    @State private var cachedMaxBasalRate: Decimal?
    private var zoomScale: Double {
        1.0 / Double(screenHours)
    }

    private let calculationQueue = DispatchQueue(
        label: "MainChartView.calculationQueue",
        qos: .userInteractive,
        attributes: .concurrent
    )

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var date24Formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.setLocalizedDateFormatFromTemplate("HH")
        return formatter
    }

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }

    private var bolusFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        return formatter
    }

    private var carbsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private var fpuFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.decimalSeparator = "."
        formatter.minimumIntegerDigits = 0
        return formatter
    }

    @Environment(\.horizontalSizeClass) var hSizeClass
    @Environment(\.verticalSizeClass) var vSizeClass

    // MARK: - Views

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                yGridView(fullSize: geo.size)
                mainScrollView(fullSize: geo.size)
                glucoseLabelsView(fullSize: geo.size)
            }
            .onChange(of: hSizeClass) { _ in
                update(fullSize: geo.size)
            }
            .onChange(of: vSizeClass) { _ in
                update(fullSize: geo.size)
            }
            .onReceive(
                Foundation.NotificationCenter.default
                    .publisher(for: UIDevice.orientationDidChangeNotification)
            ) { _ in
                update(fullSize: geo.size)
            }
        }
    }

    private func mainScrollView(fullSize: CGSize) -> some View {
        ScrollViewReader { scroll in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .top) {
                    tempTargetsView(fullSize: fullSize).drawingGroup()
                    overridesView(fullSize: fullSize).drawingGroup()
                    basalView(fullSize: fullSize).drawingGroup()
                    mainView(fullSize: fullSize).id(Config.endID)
                        .drawingGroup()
                }
            }
            .onChange(of: glucose) { _ in
                scroll.scrollTo(Config.endID, anchor: .trailing)
            }
            .onChange(of: suggestion) { _ in
                scroll.scrollTo(Config.endID, anchor: .trailing)
            }
            .onChange(of: tempBasals) { _ in
                scroll.scrollTo(Config.endID, anchor: .trailing)
            }
            .onChange(of: screenHours) { _ in
                scroll.scrollTo(Config.endID, anchor: .trailing)
            }
            .onAppear {
                // add trigger to the end of main queue
                DispatchQueue.main.async {
                    scroll.scrollTo(Config.endID, anchor: .trailing)
                    didAppearTrigger = true
                }
            }
        }
    }

    private func yGridView(fullSize: CGSize) -> some View {
        let useColour = displayYgridLines ? Color.secondary : Color.clear
        return ZStack {
            Path { path in
                let range = glucoseYRange
                let step = (range.maxY - range.minY) / CGFloat(Config.yLinesCount)
                for line in 0 ... Config.yLinesCount {
                    path.move(to: CGPoint(x: 0, y: range.minY + CGFloat(line) * step))
                    path.addLine(to: CGPoint(x: fullSize.width, y: range.minY + CGFloat(line) * step))
                }
            }.stroke(useColour, lineWidth: 0.15)

            // horizontal limits
            if thresholdLines {
                let range = glucoseYRange
                let topstep = (range.maxY - range.minY) / CGFloat(range.maxValue - range.minValue) *
                    (CGFloat(range.maxValue) - CGFloat(highGlucose))
                if CGFloat(range.maxValue) > CGFloat(highGlucose) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: range.minY + topstep))
                        path.addLine(to: CGPoint(x: fullSize.width, y: range.minY + topstep))
                    }.stroke(Color.loopYellow, lineWidth: 0.5) // .StrokeStyle(lineWidth: 0.5, dash: [5])
                }
                let yrange = glucoseYRange
                let bottomstep = (yrange.maxY - yrange.minY) / CGFloat(yrange.maxValue - yrange.minValue) *
                    (CGFloat(yrange.maxValue) - CGFloat(lowGlucose))
                if CGFloat(yrange.minValue) < CGFloat(lowGlucose) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yrange.minY + bottomstep))
                        path.addLine(to: CGPoint(x: fullSize.width, y: yrange.minY + bottomstep))
                    }.stroke(Color.loopRed, lineWidth: 0.5)
                }
            }
        }
    }

    private func glucoseLabelsView(fullSize: CGSize) -> some View {
        ForEach(0 ..< Config.yLinesCount + 1, id: \.self) { line -> AnyView in
            let range = glucoseYRange
            let yStep = (range.maxY - range.minY) / CGFloat(Config.yLinesCount)
            let valueStep = Double(range.maxValue - range.minValue) / Double(Config.yLinesCount)
            let value = round(Double(range.maxValue) - Double(line) * valueStep) *
                (units == .mmolL ? Double(GlucoseUnits.exchangeRate) : 1)

            return Text(glucoseFormatter.string(from: value as NSNumber)!)
                .position(CGPoint(x: fullSize.width - 12, y: range.minY + CGFloat(line) * yStep))
                .font(.caption2)
                .asAny()
        }
    }

    private func basalView(fullSize: CGSize) -> some View {
        ZStack {
            tempBasalPath.scale(x: zoomScale, anchor: .zero).fill(Color.basal.opacity(0.5))
            tempBasalPath.scale(x: zoomScale, anchor: .zero).stroke(Color.insulin, lineWidth: 1)
            regularBasalPath.scale(x: zoomScale, anchor: .zero)
                .stroke(Color.insulin, style: StrokeStyle(lineWidth: 0.7, dash: [4]))
            suspensionsPath.scale(x: zoomScale, anchor: .zero)
                .stroke(Color.loopGray.opacity(0.7), style: StrokeStyle(lineWidth: 0.7)).scaleEffect(x: 1, y: -1)
            suspensionsPath.scale(x: zoomScale, anchor: .zero).fill(Color.loopGray.opacity(0.2)).scaleEffect(x: 1, y: -1)
        }
        .scaleEffect(x: 1, y: -1)
        .frame(width: glucoseAndAdditionalWidth(fullSize: fullSize))
        .frame(maxHeight: Config.basalHeight)
        .background(Color.clear)
        .onChange(of: tempBasals) { _ in
            calculateBasalPoints(fullSize: fullSize)
        }
        .onChange(of: suspensions) { _ in
            calculateSuspensions(fullSize: fullSize)
        }
        .onChange(of: maxBasal) { _ in
            calculateBasalPoints(fullSize: fullSize)
        }
        .onChange(of: autotunedBasalProfile) { _ in
            calculateBasalPoints(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateBasalPoints(fullSize: fullSize)
        }
    }

    private func mainView(fullSize: CGSize) -> some View {
        VStack {
            ZStack {
                xGridView(fullSize: fullSize)
                carbsView(fullSize: fullSize)
                fpuView(fullSize: fullSize)
                bolusView(fullSize: fullSize)
                ManbolusView(fullSize: fullSize)
                if smooth { unSmoothedGlucoseView(fullSize: fullSize) }
                glucoseView(fullSize: fullSize)
                manualGlucoseView(fullSize: fullSize)
                manualGlucoseCenterView(fullSize: fullSize)
                announcementView(fullSize: fullSize)
                predictionsView(fullSize: fullSize)
            }
            timeLabelsView(fullSize: fullSize)
        }
        .frame(width: glucoseAndAdditionalWidth(fullSize: fullSize))
    }

    /// returns the width of the full chart view including predictions for the current `screenHours`
    private func glucoseAndAdditionalWidth(fullSize: CGSize) -> CGFloat {
        // fullGlucoseWidth returns the width scaled to 1h screen hours. Scale it down to screenHours
        fullGlucoseWidth(viewWidth: fullSize.width) / CGFloat(screenHours)
            + additionalWidthScaled(viewWidth: fullSize.width)
    }

    /// returns the additional width for predictions, scaled to `screenHours`
    private func additionalWidthScaled(viewWidth: CGFloat) -> CGFloat {
        guard let predictions = suggestion?.predictions,
              let deliveredAt = suggestion?.deliverAt,
              let last = glucose.last
        else {
            return Config.minAdditionalWidth
        }

        let iob = predictions.iob?.count ?? 0
        let zt = predictions.zt?.count ?? 0
        let cob = predictions.cob?.count ?? 0
        let uam = predictions.uam?.count ?? 0
        let max = [iob, zt, cob, uam].max() ?? 0

        let lastDeltaTime = last.dateString.timeIntervalSince(deliveredAt)
        let additionalTime = CGFloat(TimeInterval(max) * 5.minutes.timeInterval - lastDeltaTime)
        let oneSecondWidth = oneSecondStep(viewWidth: viewWidth) / CGFloat(screenHours)

        return Swift.min(Swift.max(additionalTime * oneSecondWidth, Config.minAdditionalWidth), 275)
    }

    @Environment(\.colorScheme) var colorScheme

    private func xGridView(fullSize: CGSize) -> some View {
        let useColour = displayXgridLines ? Color.secondary : Color.clear
        return ZStack {
            Path { path in
                for hour in 0 ..< hours + hours {
                    if screenHours >= 12 && hour % 2 == 1 {
                        continue
                    }
                    let x = (
                        firstHourPosition(viewWidth: fullSize.width) +
                            oneSecondStep(viewWidth: fullSize.width) *
                            CGFloat(hour) * CGFloat(1.hours.timeInterval)
                    ) * zoomScale
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: fullSize.height - 20))
                }
            }
            .stroke(useColour, lineWidth: 0.15)

            Path { path in // vertical timeline
                let x = timeToXCoordinate(timerDate.timeIntervalSince1970, fullSize: fullSize) * zoomScale
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: fullSize.height - 20))
            }
            .stroke(
                colorScheme == .dark ? Color.white : Color.black,
                style: StrokeStyle(lineWidth: 0.5, dash: [5])
            )
        }
    }

    private func timeLabelsView(fullSize: CGSize) -> some View {
        let format = screenHours > 6 ? date24Formatter : dateFormatter
        return ZStack {
            // X time labels
            ForEach(0 ..< hours + hours, id: \.self) { hour in
                // show every other label
                if screenHours >= 12 && hour % 2 == 0 {
                    Text(format.string(from: firstHourDate().addingTimeInterval(hour.hours.timeInterval)))
                        .font(.caption)
                        .position(
                            x: (
                                firstHourPosition(viewWidth: fullSize.width) +
                                    oneSecondStep(viewWidth: fullSize.width) *
                                    CGFloat(hour) * CGFloat(1.hours.timeInterval)
                            ) * zoomScale,
                            y: 10.0
                        )
                        .foregroundColor(.secondary)
                } else if screenHours < 12 {
                    // show every label
                    Text(format.string(from: firstHourDate().addingTimeInterval(hour.hours.timeInterval)))
                        .font(.caption)
                        .position(
                            x: (
                                firstHourPosition(viewWidth: fullSize.width) +
                                    oneSecondStep(viewWidth: fullSize.width) *
                                    CGFloat(hour) * CGFloat(1.hours.timeInterval)
                            ) * zoomScale,
                            y: 10.0
                        )
                        .foregroundColor(.secondary)
                }
            }
        }.frame(maxHeight: 20)
    }

    private func glucoseView(fullSize: CGSize) -> some View {
        Path { path in
            for rect in glucoseDots {
                path.addEllipse(in: scaleCenter(rect: rect))
            }
        }
        .fill(Color.loopGreen)
        .onChange(of: glucose) { _ in
            update(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            update(fullSize: fullSize)
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            update(fullSize: fullSize)
        }
    }

    private func manualGlucoseView(fullSize: CGSize) -> some View {
        Path { path in
            for rect in manualGlucoseDots {
                path.addEllipse(in: scaleCenter(rect: rect))
            }
        }
        .fill(Color.gray)
        .onChange(of: isManual) { _ in
            update(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            update(fullSize: fullSize)
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            update(fullSize: fullSize)
        }
    }

    private func announcementView(fullSize: CGSize) -> some View {
        ZStack {
            ForEach(announcementDots, id: \.rect.minX) { info -> AnyView in
                let position = CGPoint(x: info.rect.midX, y: info.rect.maxY - Config.owlOffset)
                let command = info.note.lowercased()
                let type: String =
                    command.contains("true") ?
                    Command.closed :
                    command.contains("false") ?
                    Command.open :
                    command.contains("suspend") ?
                    Command.suspend :
                    command.contains("resume") ?
                    Command.resume :
                    command.contains("tempbasal") ?
                    Command.tempbasal :
                    command.contains("override") ?
                    Command.override :
                    command.contains("meal") ?
                    Command.meal :
                    command.contains("bolus") ?
                    Command.bolus : ""

                VStack {
                    Text(type).font(.caption2).foregroundStyle(.orange)
//                    Image("owl").resizable().frame(maxWidth: Config.owlSeize, maxHeight: Config.owlSeize).scaledToFill()
                    Image(systemName: "icloud.and.arrow.down").resizable()
                        .frame(maxWidth: Config.owlSeize, maxHeight: Config.owlSeize).scaledToFill()
                        .symbolRenderingMode(.monochrome).foregroundStyle(Color.loopYellow)
                }.position(position).asAny()
            }
        }
        .onChange(of: announcement) { _ in
            calculateAnnouncementDots(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateAnnouncementDots(fullSize: fullSize)
        }
    }

    private func manualGlucoseCenterView(fullSize: CGSize) -> some View {
        Path { path in
            for rect in manualGlucoseDotsCenter {
                path.addEllipse(in: scaleCenter(rect: rect))
            }
        }
        .fill(Color.pink)

        .onChange(of: isManual) { _ in
            update(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            update(fullSize: fullSize)
        }
        .onReceive(
            Foundation.NotificationCenter.default
                .publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            update(fullSize: fullSize)
        }
    }

    private func unSmoothedGlucoseView(fullSize: CGSize) -> some View {
        Path { path in
            var lines: [CGPoint] = []
            for rect in unSmoothedGlucoseDots {
                let scaled = scaleCenter(rect: rect)
                lines.append(CGPoint(x: scaled.midX, y: scaled.midY))
                path.addEllipse(in: scaled)
            }
            path.addLines(lines)
        }
        .stroke(Color.loopGray, lineWidth: 0.5)
        .onChange(of: glucose) { _ in
            update(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            update(fullSize: fullSize)
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            update(fullSize: fullSize)
        }
    }

    private func bolusView(fullSize: CGSize) -> some View {
        ZStack {
            let bolusPath = Path { path in
                for dot in bolusDots {
                    let rect = scaleCenter(rect: dot.rect)
                    if dot.issmb {
                        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                    } else {
                        path.addEllipse(in: rect)
                    }
                }
            }
            bolusPath.fill(Color.insulin)
            bolusPath.stroke(Color.primary, lineWidth: 0.5)
            ForEach(bolusDots, id: \.rect.minX) { info -> AnyView in
                let rect = scaleCenter(rect: info.rect)
                let position = CGPoint(x: rect.midX, y: rect.minY - 8)
                return Text(bolusFormatter.string(from: info.value as NSNumber)!).font(.caption2)
                    .position(position)
                    .asAny()
            }
        }
        .onChange(of: boluses) { _ in
            calculateBolusDots(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateBolusDots(fullSize: fullSize)
        }
    }

    private func ManbolusView(fullSize: CGSize) -> some View {
        ZStack {
            let ManbolusPath = Path { path in
                for dot in ManbolusDots {
                    let rect = scaleCenter(rect: dot.rect)
                    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                    path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                }
            }
            ManbolusPath.fill(Color.pink)
            ManbolusPath.stroke(Color.primary, lineWidth: 0.5)
            ForEach(ManbolusDots, id: \.rect.minX) { info -> AnyView in
                let rect = scaleCenter(rect: info.rect)
                let position = CGPoint(x: rect.midX, y: rect.minY - 8)
                return Text(bolusFormatter.string(from: info.value as NSNumber)!).font(.caption2)
                    .position(position)
                    .asAny()
            }
        }
        .onChange(of: boluses) { _ in
            calculateManBolusDots(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateManBolusDots(fullSize: fullSize)
        }
    }

    private func carbsView(fullSize: CGSize) -> some View {
        ZStack {
            let carbsPath = Path { path in
                for dot in carbsDots {
                    path.addEllipse(in: scaleCenter(rect: dot.rect))
                }
            }

            carbsPath
                .fill(Color.loopYellow)
            carbsPath
                .stroke(Color.primary, lineWidth: 0.5)

            ForEach(carbsDots, id: \.rect.minX) { info -> AnyView in
                let rect = scaleCenter(rect: info.rect)

                let position = CGPoint(x: rect.midX, y: rect.maxY + 8)
                return Text(carbsFormatter.string(from: info.value as NSNumber)!).font(.caption2)
                    .position(position)
                    .asAny()
            }
        }
        .onChange(of: carbs) { _ in
            calculateCarbsDots(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateCarbsDots(fullSize: fullSize)
        }
    }

    private func fpuView(fullSize: CGSize) -> some View {
        ZStack {
            let fpuPath = Path { path in
                for dot in fpuDots {
                    path.addEllipse(in: scaleCenter(rect: dot.rect))
                }
            }

            fpuPath
                .fill(Color.loopRed)
            fpuPath
                .stroke(Color.loopYellow, lineWidth: 0.5)

            ForEach(fpuDots, id: \.rect.minX) { info -> AnyView in
                let position = CGPoint(x: info.rect.midX, y: info.rect.maxY + 8)
                return Text(fpuFormatter.string(from: info.value as NSNumber)!).font(.caption2)
                    .position(position)
                    .asAny()
            }
        }
        .onChange(of: carbs) { _ in
            calculateFPUsDots(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateFPUsDots(fullSize: fullSize)
        }
    }

    private func scale(rect: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: rect.origin.x * zoomScale, y: rect.origin.y), size: rect.size)
    }

    private func scaleCenter(rect: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: rect.midX * zoomScale - rect.width / 2, y: rect.origin.y), size: rect.size)
    }

    private func tempTargetsView(fullSize: CGSize) -> some View {
        ZStack {
            tempTargetsPath
                .scale(x: zoomScale, anchor: .zero)
                .fill(Color.loopGreen.opacity(0.5))
            tempTargetsPath
                .scale(x: zoomScale, anchor: .zero)
                .stroke(Color.basal.opacity(0.8), lineWidth: 1)
        }
        .onChange(of: glucose) { _ in
            calculateTempTargetsRects(fullSize: fullSize)
        }
        .onChange(of: tempTargets) { _ in
            calculateTempTargetsRects(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateTempTargetsRects(fullSize: fullSize)
        }
    }

    private func overridesView(fullSize: CGSize) -> some View {
        ZStack {
            overridesPath
                .scale(x: zoomScale, anchor: .zero)
                .fill(Color.violet.opacity(colorScheme == .light ? 0.3 : 0.6))
            overridesPath
                .scale(x: zoomScale, anchor: .zero)
                .stroke(Color.violet.opacity(0.7), lineWidth: 1)
        }
        .onChange(of: glucose) { _ in
            calculateOverridesRects(fullSize: fullSize)
        }
        .onChange(of: suggestion) { _ in
            calculateOverridesRects(fullSize: fullSize)
        }
        .onChange(of: overrideHistory) { _ in
            calculateOverridesRects(fullSize: fullSize)
        }
        .onChange(of: triggerUpdate) { _ in
            calculateOverridesRects(fullSize: fullSize)
        }
        .onChange(of: didAppearTrigger) { _ in
            calculateOverridesRects(fullSize: fullSize)
        }
    }

    private func predictionsView(fullSize: CGSize) -> some View {
        Group {
            Path { path in
                for rect in predictionDots[.iob] ?? [] {
                    path.addEllipse(in: scaleCenter(rect: rect))
                }
            }.fill(Color.insulin)

            Path { path in
                for rect in predictionDots[.cob] ?? [] {
                    path.addEllipse(in: scaleCenter(rect: rect))
                }
            }.fill(Color.loopYellow)

            Path { path in
                for rect in predictionDots[.zt] ?? [] {
                    path.addEllipse(in: scaleCenter(rect: rect))
                }
            }.fill(Color.zt)

            Path { path in
                for rect in predictionDots[.uam] ?? [] {
                    path.addEllipse(in: scaleCenter(rect: rect))
                }
            }.fill(Color.uam)
        }
        .onChange(of: suggestion) { _ in
            update(fullSize: fullSize)
        }
    }
}

// MARK: - Calculations

/// some of the calculations done here can take quite long (100ms+) and are not able to update data at a fast rate
/// therefore we stick to the 1h screen window for these calculations and scale the results as needed to `screenHours` which has little extra overhead and enables changing the screen hours with no lag
extension MainChartView {
    private func update(fullSize: CGSize) {
        calculatePredictionDots(fullSize: fullSize, type: .iob)
        calculatePredictionDots(fullSize: fullSize, type: .cob)
        calculatePredictionDots(fullSize: fullSize, type: .zt)
        calculatePredictionDots(fullSize: fullSize, type: .uam)
        calculateGlucoseDots(fullSize: fullSize)
        calculateManualGlucoseDots(fullSize: fullSize)
        calculateManualGlucoseDotsCenter(fullSize: fullSize)
        calculateAnnouncementDots(fullSize: fullSize)
        calculateUnSmoothedGlucoseDots(fullSize: fullSize)
        calculateBolusDots(fullSize: fullSize)
        calculateManBolusDots(fullSize: fullSize)
        calculateCarbsDots(fullSize: fullSize)
        calculateFPUsDots(fullSize: fullSize)
        calculateTempTargetsRects(fullSize: fullSize)
        calculateOverridesRects(fullSize: fullSize)
        calculateBasalPoints(fullSize: fullSize)
        calculateSuspensions(fullSize: fullSize)
    }

    private func calculateGlucoseDots(fullSize: CGSize) {
        calculationQueue.async {
            let dots = glucose.concurrentMap { value -> CGRect in
                let position = glucoseToCoordinate(value, fullSize: fullSize)
                return CGRect(x: position.x - 2, y: position.y - 2, width: 4, height: 4)
            }

            let range = self.getGlucoseYRange(fullSize: fullSize)

            DispatchQueue.main.async {
                glucoseYRange = range
                glucoseDots = dots
            }
        }
    }

    private func calculateManualGlucoseDots(fullSize: CGSize) {
        calculationQueue.async {
            let dots = isManual.concurrentMap { value -> CGRect in
                let position = glucoseToCoordinate(value, fullSize: fullSize)
                return CGRect(x: position.x - 2, y: position.y - 2, width: 14, height: 14)
            }

            let range = self.getGlucoseYRange(fullSize: fullSize)

            DispatchQueue.main.async {
                glucoseYRange = range
                manualGlucoseDots = dots
            }
        }
    }

    private func calculateManualGlucoseDotsCenter(fullSize: CGSize) {
        calculationQueue.async {
            let dots = isManual.concurrentMap { value -> CGRect in
                let position = glucoseToCoordinate(value, fullSize: fullSize)
                return CGRect(x: position.x, y: position.y, width: 10, height: 10)
            }

            let range = self.getGlucoseYRange(fullSize: fullSize)

            DispatchQueue.main.async {
                glucoseYRange = range
                manualGlucoseDotsCenter = dots
            }
        }
    }

    private func calculateAnnouncementDots(fullSize: CGSize) {
        calculationQueue.async {
            let dots = announcement.map { value -> AnnouncementDot in
                let center = timeToInterpolatedPoint(value.createdAt.timeIntervalSince1970, fullSize: fullSize)
                let size = Config.announcementSize * Config.announcementScale
                let rect = CGRect(
                    x: center.x - size / 2,
                    y: center.y - size / 2,
                    width: size, height: size
                )
                let note = value.notes
                return AnnouncementDot(rect: rect, value: 10, note: note)
            }
            let path = Path { path in
                for dot in dots {
                    path.addEllipse(in: dot.rect)
                }
            }
            let range = self.getGlucoseYRange(fullSize: fullSize)

            DispatchQueue.main.async {
                glucoseYRange = range
                announcementDots = dots
                announcementPath = path
            }
        }
    }

    private func calculateUnSmoothedGlucoseDots(fullSize: CGSize) {
        calculationQueue.async {
            let dots = glucose.concurrentMap { value -> CGRect in
                let position = UnSmoothedGlucoseToCoordinate(value, fullSize: fullSize)
                return CGRect(x: position.x - 2, y: position.y - 2, width: 4, height: 4)
            }

            let range = self.getGlucoseYRange(fullSize: fullSize)

            DispatchQueue.main.async {
                glucoseYRange = range
                unSmoothedGlucoseDots = dots
            }
        }
    }

    private func calculateBolusDots(fullSize: CGSize) {
        calculationQueue.async {
            let regboluses = boluses.filter { $0.isExternal == false }
            let dots = regboluses.map { value -> BolusInfo in
                let center = timeToInterpolatedPoint(value.timestamp.timeIntervalSince1970, fullSize: fullSize)
                var size = Config.bolusSize + CGFloat(value.amount ?? 0) * 2 * Config.bolusScale
                if value.isExternal == true { size = 0 }
                var rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
                if value.isSMB ?? false {
                    rect = CGRect(
                        x: center.x - size / 2,
                        y: center.y - size / 2 + Config.bolusOffSet - size * Config.bolusScale,
                        width: size,
                        height: size
                    )
                }
                return BolusInfo(
                    rect: rect,
                    value: value.amount ?? 0,
                    issmb: value.isSMB ?? false
                )
            }

            DispatchQueue.main.async {
                bolusDots = dots
            }
        }
    }

    private func calculateManBolusDots(fullSize: CGSize) {
        calculationQueue.async {
            let manboluses = boluses.filter { $0.isExternal ?? false }
            let dots = manboluses.map { value -> ManBolusInfo in
                let center = timeToInterpolatedPoint(value.timestamp.timeIntervalSince1970, fullSize: fullSize)
                let size = Config.bolusSize + CGFloat(value.amount ?? 0) * 2 * Config.bolusScale
                let rect = CGRect(
                    x: center.x - size / 2,
                    y: center.y - size / 2 + Config.ManbolusOffSet,
                    width: size / 2,
                    height: size * 1.3 / 2
                )

                return ManBolusInfo(
                    rect: rect,
                    value: value.amount ?? 0
                )
            }

            DispatchQueue.main.async {
                ManbolusDots = dots
            }
        }
    }

    private func calculateCarbsDots(fullSize: CGSize) {
        calculationQueue.async {
            let realCarbs = carbs.filter { !($0.isFPU ?? false) }
            let dots = realCarbs.map { value -> DotInfo in
                let center = timeToInterpolatedPoint(
                    value.actualDate != nil ? (value.actualDate ?? Date()).timeIntervalSince1970 : value.createdAt
                        .timeIntervalSince1970,
                    fullSize: fullSize
                )
                let size = min(Config.carbsSize + CGFloat(value.carbs) * Config.carbsScale, Config.carbMaxSize)
                let rect = CGRect(
                    x: center.x - size / 2,
                    y: center.y - (size / 2) + Config.carbsOffSet,
                    width: size,
                    height: size
                )
                return DotInfo(rect: rect, value: value.carbs)
            }

            DispatchQueue.main.async {
                carbsDots = dots
            }
        }
    }

    private func calculateFPUsDots(fullSize: CGSize) {
        calculationQueue.async {
            let fpus = carbs.filter { $0.isFPU ?? false }
            let dots = fpus.map { value -> DotInfo in
                let center = timeToInterpolatedPoint(
                    value.actualDate != nil ? (value.actualDate ?? Date()).timeIntervalSince1970 : value.createdAt
                        .timeIntervalSince1970,
                    fullSize: fullSize
                )
                let size = Config.fpuSize + CGFloat(value.carbs) * Config.fpuScale
                let rect = CGRect(
                    x: center.x - size / 2,
                    y: center.y - (size / 2) + Config.carbsOffSet / 2,
                    width: size, height: size
                )
                return DotInfo(rect: rect, value: value.carbs)
            }

            DispatchQueue.main.async {
                fpuDots = dots
            }
        }
    }

    private func calculatePredictionDots(fullSize: CGSize, type: PredictionType) {
        calculationQueue.async {
            let values: [Int] = { () -> [Int] in
                switch type {
                case .iob:
                    return suggestion?.predictions?.iob ?? []
                case .cob:
                    return suggestion?.predictions?.cob ?? []
                case .zt:
                    return suggestion?.predictions?.zt ?? []
                case .uam:
                    return suggestion?.predictions?.uam ?? []
                }
            }()

            var index = 0
            let dots = values.map { value -> CGRect in
                let position = predictionToCoordinate(value, fullSize: fullSize, index: index)
                index += 1
                return CGRect(x: position.x - 2, y: position.y - 2, width: 4, height: 4)
            }
            DispatchQueue.main.async {
                predictionDots[type] = dots
            }
        }
    }

    private func calculateBasalPoints(fullSize: CGSize) {
        calculationQueue.async {
            self.cachedMaxBasalRate = nil
            let dayAgoTime = Date().addingTimeInterval(-1.days.timeInterval).timeIntervalSince1970
            let firstTempTime = (tempBasals.first?.timestamp ?? Date()).timeIntervalSince1970
            var lastTimeEnd = firstTempTime
            let firstRegularBasalPoints = findRegularBasalPoints(
                timeBegin: dayAgoTime,
                timeEnd: firstTempTime,
                fullSize: fullSize,
                autotuned: false
            )
            let tempBasalPoints = firstRegularBasalPoints + tempBasals.chunks(ofCount: 2).map { chunk -> [CGPoint] in
                let chunk = Array(chunk)
                guard chunk.count == 2, chunk[0].type == .tempBasal, chunk[1].type == .tempBasalDuration else { return [] }
                let timeBegin = chunk[0].timestamp.timeIntervalSince1970
                let timeEnd = timeBegin + (chunk[1].durationMin ?? 0).minutes.timeInterval
                let rateCost = Config.basalHeight / CGFloat(maxBasalRate())
                let x0 = timeToXCoordinate(timeBegin, fullSize: fullSize)
                let y0 = Config.basalHeight - CGFloat(chunk[0].rate ?? 0) * rateCost
                let regularPoints = findRegularBasalPoints(
                    timeBegin: lastTimeEnd,
                    timeEnd: timeBegin,
                    fullSize: fullSize,
                    autotuned: false
                )
                lastTimeEnd = timeEnd
                return regularPoints + [CGPoint(x: x0, y: y0)]
            }.flatMap { $0 }
            let tempBasalPath = Path { path in
                var yPoint: CGFloat = Config.basalHeight
                path.move(to: CGPoint(x: 0, y: yPoint))

                for point in tempBasalPoints {
                    path.addLine(to: CGPoint(x: point.x, y: yPoint))
                    path.addLine(to: point)
                    yPoint = point.y
                }
                let lastPoint = lastBasalPoint(fullSize: fullSize)
                path.addLine(to: CGPoint(x: lastPoint.x, y: yPoint))
                path.addLine(to: CGPoint(x: lastPoint.x, y: Config.basalHeight))
                path.addLine(to: CGPoint(x: 0, y: Config.basalHeight))
            }
            let endDateTime = dayAgoTime + 12.hours
                .timeInterval + 12.hours
                .timeInterval
            let autotunedBasalPoints = findRegularBasalPoints(
                timeBegin: dayAgoTime,
                timeEnd: endDateTime,
                fullSize: fullSize,
                autotuned: true
            )

            let autotunedBasalPath = Path { path in
                var yPoint: CGFloat = Config.basalHeight
                path.move(to: CGPoint(x: -50, y: yPoint))

                for point in autotunedBasalPoints {
                    path.addLine(to: CGPoint(x: point.x, y: yPoint))
                    path.addLine(to: point)
                    yPoint = point.y
                }
                path.addLine(to: CGPoint(x: timeToXCoordinate(endDateTime, fullSize: fullSize), y: yPoint))
            }

            DispatchQueue.main.async {
                self.tempBasalPath = tempBasalPath
                self.regularBasalPath = autotunedBasalPath
            }
        }
    }

    private func calculateSuspensions(fullSize: CGSize) {
        calculationQueue.async {
            var rects = suspensions.windows(ofCount: 2).map { window -> CGRect? in
                let window = Array(window)
                guard window[0].type == .pumpSuspend, window[1].type == .pumpResume else { return nil }
                let x0 = self.timeToXCoordinate(window[0].timestamp.timeIntervalSince1970, fullSize: fullSize)
                let x1 = self.timeToXCoordinate(window[1].timestamp.timeIntervalSince1970, fullSize: fullSize)
                return CGRect(x: x0, y: 0, width: x1 - x0, height: Config.basalHeight * 0.7)
            }

            let firstRec = self.suspensions.first.flatMap { event -> CGRect? in
                guard event.type == .pumpResume else { return nil }
                let tbrTime = self.tempBasals.last { $0.timestamp < event.timestamp }
                    .map { $0.timestamp.timeIntervalSince1970 + TimeInterval($0.durationMin ?? 0) * 60 } ?? Date()
                    .addingTimeInterval(-1.days.timeInterval).timeIntervalSince1970

                let x0 = self.timeToXCoordinate(tbrTime, fullSize: fullSize)
                let x1 = self.timeToXCoordinate(event.timestamp.timeIntervalSince1970, fullSize: fullSize)
                return CGRect(
                    x: x0,
                    y: 0,
                    width: x1 - x0,
                    height: Config.basalHeight * 0.7
                )
            }

            let lastRec = self.suspensions.last.flatMap { event -> CGRect? in
                guard event.type == .pumpSuspend else { return nil }
                let tbrTimeX = self.tempBasals.first { $0.timestamp > event.timestamp }
                    .map { self.timeToXCoordinate($0.timestamp.timeIntervalSince1970, fullSize: fullSize) }
                let x0 = self.timeToXCoordinate(event.timestamp.timeIntervalSince1970, fullSize: fullSize)

                let x1 = tbrTimeX ?? self.fullGlucoseWidth(viewWidth: fullSize.width) + 275

                return CGRect(x: x0, y: 0, width: x1 - x0, height: Config.basalHeight * 0.7)
            }
            rects.append(firstRec)
            rects.append(lastRec)

            let path = Path { path in
                path.addRects(rects.compactMap { $0 })
            }

            DispatchQueue.main.async {
                suspensionsPath = path
            }
        }
    }

    private func maxBasalRate() -> Decimal {
        if let cached = cachedMaxBasalRate {
            return cached
        }

        let maxRegularBasalRate = max(
            basalProfile.map(\.rate).max() ?? maxBasal,
            autotunedBasalProfile.map(\.rate).max() ?? maxBasal
        )

        var maxTempBasalRate = tempBasals.compactMap(\.rate).max() ?? maxRegularBasalRate
        if maxTempBasalRate == 0 {
            maxTempBasalRate = maxRegularBasalRate
        }

        cachedMaxBasalRate = max(maxTempBasalRate, maxRegularBasalRate)
        return cachedMaxBasalRate ?? maxBasal
    }

    private func calculateTempTargetsRects(fullSize: CGSize) {
        calculationQueue.async {
            var rects = tempTargets.map { tempTarget -> CGRect in
                let x0 = timeToXCoordinate(tempTarget.createdAt.timeIntervalSince1970, fullSize: fullSize)
                let y0 = glucoseToYCoordinate(Int(tempTarget.targetTop ?? 0), fullSize: fullSize)
                let x1 = timeToXCoordinate(
                    tempTarget.createdAt.timeIntervalSince1970 + Int(tempTarget.duration).minutes.timeInterval,
                    fullSize: fullSize
                )
                let y1 = glucoseToYCoordinate(Int(tempTarget.targetBottom ?? 0), fullSize: fullSize)
                return CGRect(
                    x: x0,
                    y: y0 - 3,
                    width: x1 - x0,
                    height: y1 - y0 + 6
                )
            }
            if rects.count > 1 {
                rects = rects.reduce([]) { result, rect -> [CGRect] in
                    guard var last = result.last else { return [rect] }
                    if last.origin.x + last.width > rect.origin.x {
                        last.size.width = rect.origin.x - last.origin.x
                    }
                    var res = Array(result.dropLast())
                    res.append(contentsOf: [last, rect])
                    return res
                }
            }
            let path = Path { path in
                path.addRects(rects)
            }
            DispatchQueue.main.async {
                tempTargetsPath = path
            }
        }
    }

    private func calculateOverridesRects(fullSize: CGSize) {
        calculationQueue.async {
            let latest = OverrideStorage().fetchLatestOverride().first
            let rects = overrideHistory.compactMap { each -> CGRect in
                let placeY = Int(each.target) < Config.minGlucose ? Config.minGlucose : Int(each.target)
                let duration = each.duration
                let xStart = timeToXCoordinate(each.date!.timeIntervalSince1970, fullSize: fullSize)
                let xEnd = timeToXCoordinate(
                    each.date!.addingTimeInterval(Int(duration).minutes.timeInterval).timeIntervalSince1970,
                    fullSize: fullSize
                )
                let y = glucoseToYCoordinate(placeY, fullSize: fullSize)
                return CGRect(
                    x: xStart,
                    y: y - 3,
                    width: xEnd - xStart,
                    height: 8
                )
            }
            // Display active Override
            if let last = latest, last.enabled {
                var old = Array(rects)
                let duration = Double(last.duration ?? 0)
                // Looks better when target isn't == 0 in Home View Main Chart
                let targetRaw = last.target ?? 0
                let target = Int(targetRaw) < Config.minGlucose ? Config.minGlucose : Int(targetRaw)

                if duration > 0 {
                    let x1 = timeToXCoordinate((latest?.date ?? Date.now).timeIntervalSince1970, fullSize: fullSize)
                    let plusNow = (last.date ?? Date.now).addingTimeInterval(Int(latest?.duration ?? 0).minutes.timeInterval)
                    let x2 = timeToXCoordinate(plusNow.timeIntervalSince1970, fullSize: fullSize)
                    let oneMore = CGRect(
                        x: x1,
                        y: glucoseToYCoordinate(Int(target), fullSize: fullSize) - 3,
                        width: x2 - x1,
                        height: 8
                    )
                    old.append(oneMore)
                    let path = Path { path in
                        path.addRects(old)
                    }
                    return DispatchQueue.main.async {
                        overridesPath = path
                    }
                } else {
                    let x1 = timeToXCoordinate((last.date ?? Date.now).timeIntervalSince1970, fullSize: fullSize)
                    let x2 = timeToXCoordinate(Date.now.timeIntervalSince1970, fullSize: fullSize)
                    let oneMore = CGRect(
                        x: x1,
                        y: glucoseToYCoordinate(Int(target), fullSize: fullSize) - 3,
                        width: x2 - x1 + additionalWidth(viewWidth: fullSize.width),
                        height: 8
                    )
                    old.append(oneMore)
                    let path = Path { path in
                        path.addRects(old)
                    }
                    return DispatchQueue.main.async {
                        overridesPath = path
                    }
                }
            }
            let path = Path { path in
                path.addRects(rects)
            }
            DispatchQueue.main.async {
                overridesPath = path
            }
        }
    }

    private func findRegularBasalPoints(
        timeBegin: TimeInterval,
        timeEnd: TimeInterval,
        fullSize: CGSize,
        autotuned: Bool
    ) -> [CGPoint] {
        guard timeBegin < timeEnd else {
            return []
        }
        let beginDate = Date(timeIntervalSince1970: timeBegin)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: beginDate)

        let profile = autotuned ? autotunedBasalProfile : basalProfile

        let basalNormalized = profile.map {
            (
                time: startOfDay.addingTimeInterval($0.minutes.minutes.timeInterval).timeIntervalSince1970,
                rate: $0.rate
            )
        } + profile.map {
            (
                time: startOfDay.addingTimeInterval($0.minutes.minutes.timeInterval + 1.days.timeInterval).timeIntervalSince1970,
                rate: $0.rate
            )
        } + profile.map {
            (
                time: startOfDay.addingTimeInterval($0.minutes.minutes.timeInterval + 2.days.timeInterval).timeIntervalSince1970,
                rate: $0.rate
            )
        }

        let basalTruncatedPoints = basalNormalized.windows(ofCount: 2)
            .compactMap { window -> CGPoint? in
                let window = Array(window)
                if window[0].time < timeBegin, window[1].time < timeBegin {
                    return nil
                }

                let rateCost = Config.basalHeight / CGFloat(maxBasalRate())
                if window[0].time < timeBegin, window[1].time >= timeBegin {
                    let x = timeToXCoordinate(timeBegin, fullSize: fullSize)
                    let y = Config.basalHeight - CGFloat(window[0].rate) * rateCost
                    return CGPoint(x: x, y: y)
                }

                if window[0].time >= timeBegin, window[0].time < timeEnd {
                    let x = timeToXCoordinate(window[0].time, fullSize: fullSize)
                    let y = Config.basalHeight - CGFloat(window[0].rate) * rateCost
                    return CGPoint(x: x, y: y)
                }

                return nil
            }

        return basalTruncatedPoints
    }

    private func lastBasalPoint(fullSize: CGSize) -> CGPoint {
        let lastBasal = Array(tempBasals.suffix(2))
        guard lastBasal.count == 2 else {
            return CGPoint(x: timeToXCoordinate(Date().timeIntervalSince1970, fullSize: fullSize), y: Config.basalHeight)
        }
        let endBasalTime = lastBasal[0].timestamp.timeIntervalSince1970 + (lastBasal[1].durationMin?.minutes.timeInterval ?? 0)
        let rateCost = Config.basalHeight / CGFloat(maxBasalRate())
        let x = timeToXCoordinate(endBasalTime, fullSize: fullSize)
        let y = Config.basalHeight - CGFloat(lastBasal[0].rate ?? 0) * rateCost
        return CGPoint(x: x, y: y)
    }

    private func fullGlucoseWidth(viewWidth: CGFloat) -> CGFloat {
        viewWidth * CGFloat(hours)
    }

    private func additionalWidth(viewWidth: CGFloat) -> CGFloat {
        guard let predictions = suggestion?.predictions,
              let deliveredAt = suggestion?.deliverAt,
              let last = glucose.last
        else {
            return Config.minAdditionalWidth
        }

        let iob = predictions.iob?.count ?? 0
        let zt = predictions.zt?.count ?? 0
        let cob = predictions.cob?.count ?? 0
        let uam = predictions.uam?.count ?? 0
        let max = [iob, zt, cob, uam].max() ?? 0

        let lastDeltaTime = last.dateString.timeIntervalSince(deliveredAt)
        let additionalTime = CGFloat(TimeInterval(max) * 5.minutes.timeInterval - lastDeltaTime)
        let oneSecondWidth = oneSecondStep(viewWidth: viewWidth)

        return Swift.min(Swift.max(additionalTime * oneSecondWidth, Config.minAdditionalWidth), 275)
    }

    private func oneSecondStep(viewWidth: CGFloat) -> CGFloat {
        viewWidth / CGFloat(1.hours.timeInterval)
    }

    private func maxPredValue() -> Int? {
        [
            suggestion?.predictions?.cob ?? [],
            suggestion?.predictions?.iob ?? [],
            suggestion?.predictions?.zt ?? [],
            suggestion?.predictions?.uam ?? []
        ]
        .flatMap { $0 }
        .max()
    }

    private func minPredValue() -> Int? {
        [
            suggestion?.predictions?.cob ?? [],
            suggestion?.predictions?.iob ?? [],
            suggestion?.predictions?.zt ?? [],
            suggestion?.predictions?.uam ?? []
        ]
        .flatMap { $0 }
        .min()
    }

    private func maxTargetValue() -> Int? {
        tempTargets.map { $0.targetTop ?? 0 }.filter { $0 > 0 }.max().map(Int.init)
    }

    private func minTargetValue() -> Int? {
        tempTargets.map { $0.targetBottom ?? 0 }.filter { $0 > 0 }.min().map(Int.init)
    }

    private func glucoseToCoordinate(_ glucoseEntry: BloodGlucose, fullSize: CGSize) -> CGPoint {
        let x = timeToXCoordinate(glucoseEntry.dateString.timeIntervalSince1970, fullSize: fullSize)
        let y = glucoseToYCoordinate(glucoseEntry.glucose ?? 0, fullSize: fullSize)

        return CGPoint(x: x, y: y)
    }

    private func UnSmoothedGlucoseToCoordinate(_ glucoseEntry: BloodGlucose, fullSize: CGSize) -> CGPoint {
        let x = timeToXCoordinate(glucoseEntry.dateString.timeIntervalSince1970, fullSize: fullSize)
        let glucoseValue: Decimal = glucoseEntry.unfiltered ?? Decimal(glucoseEntry.glucose ?? 0)
        let y = glucoseToYCoordinate(Int(glucoseValue), fullSize: fullSize)

        return CGPoint(x: x, y: y)
    }

    private func predictionToCoordinate(_ pred: Int, fullSize: CGSize, index: Int) -> CGPoint {
        guard let deliveredAt = suggestion?.deliverAt else {
            return .zero
        }

        let predTime = deliveredAt.timeIntervalSince1970 + TimeInterval(index) * 5.minutes.timeInterval
        let x = timeToXCoordinate(predTime, fullSize: fullSize)
        let y = glucoseToYCoordinate(pred, fullSize: fullSize)

        return CGPoint(x: x, y: y)
    }

    private func timeToXCoordinate(_ time: TimeInterval, fullSize: CGSize) -> CGFloat {
        let xOffset = -Date().addingTimeInterval(-1.days.timeInterval).timeIntervalSince1970
        let stepXFraction = fullGlucoseWidth(viewWidth: fullSize.width) / CGFloat(hours.hours.timeInterval)
        let x = CGFloat(time + xOffset) * stepXFraction
        return x
    }

    /// inverse of `timeToXCoordinate`
    private func xCoordinateToTime(x: CGFloat, fullSize: CGSize) -> TimeInterval {
        let stepXFraction = fullGlucoseWidth(viewWidth: fullSize.width) / CGFloat(hours.hours.timeInterval)
        let xx = x / stepXFraction
        let xOffset = -Date().addingTimeInterval(-1.days.timeInterval).timeIntervalSince1970
        let time = xx - xOffset
        return time
    }

    private func glucoseToYCoordinate(_ glucoseValue: Int, fullSize: CGSize) -> CGFloat {
        let topYPaddint = Config.topYPadding + Config.basalHeight
        let bottomYPadding = Config.bottomYPadding
        let (minValue, maxValue) = minMaxYValues()
        let stepYFraction = (fullSize.height - topYPaddint - bottomYPadding) / CGFloat(maxValue - minValue)
        let yOffset = CGFloat(minValue) * stepYFraction
        let y = fullSize.height - CGFloat(glucoseValue) * stepYFraction + yOffset - bottomYPadding
        return y
    }

    private func timeToInterpolatedPoint(_ time: TimeInterval, fullSize: CGSize) -> CGPoint {
        var nextIndex = 0
        for (index, value) in glucose.enumerated() {
            if value.dateString.timeIntervalSince1970 > time {
                nextIndex = index
                break
            }
        }
        let x = timeToXCoordinate(time, fullSize: fullSize)

        guard nextIndex > 0 else {
            let lastY = glucoseToYCoordinate(glucose.last?.glucose ?? 0, fullSize: fullSize)
            return CGPoint(x: x, y: lastY)
        }

        let prevX = timeToXCoordinate(glucose[nextIndex - 1].dateString.timeIntervalSince1970, fullSize: fullSize)
        let prevY = glucoseToYCoordinate(glucose[nextIndex - 1].glucose ?? 0, fullSize: fullSize)
        let nextX = timeToXCoordinate(glucose[nextIndex].dateString.timeIntervalSince1970, fullSize: fullSize)
        let nextY = glucoseToYCoordinate(glucose[nextIndex].glucose ?? 0, fullSize: fullSize)
        let delta = nextX - prevX
        let fraction = (x - prevX) / delta

        return pointInLine(CGPoint(x: prevX, y: prevY), CGPoint(x: nextX, y: nextY), fraction)
    }

    private func minMaxYValues() -> (min: Int, max: Int) {
        var maxValue = glucose.compactMap(\.glucose).max() ?? Config.maxGlucose
        if let maxPredValue = maxPredValue() {
            maxValue = max(maxValue, maxPredValue)
        }
        if let maxTargetValue = maxTargetValue() {
            maxValue = max(maxValue, maxTargetValue)
        }
        var minValue = glucose.compactMap(\.glucose).min() ?? Config.minGlucose
        if let minPredValue = minPredValue() {
            minValue = min(minValue, minPredValue)
        }
        if let minTargetValue = minTargetValue() {
            minValue = min(minValue, minTargetValue)
        }

        if minValue == maxValue {
            minValue = Config.minGlucose
            maxValue = Config.maxGlucose
        }
        // fix the grah y-axis as long as the min and max BG values are within set borders
        if minValue > Config.minGlucose {
            minValue = Config.minGlucose
        }
        if maxValue < Config.maxGlucose {
            maxValue = Config.maxGlucose
        }
        return (min: minValue, max: maxValue)
    }

    private func getGlucoseYRange(fullSize: CGSize) -> GlucoseYRange {
        let topYPaddint = Config.topYPadding + Config.basalHeight
        let bottomYPadding = Config.bottomYPadding
        let (minValue, maxValue) = minMaxYValues()
        let stepYFraction = (fullSize.height - topYPaddint - bottomYPadding) / CGFloat(maxValue - minValue)
        let yOffset = CGFloat(minValue) * stepYFraction
        let maxY = fullSize.height - CGFloat(minValue) * stepYFraction + yOffset - bottomYPadding
        let minY = fullSize.height - CGFloat(maxValue) * stepYFraction + yOffset - bottomYPadding
        return (minValue: minValue, minY: minY, maxValue: maxValue, maxY: maxY)
    }

    private func firstHourDate() -> Date {
        let firstDate = Date().addingTimeInterval(-1.days.timeInterval)
        return firstDate.dateTruncated(from: .minute)!
    }

    private func firstHourPosition(viewWidth: CGFloat) -> CGFloat {
        let firstDate = Date().addingTimeInterval(-1.days.timeInterval)
        let firstHour = firstHourDate()

        let lastDeltaTime = firstHour.timeIntervalSince(firstDate)
        let oneSecondWidth = oneSecondStep(viewWidth: viewWidth)
        return oneSecondWidth * CGFloat(lastDeltaTime)
    }
}
