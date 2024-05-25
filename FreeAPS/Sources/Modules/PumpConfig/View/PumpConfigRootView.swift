import SwiftUI
import Swinject

extension PumpConfig {
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

        var body: some View {
            Form {
                Section(header: Text("Model")) {
                    if let pumpState = state.pumpState {
                        Button {
                            state.setupPump = true
                        } label: {
                            HStack {
                                Image(uiImage: pumpState.image ?? UIImage()).padding()
                                Text(pumpState.name)
                            }
                        }
                        if state.alertNotAck {
                            Spacer()
                            Button("Acknowledge all alerts") { state.ack() }
                        }
                    } else {
                        Button("Medtronic") { state.addPump(.minimed) }
                        Button("Omnipod Eros") { state.addPump(.omnipod) }
                        Button("Omnipod Dash") { state.addPump(.omnipodBLE) }
                        Button("Dana-i/RS") { state.addPump(.dana) }
                        Button("Simulator") { state.addPump(.simulator) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(color)
            .onAppear(perform: configureView)
            .navigationTitle("Pump config")
            .navigationBarTitleDisplayMode(.automatic)
            .sheet(isPresented: $state.setupPump) {
                if let pumpManager = state.provider.apsManager.pumpManager {
                    PumpSettingsView(
                        pumpManager: pumpManager,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        completionDelegate: state,
                        setupDelegate: state
                    )
                } else {
                    PumpSetupView(
                        pumpType: state.setupPumpType,
                        pumpInitialSettings: state.initialSettings,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        completionDelegate: state,
                        setupDelegate: state
                    )
                }
            }
        }
    }
}
