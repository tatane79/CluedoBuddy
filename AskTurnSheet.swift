//
//  AskTurnSheet.swift
//  CluedoBuddy
//

import SwiftUI

struct AskTurnSheet: View {
    @Binding var isSheetPresented: Bool
    @Binding var joueurActifG: Int

    @State private var selectedPlayerIndex = 0
    @State private var turnKind: TurnKind = .suspicion
    @State private var selectedCards = Array(repeating: -1, count: nb_elements.count)
    @State private var selectedRefuterIndices: Set<Int> = []
    @State private var shownCardSelections = Array(repeating: -1, count: grilleUser.count)
    @State private var playersWithoutSelectedCard = Array(repeating: false, count: grilleUser.count)

    private var players: [String] {
        grilleUser.dropFirst().map(\.nom)
    }

    private var activePlayerIndex: Int {
        selectedPlayerIndex + 1
    }

    private var selectedCardNames: [String] {
        selectedCards.enumerated().map { typeIndex, cardIndex in
            guard nomCartes.indices.contains(typeIndex),
                  nomCartes[typeIndex].indices.contains(cardIndex)
            else {
                return "À choisir"
            }
            return nomCartes[typeIndex][cardIndex].nom
        }
    }

    private var cardChoices: [[CardChoice]] {
        nomCartes.enumerated().map { typeIndex, cards in
            cards.enumerated().map { cardIndex, card in
                CardChoice(
                    id: cardIndex,
                    name: card.nom,
                    marker: CardMarker.marker(type: typeIndex, index: cardIndex)
                )
            }
        }
    }

    private var shownCardChoices: [ShownCardChoice] {
        selectedCards.enumerated().compactMap { typeIndex, cardIndex in
            guard cardIndex >= 0,
                  nomCartes.indices.contains(typeIndex),
                  nomCartes[typeIndex].indices.contains(cardIndex)
            else {
                return nil
            }

            return ShownCardChoice(
                id: typeIndex * 1_000 + cardIndex,
                name: nomCartes[typeIndex][cardIndex].nom,
                marker: CardMarker.marker(type: typeIndex, index: cardIndex)
            )
        }
    }

    private var shownCardChoicesByPlayer: [Int: [ShownCardChoice]] {
        Dictionary(uniqueKeysWithValues: refuterCandidates.map { candidate in
            let choices = candidate.id == 1
                ? knownMatchingCards(for: candidate.id)
                : coherentShownCards(for: candidate.id)
            return (candidate.id, choices)
        })
    }

    private var refuterCandidates: [RefuterCandidate] {
        let playerCount = max(grilleUser.count - 1, 0)
        guard playerCount > 1 else { return [] }

        return (1..<playerCount).compactMap { offset in
            let index = ((activePlayerIndex - 1 + offset) % playerCount) + 1
            guard grilleUser.indices.contains(index) else { return nil }
            return RefuterCandidate(
                id: index,
                name: grilleUser[index].nom,
                isUnavailable: playersWithoutSelectedCard.indices.contains(index)
                    && playersWithoutSelectedCard[index]
            )
        }
    }

    private var isSelectionComplete: Bool {
        selectedCards.count >= 3 && selectedCards.prefix(3).allSatisfy { $0 >= 0 }
    }

    private var isShownCardMissing: Bool {
        selectedRefuterIndices.contains { index in
            guard selectedPlayerIndex == 0 || index == 1 else { return false }
            return !shownCardSelections.indices.contains(index)
                || shownCardSelections[index] < 0
        }
    }

    private var isKnownResponseMissing: Bool {
        guard turnKind == .suspicion, isSelectionComplete
        else {
            return false
        }

        if typeJeu == 1 {
            let requiredResponders = Set(
                refuterCandidates
                    .filter { !knownMatchingCards(for: $0.id).isEmpty }
                    .map(\.id)
            )
            return !requiredResponders.isSubset(of: selectedRefuterIndices)
        }

        for candidate in refuterCandidates {
            if selectedRefuterIndices.contains(candidate.id) {
                return false
            }
            if !knownMatchingCards(for: candidate.id).isEmpty {
                return true
            }
        }
        return false
    }

    private var canSave: Bool {
        turnKind == .noSuspicion
            || (isSelectionComplete && !isShownCardMissing && !isKnownResponseMissing)
    }

    private var summary: String {
        let playerName = players.indices.contains(selectedPlayerIndex)
            ? players[selectedPlayerIndex]
            : "Le joueur"

        guard turnKind == .suspicion else {
            return "\(playerName) ne formule aucune suspicion."
        }

        guard isSelectionComplete else {
            return "Choisissez un suspect, une arme et un lieu."
        }

        let refutation: String
        if selectedRefuterIndices.isEmpty {
            refutation = "Personne ne réfute."
        } else {
            let responses = refuterCandidates
                .filter { selectedRefuterIndices.contains($0.id) }
                .map { candidate in
                    let shownCard = shownCardName(for: candidate.id)
                    return shownCard.map {
                        "\(candidate.name) montre \($0)."
                    } ?? "\(candidate.name) réfute."
                }
            refutation = responses.joined(separator: " ")
        }

        return "\(playerName) suspecte \(selectedCardNames[0]), avec \(selectedCardNames[1]), dans \(selectedCardNames[2]). \(refutation)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ActivePlayerSection(
                        players: players,
                        selectedIndex: $selectedPlayerIndex
                    )

                    TurnKindSection(selection: $turnKind)

                    if turnKind == .suspicion {
                        SuspicionSelectionSection(
                            choices: cardChoices,
                            selectedCards: $selectedCards
                        )

                        RefutationSection(
                            candidates: refuterCandidates,
                            maximumSelectionCount: typeJeu == 0 ? 1 : refuterCandidates.count,
                            selectedIndices: $selectedRefuterIndices,
                            isOwnTurn: selectedPlayerIndex == 0,
                            shownCardChoicesByPlayer: shownCardChoicesByPlayer,
                            shownCardSelections: $shownCardSelections
                        )
                    }

                    TurnSummaryCard(
                        summary: summary,
                        isComplete: canSave
                    )
                }
                .padding()
            }
            .navigationTitle("Nouveau tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isSheetPresented = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    saveTurn()
                } label: {
                    Text("Enregistrer le tour")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .padding()
                .background(.regularMaterial)
            }
            .onAppear {
                if grilleUser.indices.contains(joueurActifG),
                   let index = players.firstIndex(of: grilleUser[joueurActifG].nom) {
                    selectedPlayerIndex = index
                }
                updatePlayersWithoutSelectedCard()
                synchronizeKnownResponses()
            }
            .onChange(of: selectedPlayerIndex) { _, _ in
                selectedRefuterIndices.removeAll()
                shownCardSelections = Array(repeating: -1, count: grilleUser.count)
                updatePlayersWithoutSelectedCard()
                synchronizeKnownResponses()
            }
            .onChange(of: selectedCards) { _, _ in
                selectedRefuterIndices.removeAll()
                shownCardSelections = Array(repeating: -1, count: grilleUser.count)
                updatePlayersWithoutSelectedCard()
                synchronizeKnownResponses()
            }
            .onChange(of: turnKind) { _, newValue in
                if newValue == .noSuspicion {
                    selectedRefuterIndices.removeAll()
                    shownCardSelections = Array(repeating: -1, count: grilleUser.count)
                }
            }
        }
    }

    private func updatePlayersWithoutSelectedCard() {
        guard isSelectionComplete else {
            playersWithoutSelectedCard = Array(repeating: false, count: grilleUser.count)
            return
        }

        let verificationGrid = assistanceMode == .notebook ? evidenceGrid : grilleUser
        playersWithoutSelectedCard = verificationGrid.indices.map { playerIndex in
            selectedCards.enumerated().allSatisfy { typeIndex, cardIndex in
                guard verificationGrid[playerIndex].cartes.indices.contains(typeIndex),
                      verificationGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex)
                else {
                    return false
                }
                return verificationGrid[playerIndex].cartes[typeIndex][cardIndex].valeur == "0"
            }
        }

        selectedRefuterIndices = selectedRefuterIndices.filter { index in
            !playersWithoutSelectedCard.indices.contains(index)
                || !playersWithoutSelectedCard[index]
        }
    }

    private func coherentShownCards(for playerIndex: Int) -> [ShownCardChoice] {
        let verificationGrid = assistanceMode == .notebook ? evidenceGrid : grilleUser
        guard verificationGrid.indices.contains(playerIndex) else { return [] }

        return shownCardChoices.filter { choice in
            let typeIndex = choice.id / 1_000
            let cardIndex = choice.id % 1_000
            guard verificationGrid[playerIndex].cartes.indices.contains(typeIndex),
                  verificationGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex),
                  verificationGrid[playerIndex].cartes[typeIndex][cardIndex].valeur != "0"
            else {
                return false
            }

            return !verificationGrid.indices.contains(where: { otherPlayerIndex in
                otherPlayerIndex != playerIndex
                    && verificationGrid[otherPlayerIndex].cartes.indices.contains(typeIndex)
                    && verificationGrid[otherPlayerIndex].cartes[typeIndex].indices.contains(cardIndex)
                    && verificationGrid[otherPlayerIndex].cartes[typeIndex][cardIndex].valeur == "1"
            })
        }
    }

    private func knownMatchingCards(for playerIndex: Int) -> [ShownCardChoice] {
        let verificationGrid = assistanceMode == .notebook ? evidenceGrid : grilleUser
        guard verificationGrid.indices.contains(playerIndex) else { return [] }

        return shownCardChoices.filter { choice in
            let typeIndex = choice.id / 1_000
            let cardIndex = choice.id % 1_000
            guard verificationGrid[playerIndex].cartes.indices.contains(typeIndex),
                  verificationGrid[playerIndex].cartes[typeIndex].indices.contains(cardIndex)
            else {
                return false
            }
            return verificationGrid[playerIndex].cartes[typeIndex][cardIndex].valeur == "1"
        }
    }

    private func synchronizeKnownResponses() {
        if typeJeu == 1 {
            for candidate in refuterCandidates
            where !knownMatchingCards(for: candidate.id).isEmpty {
                selectedRefuterIndices.insert(candidate.id)
            }
        } else {
            for candidate in refuterCandidates {
                if selectedRefuterIndices.contains(candidate.id) {
                    break
                }
                if !knownMatchingCards(for: candidate.id).isEmpty {
                    selectedRefuterIndices = [candidate.id]
                    break
                }
            }
        }

        let ownedCards = knownMatchingCards(for: 1)
        if selectedRefuterIndices.contains(1), ownedCards.count == 1,
           shownCardSelections.indices.contains(1) {
            shownCardSelections[1] = ownedCards[0].id
        }
    }

    private func saveTurn() {
        let currentPlayer = activePlayerIndex
        joueurActifG = currentPlayer

        if turnKind == .suspicion {
            let respondingPlayers = refuterCandidates
                .map(\.id)
                .filter { selectedRefuterIndices.contains($0) }

            let turn = Tour(
                joueurDuTour: currentPlayer,
                personnageSuspecte: selectedCards[0],
                armeSuspectee: selectedCards[1],
                lieuSuspecte: selectedCards[2],
                joueursRepondant: respondingPlayers,
                shownCards: respondingPlayers.compactMap { shownCard(for: $0) }
            )
            recordObservedTurn(turn)
        }

        joueurActifG = (currentPlayer % nb_joueurs) + 1
        saveCurrentGame(activePlayer: joueurActifG)
        isSheetPresented = false
    }

    private func shownCard(for playerIndex: Int) -> ShownCard? {
        guard shownCardSelections.indices.contains(playerIndex) else { return nil }
        let encodedChoice = shownCardSelections[playerIndex]
        guard encodedChoice >= 0 else { return nil }

        return ShownCard(
            playerIndex: playerIndex,
            typeIndex: encodedChoice / 1_000,
            cardIndex: encodedChoice % 1_000
        )
    }

    private func shownCardName(for playerIndex: Int) -> String? {
        guard shownCardSelections.indices.contains(playerIndex) else { return nil }
        let encodedChoice = shownCardSelections[playerIndex]
        guard encodedChoice >= 0 else { return nil }

        let typeIndex = encodedChoice / 1_000
        let cardIndex = encodedChoice % 1_000
        guard nomCartes.indices.contains(typeIndex),
              nomCartes[typeIndex].indices.contains(cardIndex)
        else {
            return nil
        }
        return nomCartes[typeIndex][cardIndex].nom
    }
}

private enum TurnKind: String, CaseIterable, Identifiable {
    case suspicion = "Suspicion"
    case noSuspicion = "Aucune"

    var id: Self { self }
}

private struct ActivePlayerSection: View {
    let players: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        TurnSectionCard(title: "Joueur actif", systemImage: "person.fill") {
            Picker("Tour de", selection: $selectedIndex) {
                ForEach(players.indices, id: \.self) { index in
                    Text(players[index]).tag(index)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TurnKindSection: View {
    @Binding var selection: TurnKind

    var body: some View {
        TurnSectionCard(title: "Action", systemImage: "bubble.left.and.bubble.right") {
            Picker("Action du tour", selection: $selection) {
                ForEach(TurnKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

private struct SuspicionSelectionSection: View {
    let choices: [[CardChoice]]
    @Binding var selectedCards: [Int]

    private let titles = ["Suspect", "Arme", "Lieu"]
    private let symbols = ["person.crop.circle", "hammer", "mappin.and.ellipse"]

    var body: some View {
        TurnSectionCard(title: "Suspicion", systemImage: "magnifyingglass") {
            VStack(spacing: 0) {
                ForEach(titles.indices, id: \.self) { typeIndex in
                    CardSelectionRow(
                        title: titles[typeIndex],
                        systemImage: symbols[typeIndex],
                        choices: choices[typeIndex],
                        selection: $selectedCards[typeIndex]
                    )

                    if typeIndex < titles.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct CardSelectionRow: View {
    let title: String
    let systemImage: String
    let choices: [CardChoice]
    @Binding var selection: Int

    private var selectedChoice: CardChoice? {
        choices.first { $0.id == selection }
    }

    var body: some View {
        Menu {
            ForEach(choices) { choice in
                Button {
                    selection = choice.id
                } label: {
                    HStack {
                        Text("\(choice.marker.menuGlyph) \(choice.name)")
                        if selection == choice.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                if let selectedChoice {
                    CardMarkerView(marker: selectedChoice.marker)
                }
                Text(selectedChoice?.name ?? "Choisir")
                    .foregroundStyle(selectedChoice != nil ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RefutationSection: View {
    let candidates: [RefuterCandidate]
    let maximumSelectionCount: Int
    @Binding var selectedIndices: Set<Int>
    let isOwnTurn: Bool
    let shownCardChoicesByPlayer: [Int: [ShownCardChoice]]
    @Binding var shownCardSelections: [Int]

    var body: some View {
        TurnSectionCard(title: "Résultat", systemImage: "hand.raised.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    selectedIndices.removeAll()
                } label: {
                    SelectionChip(
                        title: "Personne n’a répondu",
                        isSelected: selectedIndices.isEmpty
                    )
                }
                .buttonStyle(.plain)

                ForEach(candidates) { candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            toggle(candidate.id)
                        } label: {
                            SelectionChip(
                                title: candidate.name,
                                isSelected: selectedIndices.contains(candidate.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(candidate.isUnavailable)

                        if (isOwnTurn || candidate.id == 1),
                           selectedIndices.contains(candidate.id) {
                            Picker(
                                "Carte montrée par \(candidate.name)",
                                selection: $shownCardSelections[candidate.id]
                            ) {
                                Text("Choisir la carte montrée").tag(-1)
                                ForEach(shownCardChoicesByPlayer[candidate.id] ?? []) { choice in
                                    Text("\(choice.name) \(choice.marker.menuGlyph)")
                                        .tag(choice.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else if maximumSelectionCount == 1 {
            selectedIndices = [index]
        } else if selectedIndices.count < maximumSelectionCount {
            selectedIndices.insert(index)
        }
    }
}

private struct SelectionChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            Text(title)
            Spacer()
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct TurnSummaryCard: View {
    let summary: String
    let isComplete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Résumé", systemImage: "text.alignleft")
                .font(.headline)
            Text(summary)
                .foregroundStyle(isComplete ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isComplete ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

private struct TurnSectionCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct RefuterCandidate: Identifiable {
    let id: Int
    let name: String
    let isUnavailable: Bool
}

private struct ShownCardChoice: Identifiable {
    let id: Int
    let name: String
    let marker: CardMarker
}

private struct CardChoice: Identifiable {
    let id: Int
    let name: String
    let marker: CardMarker
}

enum CardMarker {
    case color(Color, menuGlyph: String)
    case symbol(String, menuGlyph: String)

    var menuGlyph: String {
        switch self {
        case .color(_, let menuGlyph), .symbol(_, let menuGlyph):
            return menuGlyph
        }
    }

    static func marker(type: Int, index: Int) -> CardMarker {
        switch type {
        case 0:
            let colors: [(Color, String)] = [
                (.green, "🟢"),
                (.yellow, "🟡"),
                (.blue, "🔵"),
                (.purple, "🟣"),
                (.red, "🔴"),
                (.white, "⚪️")
            ]
            return .color(colors[index].0, menuGlyph: colors[index].1)
        case 1:
            let symbols = [
                ("light.recessed.3.fill", "🕯️"),
                ("scissors", "🗡️"),
                ("pipe.and.drop", "🔩"),
                ("scope", "🔫"),
                ("lasso", "🪢"),
                ("wrench.adjustable.fill", "🔧")
            ]
            return .symbol(symbols[index].0, menuGlyph: symbols[index].1)
        default:
            let symbols = [
                ("party.popper.fill", "🎉"),
                ("circle.grid.cross.fill", "🎱"),
                ("leaf.fill", "🌿"),
                ("fork.knife", "🍽️"),
                ("door.left.hand.open", "🚪"),
                ("frying.pan.fill", "🍳"),
                ("books.vertical.fill", "📚"),
                ("sofa.fill", "🛋️"),
                ("desktopcomputer", "🖥️")
            ]
            return .symbol(symbols[index].0, menuGlyph: symbols[index].1)
        }
    }
}

struct CardMarkerView: View {
    let marker: CardMarker

    var body: some View {
        switch marker {
        case .color(let color, _):
            Image(systemName: "circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(color)
                .overlay {
                    Circle()
                        .stroke(.secondary.opacity(0.5), lineWidth: 0.75)
                        .frame(width: 12, height: 12)
                }
                .accessibilityHidden(true)
        case .symbol(let name, _):
            Image(systemName: name)
                .frame(width: 18)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    AskTurnSheet(
        isSheetPresented: .constant(true),
        joueurActifG: .constant(1)
    )
}
