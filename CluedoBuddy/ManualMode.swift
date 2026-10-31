import SwiftUI

enum GameAssistanceMode: String, Codable, CaseIterable, Identifiable {
    case assisted
    case notebook

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .assisted: "Assistant"
        case .notebook: "Carnet libre"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .assisted:
            "L’application complète automatiquement les déductions certaines."
        case .notebook:
            "Vous remplissez seul la grille. Les preuves restent enregistrées séparément."
        }
    }
}

struct HypothesisCell: Codable, Hashable {
    let playerIndex: Int
    let typeIndex: Int
    let cardIndex: Int
}

struct GridHypothesis: Codable, Identifiable, Equatable {
    let id: UUID
    var cells: [HypothesisCell]
    var sourceTurn: Int?

    init(
        id: UUID = UUID(),
        cells: [HypothesisCell],
        sourceTurn: Int? = nil
    ) {
        self.id = id
        self.cells = cells
        self.sourceTurn = sourceTurn
    }
}

var gridHypotheses = [GridHypothesis]()

struct AssistantDeduction: Codable, Identifiable, Equatable {
    let id: UUID
    let playerIndex: Int
    let typeIndex: Int
    let cardIndex: Int
    let value: String
    let explanation: String
    let sourceTurn: Int?

    init(
        id: UUID = UUID(),
        playerIndex: Int,
        typeIndex: Int,
        cardIndex: Int,
        value: String,
        explanation: String,
        sourceTurn: Int? = nil
    ) {
        self.id = id
        self.playerIndex = playerIndex
        self.typeIndex = typeIndex
        self.cardIndex = cardIndex
        self.value = value
        self.explanation = explanation
        self.sourceTurn = sourceTurn
    }
}

struct ReversibleGameState: Codable {
    let grid: [DataJoueur]
    let evidence: [DataJoueur]
    let evidenceSeed: [DataJoueur]
    let turns: [Tour]
    let hypotheses: [GridHypothesis]
    let deductions: [AssistantDeduction]
    let activePlayer: Int
    let resolutionTurn: Int

    var fingerprint: Data? {
        try? JSONEncoder().encode(self)
    }
}

var assistantDeductions = [AssistantDeduction]()

func captureGameState(activePlayer: Int) -> ReversibleGameState {
    ReversibleGameState(
        grid: grilleUser,
        evidence: evidenceGrid,
        evidenceSeed: evidenceSeedGrid,
        turns: toursDeLaPartie,
        hypotheses: gridHypotheses,
        deductions: assistantDeductions,
        activePlayer: activePlayer,
        resolutionTurn: tourResolution
    )
}

@discardableResult
func restoreGameState(_ state: ReversibleGameState) -> Int {
    grilleUser = state.grid
    evidenceGrid = state.evidence
    evidenceSeedGrid = state.evidenceSeed
    toursDeLaPartie = state.turns
    gridHypotheses = state.hypotheses
    assistantDeductions = state.deductions
    tourResolution = state.resolutionTurn
    return state.activePlayer
}

func assistantDeduction(player: Int, type: Int, card: Int) -> AssistantDeduction? {
    assistantDeductions.last {
        $0.playerIndex == player
            && $0.typeIndex == type
            && $0.cardIndex == card
            && grilleUser.indices.contains(player)
            && grilleUser[player].cartes.indices.contains(type)
            && grilleUser[player].cartes[type].indices.contains(card)
            && grilleUser[player].cartes[type][card].valeur == $0.value
    }
}

struct NoteIssue: Identifiable, Equatable {
    let playerIndex: Int
    let typeIndex: Int
    let cardIndex: Int
    let notedValue: String
    let expectedValue: String
    let explanation: String

    var id: String {
        "\(playerIndex)-\(typeIndex)-\(cardIndex)-\(explanation)"
    }
}

var assistanceMode: GameAssistanceMode = .notebook
var alertsOnNoteError = false
var evidenceGrid = [DataJoueur]()
var evidenceSeedGrid = [DataJoueur]()

func prepareEvidenceJournal() {
    evidenceSeedGrid = grilleUser
    evidenceGrid = grilleUser
    toursDeLaPartie.removeAll()
    gridHypotheses.removeAll()
    assistantDeductions.removeAll()
}

func rebuildAssistantDeductionJournal() {
    guard !toursDeLaPartie.isEmpty else {
        assistantDeductions.removeAll()
        return
    }

    let visibleGrid = grilleUser
    var rebuiltEvidence = evidenceSeedGrid.isEmpty ? evidenceGrid : evidenceSeedGrid
    assistantDeductions.removeAll()

    for (turnIndex, turn) in toursDeLaPartie.enumerated() {
        let previousEvidence = rebuiltEvidence
        grilleUser = rebuiltEvidence
        gererTour(tour: turn)
        applyShownCards(from: turn, to: &grilleUser)
        rebuiltEvidence = verifTousLesJoueurs(grid: grilleUser)
        recordAssistantDeductions(
            from: previousEvidence,
            to: rebuiltEvidence,
            turn: turn,
            turnNumber: turnIndex + 1
        )
    }

    evidenceGrid = rebuiltEvidence
    grilleUser = assistanceMode == .assisted ? rebuiltEvidence : visibleGrid
}

@discardableResult
func recordObservedTurn(_ turn: Tour) -> [NoteIssue] {
    toursDeLaPartie.append(turn)
    let turnNumber = toursDeLaPartie.count

    if assistanceMode == .assisted {
        let previousGrid = grilleUser
        gererTour(tour: turn)
        applyShownCards(from: turn, to: &grilleUser)
        grilleUser = verifTousLesJoueurs(grid: grilleUser)
        recordAssistantDeductions(
            from: previousGrid,
            to: grilleUser,
            turn: turn,
            turnNumber: turnNumber
        )
        evidenceGrid = grilleUser
    } else {
        let userNotes = grilleUser
        if evidenceGrid.isEmpty {
            evidenceGrid = userNotes
        }

        let previousEvidence = evidenceGrid
        grilleUser = evidenceGrid
        gererTour(tour: turn)
        applyShownCards(from: turn, to: &grilleUser)
        evidenceGrid = verifTousLesJoueurs(grid: grilleUser)
        recordAssistantDeductions(
            from: previousEvidence,
            to: evidenceGrid,
            turn: turn,
            turnNumber: turnNumber
        )
        grilleUser = userNotes
    }

    return findNoteIssues()
}

@discardableResult
func replaceObservedTurn(at index: Int, with turn: Tour) -> [NoteIssue] {
    guard toursDeLaPartie.indices.contains(index) else { return findNoteIssues() }

    toursDeLaPartie[index] = turn
    let userNotes = grilleUser
    var rebuiltEvidence = evidenceSeedGrid.isEmpty ? evidenceGrid : evidenceSeedGrid
    assistantDeductions.removeAll()

    for (turnIndex, recordedTurn) in toursDeLaPartie.enumerated() {
        let previousEvidence = rebuiltEvidence
        grilleUser = rebuiltEvidence
        gererTour(tour: recordedTurn)
        applyShownCards(from: recordedTurn, to: &grilleUser)
        rebuiltEvidence = verifTousLesJoueurs(grid: grilleUser)
        recordAssistantDeductions(
            from: previousEvidence,
            to: rebuiltEvidence,
            turn: recordedTurn,
            turnNumber: turnIndex + 1
        )
    }

    evidenceGrid = rebuiltEvidence
    grilleUser = assistanceMode == .assisted ? rebuiltEvidence : userNotes
    return findNoteIssues()
}

private func applyShownCards(from turn: Tour, to grid: inout [DataJoueur]) {
    for shownCard in turn.shownCards {
        let result = changeValeurCarte(
            grid: grid,
            joueur: shownCard.playerIndex,
            typeElement: shownCard.typeIndex,
            numElement: shownCard.cardIndex,
            newValue: "1",
            caller: "Carte montrée"
        )
        grid = result.gridchanged
    }
}

func applyUserNote(
    player: Int,
    type: Int,
    card: Int,
    value: String
) -> [NoteIssue] {
    assistantDeductions.removeAll {
        $0.playerIndex == player && $0.typeIndex == type && $0.cardIndex == card
    }
    let result = changeValeurCarte(
        grid: grilleUser,
        joueur: player,
        typeElement: type,
        numElement: card,
        newValue: value,
        caller: "Note utilisateur"
    )
    grilleUser = result.gridchanged

    if assistanceMode == .assisted {
        let directlyEditedGrid = grilleUser
        grilleUser = verifTousLesJoueurs(grid: grilleUser)
        recordAssistantDeductions(
            from: directlyEditedGrid,
            to: grilleUser,
            turn: nil,
            turnNumber: nil
        )
        evidenceGrid = grilleUser
    }

    return findNoteIssues()
}

@discardableResult
func applyAssistantHelp() -> Int {
    guard !evidenceGrid.isEmpty else { return 0 }

    var appliedCount = 0
    for playerIndex in grilleUser.indices {
        guard evidenceGrid.indices.contains(playerIndex) else { continue }

        for typeIndex in grilleUser[playerIndex].cartes.indices {
            guard evidenceGrid[playerIndex].cartes.indices.contains(typeIndex) else {
                continue
            }

            for cardIndex in grilleUser[playerIndex].cartes[typeIndex].indices {
                guard evidenceGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex) else {
                    continue
                }

                let provenValue = evidenceGrid[playerIndex].cartes[typeIndex][cardIndex].valeur
                guard provenValue != "?",
                      grilleUser[playerIndex].cartes[typeIndex][cardIndex].valeur != provenValue
                else {
                    continue
                }

                grilleUser[playerIndex].cartes[typeIndex][cardIndex].valeur = provenValue
                if assistantDeductionInEvidence(
                    player: playerIndex,
                    type: typeIndex,
                    card: cardIndex,
                    value: provenValue
                ) == nil {
                    upsertAssistantDeduction(
                        player: playerIndex,
                        type: typeIndex,
                        card: cardIndex,
                        value: provenValue,
                        explanation: deductionExplanation(
                            player: playerIndex,
                            type: typeIndex,
                            card: cardIndex,
                            value: provenValue,
                            in: evidenceGrid,
                            turn: nil,
                            turnNumber: nil
                        ),
                        sourceTurn: nil
                    )
                }
                appliedCount += 1
            }
        }
    }

    grilleUser = majComptages(gridInput: grilleUser)
    return appliedCount
}

private func assistantDeductionInEvidence(
    player: Int,
    type: Int,
    card: Int,
    value: String
) -> AssistantDeduction? {
    assistantDeductions.last {
        $0.playerIndex == player
            && $0.typeIndex == type
            && $0.cardIndex == card
            && $0.value == value
    }
}

private func recordAssistantDeductions(
    from previousGrid: [DataJoueur],
    to updatedGrid: [DataJoueur],
    turn: Tour?,
    turnNumber: Int?
) {
    for playerIndex in updatedGrid.indices {
        guard previousGrid.indices.contains(playerIndex) else { continue }
        for typeIndex in updatedGrid[playerIndex].cartes.indices {
            guard previousGrid[playerIndex].cartes.indices.contains(typeIndex) else { continue }
            for cardIndex in updatedGrid[playerIndex].cartes[typeIndex].indices {
                guard previousGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex) else {
                    continue
                }
                let oldValue = previousGrid[playerIndex].cartes[typeIndex][cardIndex].valeur
                let newValue = updatedGrid[playerIndex].cartes[typeIndex][cardIndex].valeur
                guard oldValue == "?", newValue != "?" else { continue }

                upsertAssistantDeduction(
                    player: playerIndex,
                    type: typeIndex,
                    card: cardIndex,
                    value: newValue,
                    explanation: deductionExplanation(
                        player: playerIndex,
                        type: typeIndex,
                        card: cardIndex,
                        value: newValue,
                        in: updatedGrid,
                        turn: turn,
                        turnNumber: turnNumber
                    ),
                    sourceTurn: turnNumber
                )
            }
        }
    }
}

private func upsertAssistantDeduction(
    player: Int,
    type: Int,
    card: Int,
    value: String,
    explanation: String,
    sourceTurn: Int?
) {
    assistantDeductions.removeAll {
        $0.playerIndex == player && $0.typeIndex == type && $0.cardIndex == card
    }
    assistantDeductions.append(
        AssistantDeduction(
            playerIndex: player,
            typeIndex: type,
            cardIndex: card,
            value: value,
            explanation: explanation,
            sourceTurn: sourceTurn
        )
    )
}

private func deductionExplanation(
    player: Int,
    type: Int,
    card: Int,
    value: String,
    in grid: [DataJoueur],
    turn: Tour?,
    turnNumber: Int?
) -> String {
    let playerName = grid.indices.contains(player) ? grid[player].nom : "Ce joueur"
    let cardName = noteCardName(typeIndex: type, cardIndex: card)
    let turnPrefix = turnNumber.map { "Au tour \($0), " } ?? ""

    if let turn,
       turn.shownCards.contains(where: {
           $0.playerIndex == player && $0.typeIndex == type && $0.cardIndex == card
       }) {
        return "\(turnPrefix)\(playerName) a montré « \(cardName) ». Cette carte appartient donc nécessairement à sa main."
    }

    if let turn, turnContains(turn, type: type, card: card) {
        if value == "0", player != turn.joueurDuTour {
            if typeJeu == 0,
               let responder = turn.joueursRepondant.first,
               playersBeforeResponder(in: grid, turn: turn, responder: responder).contains(player) {
                return "\(turnPrefix)\(playerName) a été interrogé avant le premier joueur ayant réfuté et n’a pas répondu. Il ne possède donc pas « \(cardName) »."
            }
            if typeJeu == 0, turn.joueursRepondant.isEmpty {
                return "\(turnPrefix)personne n’a réfuté la suspicion. Comme \(playerName) n’était pas le joueur actif, il ne possède pas « \(cardName) »."
            }
            if typeJeu == 1, !turn.joueursRepondant.contains(player) {
                return "\(turnPrefix)en règle Accélérée, chaque joueur possédant une carte demandée doit répondre. \(playerName) n’ayant pas répondu, il ne possède pas « \(cardName) »."
            }
        }

        if value == "1", turn.joueursRepondant.contains(player) {
            let otherRequestedCardsAreExcluded = requestedCells(for: turn)
                .filter { $0.typeIndex != type || $0.cardIndex != card }
                .allSatisfy { requested in
                    grid.indices.contains(player)
                        && grid[player].cartes.indices.contains(requested.typeIndex)
                        && grid[player].cartes[requested.typeIndex].indices.contains(requested.cardIndex)
                        && grid[player].cartes[requested.typeIndex][requested.cardIndex].valeur == "0"
                }
            if otherRequestedCardsAreExcluded {
                return "\(turnPrefix)\(playerName) a réfuté la suspicion. Les deux autres cartes demandées sont exclues de sa main ; la carte montrée ne peut donc être que « \(cardName) »."
            }
        }
    }

    guard grid.indices.contains(player),
          grid[player].cartes.indices.contains(type),
          grid[player].cartes[type].indices.contains(card)
    else {
        return "Cette valeur résulte des contraintes certaines enregistrées pendant la partie."
    }

    if value == "0" {
        if let owner = grid.indices.first(where: {
            $0 != player && grid[$0].cartes[type][card].valeur == "1"
        }) {
            return "« \(cardName) » appartient déjà à \(grid[owner].nom). Une carte étant unique, \(playerName) ne peut pas la posséder."
        }
        if player == 0,
           grid[0].cartes[type].contains(where: { $0.valeur == "1" }) {
            return "L’enveloppe contient déjà une carte de cette catégorie. « \(cardName) » ne peut donc pas être la solution."
        }
        if player > 0, grid[player].nb_cartes_1 >= grid[player].nb_cartes {
            return "Toutes les \(grid[player].nb_cartes) cartes de \(playerName) sont déjà identifiées. « \(cardName) » ne peut donc pas appartenir à sa main."
        }
    } else if value == "1" {
        let possibleOwners = grid.indices.filter {
            grid[$0].cartes[type][card].valeur != "0"
        }
        if possibleOwners == [player] {
            return "Tous les autres propriétaires possibles de « \(cardName) » ont été éliminés. Cette carte appartient donc à \(playerName)."
        }
        if player == 0 {
            let possibleCards = grid[0].cartes[type].filter { $0.valeur != "0" }
            if possibleCards.count == 1 {
                return "Toutes les autres cartes de cette catégorie ont été exclues de l’enveloppe. « \(cardName) » est donc dans la solution."
            }
        } else {
            let remainingSlots = grid[player].nb_cartes - grid[player].nb_cartes_1
            if remainingSlots == grid[player].nb_cartes_inconnues {
                return "Il reste exactement autant de cartes possibles que de places libres dans la main de \(playerName). « \(cardName) » en fait donc nécessairement partie."
            }
        }
    }

    return "\(turnPrefix)cette conclusion découle du croisement des réponses enregistrées, de l’unicité de chaque carte et du nombre de cartes de chaque joueur."
}

private func turnContains(_ turn: Tour, type: Int, card: Int) -> Bool {
    switch type {
    case 0: turn.personnageSuspecte == card
    case 1: turn.armeSuspectee == card
    case 2: turn.lieuSuspecte == card
    default: false
    }
}

private func requestedCells(for turn: Tour) -> [HypothesisCell] {
    [
        HypothesisCell(playerIndex: 0, typeIndex: 0, cardIndex: turn.personnageSuspecte),
        HypothesisCell(playerIndex: 0, typeIndex: 1, cardIndex: turn.armeSuspectee),
        HypothesisCell(playerIndex: 0, typeIndex: 2, cardIndex: turn.lieuSuspecte)
    ]
}

private func playersBeforeResponder(
    in grid: [DataJoueur],
    turn: Tour,
    responder: Int
) -> [Int] {
    let playerCount = max(grid.count - 1, 0)
    guard playerCount > 1 else { return [] }

    var result: [Int] = []
    for offset in 1..<playerCount {
        let player = ((turn.joueurDuTour - 1 + offset) % playerCount) + 1
        if player == responder { break }
        result.append(player)
    }
    return result
}

func findNoteIssues() -> [NoteIssue] {
    guard assistanceMode == .notebook else { return [] }

    var issues = findInternalNoteIssues()
    for playerIndex in grilleUser.indices {
        guard evidenceGrid.indices.contains(playerIndex) else { continue }

        for typeIndex in grilleUser[playerIndex].cartes.indices {
            guard evidenceGrid[playerIndex].cartes.indices.contains(typeIndex) else {
                continue
            }

            for cardIndex in grilleUser[playerIndex].cartes[typeIndex].indices {
                guard evidenceGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex) else {
                    continue
                }

                let notedValue = grilleUser[playerIndex].cartes[typeIndex][cardIndex].valeur
                let expectedValue = evidenceGrid[playerIndex].cartes[typeIndex][cardIndex].valeur
                guard notedValue != "?",
                      expectedValue != "?",
                      notedValue != expectedValue
                else {
                    continue
                }

                issues.append(
                    NoteIssue(
                        playerIndex: playerIndex,
                        typeIndex: typeIndex,
                        cardIndex: cardIndex,
                        notedValue: notedValue,
                        expectedValue: expectedValue,
                        explanation: issueExplanation(
                            playerIndex: playerIndex,
                            typeIndex: typeIndex,
                            cardIndex: cardIndex,
                            expectedValue: expectedValue
                        )
                    )
                )
            }
        }
    }

    return issues
}

private func findInternalNoteIssues() -> [NoteIssue] {
    guard let cardLayout = grilleUser.first?.cartes else { return [] }

    var issues: [NoteIssue] = []
    for typeIndex in cardLayout.indices {
        for cardIndex in cardLayout[typeIndex].indices {
            let owners = grilleUser.indices.filter { playerIndex in
                grilleUser[playerIndex].cartes.indices.contains(typeIndex)
                    && grilleUser[playerIndex].cartes[typeIndex].indices.contains(cardIndex)
                    && grilleUser[playerIndex].cartes[typeIndex][cardIndex].valeur == "1"
            }
            guard owners.count > 1 else { continue }

            let cardName = noteCardName(typeIndex: typeIndex, cardIndex: cardIndex)
            let ownerNames = owners.map { grilleUser[$0].nom }.formatted(
                .list(type: .and)
                    .locale(Locale(identifier: "fr_FR"))
            )
            let explanation = "« \(cardName) » est attribuée à plusieurs joueurs : \(ownerNames). Une carte ne peut appartenir qu’à une seule main. Les notes ne permettent pas de déterminer quelle attribution est incorrecte."
            issues.append(contentsOf: owners.map { owner in
                NoteIssue(
                    playerIndex: owner,
                    typeIndex: typeIndex,
                    cardIndex: cardIndex,
                    notedValue: "1",
                    expectedValue: "un seul propriétaire",
                    explanation: explanation
                )
            })
        }
    }
    return issues
}

private func noteCardName(typeIndex: Int, cardIndex: Int) -> String {
    guard nomCartes.indices.contains(typeIndex),
          nomCartes[typeIndex].indices.contains(cardIndex)
    else {
        return "Cette carte"
    }
    return nomCartes[typeIndex][cardIndex].nom
}

private func issueExplanation(
    playerIndex: Int,
    typeIndex: Int,
    cardIndex: Int,
    expectedValue: String
) -> String {
    let playerName = grilleUser.indices.contains(playerIndex)
        ? grilleUser[playerIndex].nom
        : "Ce joueur"
    let cardName = nomCartes.indices.contains(typeIndex)
        && nomCartes[typeIndex].indices.contains(cardIndex)
        ? nomCartes[typeIndex][cardIndex].nom
        : "cette carte"
    let turnNumber = latestRelevantTurn(typeIndex: typeIndex, cardIndex: cardIndex)

    let fact: String
    if expectedValue == "1" {
        fact = "le journal de preuves établit que \(playerName) possède « \(cardName) »"
    } else {
        fact = "le journal de preuves exclut « \(cardName) » de la main de \(playerName)"
    }

    if let turnNumber {
        return "Après le tour \(turnNumber), \(fact). Votre note indique l’inverse."
    }
    return "D’après les cartes initiales et les réponses enregistrées, \(fact). Votre note indique l’inverse."
}

private func latestRelevantTurn(typeIndex: Int, cardIndex: Int) -> Int? {
    for (offset, turn) in toursDeLaPartie.enumerated().reversed() {
        let cards = [
            turn.personnageSuspecte,
            turn.armeSuspectee,
            turn.lieuSuspecte
        ]
        if cards.indices.contains(typeIndex), cards[typeIndex] == cardIndex {
            return offset + 1
        }
    }
    return nil
}

struct GameModePicker: View {
    @Binding var mode: GameAssistanceMode
    @Binding var alertsOnError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style de partie")
                .font(.headline)

            Picker("Style de partie", selection: $mode) {
                ForEach(GameAssistanceMode.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if mode == .notebook {
                Toggle("Alerter immédiatement en cas d’erreur", isOn: $alertsOnError)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct GameModeStatus: View {
    let mode: GameAssistanceMode

    var body: some View {
        Label {
            Text(mode == .notebook ? "Carnet libre" : "Assistant")
        } icon: {
            Image(systemName: mode == .notebook ? "pencil.and.list.clipboard" : "sparkles")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(mode == .notebook ? .indigo : .blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            (mode == .notebook ? Color.indigo : Color.blue).opacity(0.12),
            in: Capsule()
        )
    }
}

struct NoteIssuesView: View {
    let issues: [NoteIssue]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if issues.isEmpty {
                    ContentUnavailableView(
                        "Notes cohérentes",
                        systemImage: "checkmark.seal",
                        description: Text("Aucune contradiction n’a été trouvée dans vos notes.")
                    )
                } else {
                    Section {
                        ForEach(issues) { issue in
                            NoteIssueRow(explanation: issue.explanation)
                        }
                    } header: {
                        if issues.count == 1 {
                            Text("1 incohérence")
                        } else {
                            Text("\(issues.count) incohérences")
                        }
                    } footer: {
                        Text("Le carnet n’est pas modifié automatiquement.")
                    }
                }
            }
            .navigationTitle("Vérifier mes notes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct NoteIssueRow: View {
    let explanation: String

    var body: some View {
        Label {
            Text(explanation)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
