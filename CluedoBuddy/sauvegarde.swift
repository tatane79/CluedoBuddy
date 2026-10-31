import Foundation

enum GamePersistenceError: Error, Equatable {
    case noSavedGame
    case invalidGame
}

struct GameSnapshot: Codable {
    let grid: [DataJoueur]
    let gameType: Int
    let activePlayer: Int
    let turns: [Tour]
    let assistanceMode: GameAssistanceMode?
    let alertsOnNoteError: Bool?
    let evidenceGrid: [DataJoueur]?
    let evidenceSeedGrid: [DataJoueur]?
    let hypotheses: [GridHypothesis]?
    let assistantDeductions: [AssistantDeduction]?

    init(
        grid: [DataJoueur],
        gameType: Int,
        activePlayer: Int,
        turns: [Tour],
        assistanceMode: GameAssistanceMode? = nil,
        alertsOnNoteError: Bool? = nil,
        evidenceGrid: [DataJoueur]? = nil,
        evidenceSeedGrid: [DataJoueur]? = nil,
        hypotheses: [GridHypothesis]? = nil,
        assistantDeductions: [AssistantDeduction]? = nil
    ) {
        self.grid = grid
        self.gameType = gameType
        self.activePlayer = activePlayer
        self.turns = turns
        self.assistanceMode = assistanceMode
        self.alertsOnNoteError = alertsOnNoteError
        self.evidenceGrid = evidenceGrid
        self.evidenceSeedGrid = evidenceSeedGrid
        self.hypotheses = hypotheses
        self.assistantDeductions = assistantDeductions
    }

    private enum CodingKeys: String, CodingKey {
        case grid
        case gameType
        case activePlayer
        case turns
        case assistanceMode
        case alertsOnNoteError
        case evidenceGrid
        case evidenceSeedGrid
        case hypotheses
        case assistantDeductions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        grid = try container.decode([DataJoueur].self, forKey: .grid)
        gameType = try container.decode(Int.self, forKey: .gameType)
        activePlayer = try container.decode(Int.self, forKey: .activePlayer)
        turns = try container.decodeIfPresent([Tour].self, forKey: .turns) ?? []
        assistanceMode = try container.decodeIfPresent(
            GameAssistanceMode.self,
            forKey: .assistanceMode
        )
        alertsOnNoteError = try container.decodeIfPresent(
            Bool.self,
            forKey: .alertsOnNoteError
        )
        evidenceGrid = try container.decodeIfPresent(
            [DataJoueur].self,
            forKey: .evidenceGrid
        )
        evidenceSeedGrid = try container.decodeIfPresent(
            [DataJoueur].self,
            forKey: .evidenceSeedGrid
        )
        hypotheses = try container.decodeIfPresent(
            [GridHypothesis].self,
            forKey: .hypotheses
        )
        assistantDeductions = try container.decodeIfPresent(
            [AssistantDeduction].self,
            forKey: .assistantDeductions
        )
    }

    var isValid: Bool {
        guard grid.count >= 4,
              (0...1).contains(gameType),
              grid.indices.contains(activePlayer),
              activePlayer > 0
        else {
            return false
        }

        let expectedCardCounts = [nb_suspects, nb_armes, nb_lieux]
        let hasValidShape: ([DataJoueur]) -> Bool = { candidate in
            candidate.count == grid.count
                && candidate.allSatisfy { player in
                    player.cartes.count == expectedCardCounts.count
                        && zip(player.cartes, expectedCardCounts).allSatisfy { cards, count in
                            cards.count == count
                                && cards.allSatisfy { ["0", "1", "?"].contains($0.valeur) }
                        }
                }
        }

        return hasValidShape(grid)
            && (evidenceGrid.map(hasValidShape) ?? true)
            && (evidenceSeedGrid.map(hasValidShape) ?? true)
    }
}

struct GamePersistence {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let baseURL = directory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = baseURL.appendingPathComponent("cluedo-buddy-game.json")
    }

    var hasSavedGame: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func save(_ snapshot: GameSnapshot) throws {
        guard snapshot.isValid else {
            throw GamePersistenceError.invalidGame
        }

        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> GameSnapshot {
        guard hasSavedGame else {
            throw GamePersistenceError.noSavedGame
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try JSONDecoder().decode(GameSnapshot.self, from: data)
        guard snapshot.isValid else {
            throw GamePersistenceError.invalidGame
        }
        return snapshot
    }

    func delete() throws {
        guard hasSavedGame else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

let gamePersistence = GamePersistence()

@discardableResult
func saveCurrentGame(activePlayer: Int) -> Bool {
    let snapshot = GameSnapshot(
        grid: grilleUser,
        gameType: typeJeu,
        activePlayer: activePlayer,
        turns: toursDeLaPartie,
        assistanceMode: assistanceMode,
        alertsOnNoteError: alertsOnNoteError,
        evidenceGrid: evidenceGrid,
        evidenceSeedGrid: evidenceSeedGrid,
        hypotheses: gridHypotheses,
        assistantDeductions: assistantDeductions
    )

    do {
        try gamePersistence.save(snapshot)
        return true
    } catch {
        print("Impossible de sauvegarder la partie : \(error)")
        return false
    }
}

func restoreCurrentGame() throws -> Int {
    let snapshot = try gamePersistence.load()
    grilleUser = snapshot.grid
    typeJeu = snapshot.gameType
    toursDeLaPartie = snapshot.turns
    assistanceMode = snapshot.assistanceMode ?? .notebook
    alertsOnNoteError = snapshot.alertsOnNoteError ?? false
    evidenceGrid = snapshot.evidenceGrid ?? snapshot.grid
    evidenceSeedGrid = snapshot.evidenceSeedGrid ?? snapshot.grid
    gridHypotheses = snapshot.hypotheses ?? []
    assistantDeductions = snapshot.assistantDeductions ?? []
    if assistantDeductions.isEmpty, !toursDeLaPartie.isEmpty {
        rebuildAssistantDeductionJournal()
    }
    nb_joueurs = snapshot.grid.count - 1
    return snapshot.activePlayer
}
