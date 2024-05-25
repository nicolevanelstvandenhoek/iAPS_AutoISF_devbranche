import SwiftUI

extension AIMIB30Conf {
    final class StateModel: BaseStateModel<Provider>, PreferencesSettable {
        private(set) var preferences = Preferences()
        @Injected() var settings: SettingsManager!
        @Injected() var storage: FileStorage!

        @Published var unit: GlucoseUnits = .mmolL
        @Published var sections: [FieldSection] = []
        @Published var enableB30: Bool = false

        override func subscribe() {
            unit = settingsManager.settings.units
            preferences = provider.preferences
            enableB30 = settings.preferences.enableB30

            // MARK: - AIMI B30 fields

            let xpmB30 = [
                Field(
                    displayName: "TempDoelwaarde in mg/dl voor B30 die moet worden uitgevoerd",
                    type: .decimal(keypath: \.B30iTimeTarget),
                    infoText: NSLocalizedString(
                        "Er moet een EatingSoon TempTarget worden ingeschakeld om de B30-aanpassing te starten. Stel het niveau in waarop dit doel moet worden geïdentificeerd. De standaardwaarde is 90 mg/dl. Als je deze EatingSoon TT uitschakelt, stopt ook de B30 basale hoeveelheid.",
                        comment: "EatingSoon TT waarde"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Minimale start bolusgrootte",
                    type: .decimal(keypath: \.B30iTimeStartBolus),
                    infoText: NSLocalizedString(
                        "Minimale handmatige bolus om een B30- aanpassing te starten.",
                        comment: "B30 Start bolusgrootte"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Duur van de verhoogde B30 basale hoeveelheid",
                    type: .decimal(keypath: \.B30iTime),
                    infoText: NSLocalizedString(
                        "Duur van de verhoogde basale hoeveelheid die de infusieplaats verzadigt met insuline. Standaard 30 minuten, zoals in B30. De EatingSoon TT moet ten minste voor deze duur actief zijn, anders stopt B30 nadat de TT is afgelopen.",
                        comment: "Duur van de B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "B30 Toename factor basaal",
                    type: .decimal(keypath: \.B30basalFactor),
                    infoText: NSLocalizedString(
                        "Factor die je normale basale hoeveelheid vermenigvuldigt met je profiel voor B30. Standaard is 10.",
                        comment: "Basaal factor B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Upper BG limit in mg/dl for B30",
                    type: .decimal(keypath: \.B30upperLimit),
                    infoText: NSLocalizedString(
                        "B30 will only run as long as BG stays underneath that level, if above regular autoISF takes over. Default is 130 mg/dl.",
                        comment: "Upper BG for B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Bovenste (delta) limiet in mg/dl voor B30",
                    type: .decimal(keypath: \.B30upperDelta),
                    infoText: NSLocalizedString(
                        "B30 werkt alleen zolang de BG-delta onder dat niveau blijft, als de BG-delta daarboven komt, neemt autoISF het over. Standaard is 8 mg/dl.",
                        comment: "Bovenste (delta) limiet in mg/dl voor B30"
                    ),
                    settable: self
                )
            ]

            sections = [
                FieldSection(
                    displayName: NSLocalizedString(
                        "AIMI B30 instellingen",
                        comment: "AIMI B30 instellingen"
                    ),
                    fields: xpmB30
                )
            ]
        }

        var unChanged: Bool {
            preferences.enableB30 == enableB30
        }

        func convertBack(_ glucose: Decimal) -> Decimal {
            if unit == .mmolL {
                return glucose.asMgdL
            }
            return glucose
        }

        func save() {
            provider.savePreferences(preferences)
        }

        func set<T>(_ keypath: WritableKeyPath<Preferences, T>, value: T) {
            preferences[keyPath: keypath] = value
            save()
        }

        func get<T>(_ keypath: WritableKeyPath<Preferences, T>) -> T {
            preferences[keyPath: keypath]
        }

        func saveIfChanged() {
            if !unChanged {
                var newSettings = storage.retrieve(OpenAPS.Settings.preferences, as: Preferences.self) ?? Preferences()
                newSettings.enableB30 = enableB30
                newSettings.timestamp = Date()
                storage.save(newSettings, as: OpenAPS.Settings.preferences)
            }
        }
    }
}
