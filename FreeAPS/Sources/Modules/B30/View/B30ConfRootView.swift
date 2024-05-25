import SwiftUI
import Swinject

extension AIMIB30Conf {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        @State private var infoButtonPressed: InfoText?
        @Environment(\.colorScheme) var colorScheme

        private var color: LinearGradient {
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

        var body: some View {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Toggle("Activeer AIMI B30", isOn: $state.enableB30)
                        }
                        .padding(.bottom, 2)
                        if !state.enableB30 {
                            VStack(alignment: .leading) {
                                Text(
                                    "Maakt een verhoogde basale hoeveelheid mogelijk na een EatingSoon TT en een handmatige bolus om de infusieplaats te verzadigen met insuline om de insulineabsorptie te verhogen voor SMB's na een maaltijd zonder koolhydraten te tellen."
                                )
                                BulletList(
                                    listItems: [
                                        "heeft een EatingSoon TT nodig met een specifiek GlucoseDoel",
                                        "zodra deze TT is geannuleerd, wordt B30 hoge TBR geannuleerd",
                                        "om B30 te activeren moet minimaal een handmatige bolus worden gegeven",
                                        "je kunt aangeven hoe lang B30 moet lopen en hoe hoog deze is"
                                    ],
                                    listItemSpacing: 10
                                )
                                Text("Je kunt B30 starten met de sneltoetsen van Apple")
                                BulletList(
                                    listItems: [
                                        "https://tinyurl.com/B30shortcut"
                                    ],
                                    listItemSpacing: 10
                                )
                            }
                        }
                    }
                } header: { Text("Inschakelen").textCase(nil) }
                if state.enableB30 {
                    ForEach(state.sections.indexed(), id: \.1.id) { sectionIndex, section in
                        Section(header: Text(section.displayName).textCase(nil)) {
                            ForEach(section.fields.indexed(), id: \.1.id) { fieldIndex, field in
                                HStack {
                                    switch field.type {
                                    case .boolean:
                                        ZStack {
                                            Button("", action: {
                                                infoButtonPressed = InfoText(
                                                    description: field.infoText,
                                                    oref0Variable: field.displayName
                                                )
                                            })
                                            Toggle(isOn: self.$state.sections[sectionIndex].fields[fieldIndex].boolValue) {
                                                Text(field.displayName)
                                            }
                                        }
                                    case .decimal:
                                        ZStack {
                                            Button("", action: {
                                                infoButtonPressed = InfoText(
                                                    description: field.infoText,
                                                    oref0Variable: field.displayName
                                                )
                                            })
                                            Text(field.displayName)
                                        }
                                        DecimalTextField(
                                            "0",
                                            value: self.$state.sections[sectionIndex].fields[fieldIndex].decimalValue,
                                            formatter: formatter
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(color)
            .onAppear(perform: configureView)
            .navigationTitle("AIMI B30 Configuratie")
            .navigationBarTitleDisplayMode(.automatic)
            .onDisappear {
                state.saveIfChanged()
            }
        }

        func createParagraphAttribute(
            tabStopLocation: CGFloat,
            defaultTabInterval: CGFloat,
            firstLineHeadIndent: CGFloat,
            headIndent: CGFloat
        ) -> NSParagraphStyle {
            let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            let options: [NSTextTab.OptionKey: Any] = [:]
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: tabStopLocation, options: options)]
            paragraphStyle.defaultTabInterval = defaultTabInterval
            paragraphStyle.firstLineHeadIndent = firstLineHeadIndent
            paragraphStyle.headIndent = headIndent
            return paragraphStyle
        }
    }
}
