import SwiftUI
import Swinject

extension FPUConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @Environment(\.colorScheme) var colorScheme
        var color: LinearGradient {
            colorScheme == .dark ? LinearGradient(
                gradient: Gradient(colors: [
                    Color.bgDarkBlue,
                    Color.bgDarkerDarkBlue
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
                :
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
        }

        private var conversionFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1

            return formatter
        }

        private var intFormater: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.allowsFloats = false
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text("Conversion settings")) {
                    HStack {
                        Text("Delay In Minutes")
                        Spacer()
                        DecimalTextField("60", value: $state.delay, formatter: intFormater)
                    }
                    HStack {
                        Text("Maximum Duration In Hours")
                        Spacer()
                        DecimalTextField("8", value: $state.timeCap, formatter: intFormater)
                    }
                    HStack {
                        Text("Interval In Minutes")
                        Spacer()
                        DecimalTextField("30", value: $state.minuteInterval, formatter: intFormater)
                    }
                    HStack {
                        Text("Override With A Factor Of ")
                        Spacer()
                        DecimalTextField("0.5", value: $state.individualAdjustmentFactor, formatter: conversionFormatter)
                    }
                }

                Section {}
                footer: {
                    Text(
                        NSLocalizedString(
                            "Dit laat je vet en eiwit omzetten in toekomstige koolhydraten met behulp van de Warschau-formule. Deze formule verdeelt de koolhydraten over een zelf in te stellen tijdsduur van 5-12 uur.\n\nDe vertraging is de tijd tussen nu en de eerste toekomstige koolhydrateninvoer. Het interval in minuten is het aantal minuten tussen elke invoer. Als je een korter interval kiest, wordt het resultaat gelijkmatiger. Goede keuzes zijn bijvoorbeeld 10, 15, 20, 30 of 60 minuten.\n\nDe aanpassingsfactor bepaalt het effect van vet en eiwit op de waarden. Een factor van 1,0 betekent volledig effect (de oorspronkelijke Warschau-methode), en 0,5 betekent half effect.\n\nLet op dat je mogelijk moet opmerken dat je normale koolhydratenverhouding moet verhogen tot een hoger getal wanneer je vet en eiwit toevoegt. Daarom is het het beste om te beginnen met een factor van ongeveer 0,5 om het jezelf makkelijk te maken.\n\nStandaardinstellingen zijn een tijdslimiet van 8 uur, een interval van 30 minuten, een factor van 0,5 en een vertraging van 60 minuten",
                            comment: "Fat/Protein description"
                        ) + NSLocalizedString(
                            "\n\nCarb equivalents that get to small (0.6g or under) will be excluded and the equivalents over 0.6 but under 1 will be rounded up to 1. With a higher time interval setting you'll get fewer equivalents with a higher carb amount.",
                            comment: "Fat/Protein additional info"
                        )
                    )
                }
            }
            .scrollContentBackground(.hidden).background(color)
            .onAppear(perform: configureView)
            .navigationBarTitle("Fat and Protein")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
