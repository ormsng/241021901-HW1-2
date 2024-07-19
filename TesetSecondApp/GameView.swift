import SwiftUI

struct Card: Codable {
    let value: String
    let suit: String
    let image: String
}

struct DeckResponse: Codable {
    let success: Bool
    let deck_id: String
    let shuffled: Bool
    let remaining: Int
}

struct DrawResponse: Codable {
    let success: Bool
    let cards: [Card]
    let remaining: Int
}

class GameViewModel: ObservableObject {
    @Published var playerCard: Card?
    @Published var pcCard: Card?
    @Published var playerScore = 0
    @Published var pcScore = 0
    @Published var roundsPlayed = 0
    @Published var isGameOver = false
    @Published var countdown = 5
    @Published var showCards = false
    @Published var deckId: String?
    @Published var isLoading = false
    @Published var winner: String = ""
    @Published var isGameReady = false
    
    let playerName: String
    let location: Double
    var isPlayerOnLeft: Bool
    
    init(playerName: String, location: Double) {
        self.playerName = playerName
        self.location = location
        self.isPlayerOnLeft = location < 34.817549168324334
    }
    
    var timer: Timer?
    
    func startGame() {
        isLoading = true
        fetchNewDeck()
    }
    
    private func fetchNewDeck() {
        guard let url = URL(string: "https://www.deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(DeckResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.deckId = response.deck_id
                        self.drawCards(initialDraw: true)
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    func drawCards(initialDraw: Bool = false) {
        guard let deckId = deckId else { return }
        let urlString = "https://www.deckofcardsapi.com/api/deck/\(deckId)/draw/?count=2"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(DrawResponse.self, from: data)
                    DispatchQueue.main.async {
                        if response.cards.count == 2 {
                            self.playerCard = response.cards[0]
                            self.pcCard = response.cards[1]
                            self.isLoading = false
                            if initialDraw {
                                self.isGameReady = true
                            }
                            self.startCountdown()
                        }
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    self.isLoading = false
                }
            } else {
                self.isLoading = false
            }
        }.resume()
    }
    
    func startCountdown() {
        countdown = 5
        showCards = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                self.timer?.invalidate()
                self.revealCards()
            }
        }
    }
    
    func revealCards() {
        showCards = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.compareCards()
            self.roundsPlayed += 1
            
            if self.roundsPlayed < 10 {
                self.showCards = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.drawCards()
                }
            } else {
                self.endGame()
            }
        }
    }
    
    func compareCards() {
        guard let playerCard = playerCard, let pcCard = pcCard else { return }
        
        let cardValues = ["2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "JACK": 11, "QUEEN": 12, "KING": 13, "ACE": 14]
        
        if let playerValue = cardValues[playerCard.value], let pcValue = cardValues[pcCard.value] {
            if playerValue > pcValue {
                playerScore += 1
            } else if playerValue < pcValue {
                pcScore += 1
            }
        }
    }
    
    func determineWinner() {
        if playerScore > pcScore {
            winner = playerName
        } else if pcScore > playerScore {
            winner = "PC"
        } else {
            winner = "Tie"
        }
    }
    
    func endGame() {
        timer?.invalidate()
        isGameOver = true
        determineWinner()
    }
}

struct GameView: View {
    @StateObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Group {
            if viewModel.isGameOver {
                EndGameView(winnerName: viewModel.winner,
                            score: max(viewModel.playerScore, viewModel.pcScore),
                            presentationMode: presentationMode)
            } else if viewModel.isGameReady {
                gameContent
            } else {
                ProgressView("Preparing game...")
                    .scaleEffect(2)
                    .padding()
            }
        }
        .onAppear {
            viewModel.startGame()
        }
    }
    
    var gameContent: some View {
        VStack {
            HStack {
                VStack {
                    Text(viewModel.isPlayerOnLeft ? viewModel.playerName : "PC")
                    Text("\(viewModel.isPlayerOnLeft ? viewModel.playerScore : viewModel.pcScore)")
                        .font(.largeTitle)
                }
                Spacer()
                VStack {
                    Text(viewModel.isPlayerOnLeft ? "PC" : viewModel.playerName)
                    Text("\(viewModel.isPlayerOnLeft ? viewModel.pcScore : viewModel.playerScore)")
                        .font(.largeTitle)
                }
            }
            .padding()
            
            HStack {
                CardView(card: viewModel.isPlayerOnLeft ? viewModel.playerCard : viewModel.pcCard,
                         isRevealed: viewModel.showCards)
                VStack {
                    Text("⏱")
                        .font(.system(size: 40))
                    Text("\(viewModel.countdown)")
                        .font(.system(size: 72, weight: .bold))
                }
                .padding()
                CardView(card: viewModel.isPlayerOnLeft ? viewModel.pcCard : viewModel.playerCard,
                         isRevealed: viewModel.showCards)
            }
        }
        .padding()
    }
}

struct CardView: View {
    let card: Card?
    let isRevealed: Bool
    
    @State private var backDegree = 0.0
    @State private var frontDegree = -90.0
    
    var body: some View {
        ZStack {
            CardFace(degree: $backDegree, imageName: "https://www.deckofcardsapi.com/static/img/back.png")
                .opacity(isRevealed ? 0 : 1)
            CardFace(degree: $frontDegree, imageName: card?.image ?? "")
                .opacity(isRevealed ? 1 : 0)
        }
        .frame(width: 100, height: 150)
        .onChange(of: isRevealed) { newValue in
            if newValue {
                backDegree = -90 // Immediately hide back
                withAnimation(.linear(duration: 0.3)) {
                    frontDegree = 0 // Animate front
                }
            } else {
                frontDegree = 90 // Immediately hide front
                withAnimation(.linear(duration: 0.3)) {
                    backDegree = 0 // Animate back
                }
            }
        }
    }
}

struct CardFace: View {
    @Binding var degree: Double
    let imageName: String
    
    var body: some View {
        AsyncImage(url: URL(string: imageName)) { image in
            image.resizable()
        } placeholder: {
            Color.gray
        }
        .frame(width: 100, height: 150)
        .cornerRadius(10)
        .rotation3DEffect(Angle(degrees: degree), axis: (x: 0, y: 1, z: 0))
    }
}

struct EndGameView: View {
    let winnerName: String
    let score: Int
    var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(spacing: 20) {
            Text("Winner: \(winnerName)")
                .font(.title)
            Text("Score: \(score)")
                .font(.title2)
            Button("BACK TO MENU") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView(viewModel: GameViewModel(playerName: "Gabi", location: 30.0))
    }
}
