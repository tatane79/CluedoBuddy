import Foundation
import Testing
@testable import CluedoBuddy

@Suite(.serialized)
struct GamePersistenceTests {
    @Test
    func `A valid game survives a save and load round trip`() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = GamePersistence(directory: directory)
        let grid = initialiserGrille(noms: ["Alice", "Bob", "Chloé"])
        let turn = Tour(
            joueurDuTour: 1,
            personnageSuspecte: 0,
            armeSuspectee: 1,
            lieuSuspecte: 2,
            joueursRepondant: [2]
        )
        let snapshot = GameSnapshot(
            grid: grid,
            gameType: 0,
            activePlayer: 2,
            turns: [turn],
            assistantDeductions: [
                AssistantDeduction(
                    playerIndex: 2,
                    typeIndex: 0,
                    cardIndex: 0,
                    value: "0",
                    explanation: "Bob n’a pas réfuté."
                )
            ]
        )

        try persistence.save(snapshot)
        let restored = try persistence.load()

        #expect(restored.grid.map(\.nom) == grid.map(\.nom))
        #expect(restored.gameType == 0)
        #expect(restored.activePlayer == 2)
        #expect(restored.turns.count == 1)
        #expect(restored.turns[0].joueursRepondant == [2])
        #expect(restored.assistantDeductions?.first?.explanation == "Bob n’a pas réfuté.")
    }

    @Test
    func `A legacy save without optional game data can be resumed`() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = GamePersistence(directory: directory)
        let grid = initialiserGrille(noms: ["Alice", "Bob", "Chloé"])
        let encodedGrid = try JSONEncoder().encode(grid)
        let gridObject = try JSONSerialization.jsonObject(with: encodedGrid)
        let legacySnapshot: [String: Any] = [
            "grid": gridObject,
            "gameType": 0,
            "activePlayer": 1
        ]
        let data = try JSONSerialization.data(withJSONObject: legacySnapshot)
        try data.write(
            to: directory.appendingPathComponent("cluedo-buddy-game.json"),
            options: .atomic
        )

        let restored = try persistence.load()

        #expect(restored.grid.map(\.nom) == grid.map(\.nom))
        #expect(restored.turns.isEmpty)
        #expect(restored.assistanceMode == nil)
        #expect(restored.evidenceGrid == nil)
    }

    @Test
    func `An invalid game is never written`() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = GamePersistence(directory: directory)
        let invalidSnapshot = GameSnapshot(
            grid: initialiserGrille(noms: ["Alice"]),
            gameType: 0,
            activePlayer: 1,
            turns: []
        )

        #expect(throws: GamePersistenceError.invalidGame) {
            try persistence.save(invalidSnapshot)
        }
        #expect(!persistence.hasSavedGame)
    }

    @Test
    func `A corrupt save is rejected`() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = GamePersistence(directory: directory)
        let fileURL = directory.appendingPathComponent("cluedo-buddy-game.json")
        try Data("not-json".utf8).write(to: fileURL)

        #expect(throws: (any Error).self) {
            try persistence.load()
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

struct DeductionEngineTests {
    @Test
    func `A known owner excludes every other player`() {
        var grid = playableGrid()
        grid[2].cartes[0][0].valeur = "1"

        let result = verifTousLesJoueurs(grid: grid)

        #expect(result[2].cartes[0][0].valeur == "1")
        #expect(result.enumerated().allSatisfy { index, player in
            index == 2 || player.cartes[0][0].valeur == "0"
        })
    }

    @Test
    func `The last possible owner is deduced`() {
        var grid = playableGrid()
        for playerIndex in [0, 1, 2] {
            grid[playerIndex].cartes[1][3].valeur = "0"
        }

        let result = verifTousLesJoueurs(grid: grid)

        #expect(result[3].cartes[1][3].valeur == "1")
    }

    @Test
    func `Conditional expressions use the supplied grid`() {
        var grid = playableGrid()
        grid[2].cartes[1][0].valeur = "1"
        grid[1].cartes[0][0].unSi = .pointeur(2, 1, 0)

        let result = verifTousLesJoueurs(grid: grid)

        #expect(result[1].cartes[0][0].valeur == "1")
    }

    @Test
    func `Standard rules exclude only players before the first responder`() {
        grilleUser = initialiserGrille(noms: ["Alice", "Bob", "Chloé", "David"])
        for playerIndex in grilleUser.indices.dropFirst() {
            grilleUser[playerIndex].nb_cartes = 5
        }
        nb_joueurs = 4
        typeJeu = 0

        gererTour(
            tour: Tour(
                joueurDuTour: 1,
                personnageSuspecte: 0,
                armeSuspectee: 0,
                lieuSuspecte: 0,
                joueursRepondant: [3]
            )
        )

        #expect(grilleUser[2].cartes[0][0].valeur == "0")
        #expect(grilleUser[4].cartes[0][0].valeur == "?")
    }

    @Test
    func `Accelerated rules accept every responding player`() {
        grilleUser = initialiserGrille(noms: ["Alice", "Bob", "Chloé", "David", "Emma"])
        for playerIndex in grilleUser.indices.dropFirst() {
            grilleUser[playerIndex].nb_cartes = 4
        }
        nb_joueurs = 5
        typeJeu = 1

        gererTour(
            tour: Tour(
                joueurDuTour: 1,
                personnageSuspecte: 0,
                armeSuspectee: 0,
                lieuSuspecte: 0,
                joueursRepondant: [2, 3, 4, 5]
            )
        )

        #expect(grilleUser[2].cartes[0][0].valeur == "?")
        #expect(grilleUser[5].cartes[0][0].valeur == "?")
    }

    private func playableGrid() -> [DataJoueur] {
        var grid = initialiserGrille(noms: ["Alice", "Bob", "Chloé"])
        for playerIndex in grid.indices.dropFirst() {
            grid[playerIndex].nb_cartes = 6
        }
        return grid
    }
}

@Suite(.serialized)
struct ManualNotebookTests {
    @Test
    func `A manual note never triggers automatic deduction`() {
        configureNotebookGame()

        _ = applyUserNote(player: 2, type: 0, card: 0, value: "1")

        #expect(grilleUser[2].cartes[0][0].valeur == "1")
        #expect(grilleUser[3].cartes[0][0].valeur == "?")
    }

    @Test
    func `An incorrect conclusion is reported without being erased`() {
        configureNotebookGame()
        evidenceGrid[2].cartes[0][0].valeur = "0"

        let issues = applyUserNote(player: 2, type: 0, card: 0, value: "1")

        #expect(issues.count == 1)
        #expect(issues[0].expectedValue == "0")
        #expect(grilleUser[2].cartes[0][0].valeur == "1")
    }

    @Test
    func `One card cannot belong to two players`() {
        configureNotebookGame()
        grilleUser[2].cartes[0][1].valeur = "1"
        grilleUser[3].cartes[0][1].valeur = "1"

        let issues = findNoteIssues()

        #expect(issues.count == 2)
        #expect(Set(issues.map(\.playerIndex)) == [2, 3])
        #expect(issues[0].explanation.contains("Moutarde"))
        #expect(issues[0].explanation.contains("plusieurs joueurs"))
        #expect(issues[0].expectedValue == "un seul propriétaire")
    }

    @Test
    func `On-demand assistance applies only proven values`() {
        configureNotebookGame()
        evidenceGrid[2].cartes[0][0].valeur = "0"
        evidenceGrid[3].cartes[1][1].valeur = "1"

        let appliedCount = applyAssistantHelp()

        #expect(appliedCount == 2)
        #expect(grilleUser[2].cartes[0][0].valeur == "0")
        #expect(grilleUser[3].cartes[1][1].valeur == "1")
        #expect(grilleUser[2].cartes[2][0].valeur == "?")
        #expect(assistanceMode == .notebook)
    }

    @Test
    func `Assistant deductions retain a readable explanation`() {
        configureNotebookGame()
        let turn = Tour(
            joueurDuTour: 1,
            personnageSuspecte: 0,
            armeSuspectee: 0,
            lieuSuspecte: 0,
            joueursRepondant: []
        )

        _ = recordObservedTurn(turn)
        _ = applyAssistantHelp()

        let deduction = assistantDeduction(player: 2, type: 0, card: 0)
        #expect(deduction?.value == "0")
        #expect(deduction?.explanation.contains("personne n’a réfuté") == true)
    }

    @Test
    func `A complete game state can be restored for undo`() {
        configureNotebookGame()
        let state = captureGameState(activePlayer: 1)
        _ = applyUserNote(player: 2, type: 0, card: 0, value: "1")
        gridHypotheses.append(
            GridHypothesis(cells: [
                HypothesisCell(playerIndex: 2, typeIndex: 1, cardIndex: 0),
                HypothesisCell(playerIndex: 2, typeIndex: 2, cardIndex: 0)
            ])
        )

        let restoredPlayer = restoreGameState(state)

        #expect(restoredPlayer == 1)
        #expect(grilleUser[2].cartes[0][0].valeur == "?")
        #expect(gridHypotheses.isEmpty)
    }

    @Test
    func `Editing a turn rebuilds evidence from the initial grid`() {
        configureNotebookGame()
        let originalTurn = Tour(
            joueurDuTour: 1,
            personnageSuspecte: 0,
            armeSuspectee: 0,
            lieuSuspecte: 0,
            joueursRepondant: []
        )
        _ = recordObservedTurn(originalTurn)

        let correctedTurn = Tour(
            joueurDuTour: 1,
            personnageSuspecte: 1,
            armeSuspectee: 0,
            lieuSuspecte: 0,
            joueursRepondant: []
        )
        _ = replaceObservedTurn(at: 0, with: correctedTurn)

        #expect(evidenceGrid[2].cartes[0][0].valeur == "?")
        #expect(evidenceGrid[2].cartes[0][1].valeur == "0")
        #expect(grilleUser[2].cartes[0][0].valeur == "?")
    }

    @Test
    func `Recording a turn changes evidence but preserves notes`() {
        configureNotebookGame()
        let turn = Tour(
            joueurDuTour: 1,
            personnageSuspecte: 0,
            armeSuspectee: 0,
            lieuSuspecte: 0,
            joueursRepondant: []
        )

        _ = recordObservedTurn(turn)

        #expect(grilleUser[2].cartes[0][0].valeur == "?")
        #expect(evidenceGrid[2].cartes[0][0].valeur == "0")
    }

    private func configureNotebookGame() {
        assistanceMode = .notebook
        alertsOnNoteError = false
        typeJeu = 0
        toursDeLaPartie = []
        grilleUser = initialiserGrille(noms: ["Alice", "Bob", "Chloé"])
        for playerIndex in grilleUser.indices.dropFirst() {
            grilleUser[playerIndex].nb_cartes = 6
        }
        evidenceSeedGrid = grilleUser
        evidenceGrid = grilleUser
        assistantDeductions = []
        gridHypotheses = []
    }
}
