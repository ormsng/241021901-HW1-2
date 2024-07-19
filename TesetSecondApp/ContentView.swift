import SwiftUI
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var name: String = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var isNameEntered: Bool = UserDefaults.standard.bool(forKey: "isNameEntered")
    @State private var isGameStarted: Bool = false
    @State private var location: Double = 0
    @State private var isWestSide: Bool = false

    private var isStartEnabled: Bool {
        return !name.isEmpty && isNameEntered && locationManager.location != nil
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !isNameEntered {
                    TextField("Insert name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button("Save Name") {
                        if !name.isEmpty {
                            UserDefaults.standard.set(name, forKey: "userName")
                            UserDefaults.standard.set(true, forKey: "isNameEntered")
                            isNameEntered = true
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                } else {
                    Text("Hi \(name)")
                        .font(.title)
                        .padding()
                }
                
                HStack {
                    if isWestSide {
                        sideContent
                        Spacer()
                    } else {
                        Spacer()
                        sideContent
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                if locationManager.authorizationStatus == .authorizedWhenInUse {
                    Text("Location: \(locationManager.location?.coordinate.latitude ?? 0)")
                } else if locationManager.authorizationStatus == .denied {
                    Text("Location access denied. Please enable in Settings.")
                }
                
                NavigationLink(destination: GameView(viewModel: GameViewModel(playerName: name, location: location))) {
                    Text("START")
                        .padding()
                        .background(isStartEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isStartEnabled)
            }
            .padding()
            .onReceive(locationManager.$location) { newLocation in
                if let latitude = newLocation?.coordinate.latitude {
                    self.location = latitude
                    self.isWestSide = latitude < 34.817549168324334
                }
            }
        }
    }
    
    private var sideContent: some View {
        VStack {
            Image(isWestSide ? "left" : "right")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
            
            Text(isWestSide ? "West Side" : "East Side")
                .font(.headline)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
