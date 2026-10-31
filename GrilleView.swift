//
//  GrilleView.swift
//  CluedoBuddy
//
//  Created by Jonathan Lafarge on 28/11/2023.
//

import SwiftUI
import WStack


struct GrilleView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedElement = 0
    @State private var selectedRow = -1
    @State private var selectedCol = -1
    @State private var selectedColumnInfo: GridColumnInfo?
    @State private var availableWidth: CGFloat = 0
    @State private var isRowHeaderSelected: [Bool] = Array(repeating: false, count: nb_elements.count)
    @State private var isSheetPresented = false
    @Binding var joueurActifG: Int
    @State private var noteIssues: [NoteIssue] = []
    @State private var showNoteIssues = false
    @State private var showAssistantConfirmation = false
    @State private var assistantHelpCount: Int?
    @State private var pendingIssueCheck: Task<Void, Never>?
    @State private var gridRevision = 0
    @State private var lastTurnSummary: RecordedTurnSummary?
    @State private var turnHistory: [RecordedTurnSummary] = []
    @State private var showTurnHistory = false
    @State private var hypothesisDraft: Set<HypothesisCell> = []
    @State private var editedHypothesisID: UUID?
    @State private var showHypotheses = false
    @State private var selectedDeduction: AssistantDeduction?
    @State private var undoStack: [ReversibleGameState] = []
    @State private var redoStack: [ReversibleGameState] = []
    @State private var pendingGameState: ReversibleGameState?
    
    
    let titreSection = ["QUI EST RESPONSABLE ?","AVEC QUELLE ARME ?", "ET OÙ ?"]

    private var rowHeaderWidth: CGFloat {
        let playerColumnsWidth = CGFloat(grilleUser.count) * 30
        let minimumSpacingWidth = CGFloat(grilleUser.count) * 4
        let usableWidth = max(availableWidth - 20, 0)
        return min(
            180,
            max(110, usableWidth - playerColumnsWidth - minimumSpacingWidth)
        )
    }

    private var gridColumnSpacing: CGFloat {
        guard !grilleUser.isEmpty else { return 0 }
        let usableWidth = max(availableWidth - 20, 0)
        let playerColumnsWidth = CGFloat(grilleUser.count) * 30
        let remainingWidth = usableWidth - rowHeaderWidth - playerColumnsWidth
        return min(24, max(0, remainingWidth / CGFloat(grilleUser.count)))
    }

    private var gridColumnInfos: [GridColumnInfo] {
        grilleUser.indices.map { index in
            GridColumnInfo(
                index: index,
                abbreviation: grilleUser[index].nom_court ?? "J",
                meaning: index == 0 ? "Coupable" : grilleUser[index].nom,
                discoveredCardCount: grilleUser[index].cartes
                    .flatMap { $0 }
                    .filter { $0.valeur == "1" }
                    .count,
                cardCount: grilleUser[index].nb_cartes
            )
        }
    }
    
    //    let skyBlue = Color(red: 0.4627, green: 0.8392, blue: 1.0)
    //    let lemonYellow = Color(hue: 0.1639, saturation: 1, brightness: 1)
    //    let steelGray = Color(white: 0.4745)
    
    var body: some View {
        
        VStack(alignment: .leading) {
            GridHeader(
                mode: assistanceMode,
                assistantHelpCount: assistantHelpCount,
                onAssistant: {
                    showAssistantConfirmation = true
                },
                onAudit: {
                    noteIssues = findNoteIssues()
                    showNoteIssues = true
                },
                canUndo: !undoStack.isEmpty,
                canRedo: !redoStack.isEmpty,
                onUndo: undoLastAction,
                onRedo: redoLastAction,
                onNewTurn: {
                    pendingGameState = captureGameState(activePlayer: joueurActifG)
                    isSheetPresented = true
                }
            )

            if !noteIssues.isEmpty {
                GridIssueBanner(count: highlightedCellCount) {
                    noteIssues = findNoteIssues()
                    showNoteIssues = true
                }
            }

            if let lastTurnSummary {
                LastTurnCard(summary: lastTurnSummary) {
                    turnHistory = makeTurnHistory()
                    showTurnHistory = true
                }
            }

            if !hypothesisDraft.isEmpty {
                HypothesisDraftBar(
                    selectedCount: hypothesisDraft.count,
                    canSave: hypothesisDraft.count >= 2,
                    onCancel: cancelHypothesisDraft,
                    onSave: saveHypothesisDraft
                )
            } else if !gridHypotheses.isEmpty {
                Button {
                    showHypotheses = true
                } label: {
                    Label(
                        "\(gridHypotheses.count) hypothèse\(gridHypotheses.count > 1 ? "s" : "")",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            } else {
                Label(
                    "Appui long sur une cellule pour créer une hypothèse",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            StickyGridHeader(
                columns: gridColumnInfos,
                rowHeaderWidth: rowHeaderWidth,
                columnSpacing: gridColumnSpacing,
                onSelect: { selectedColumnInfo = $0 }
            )

            ScrollView {
                VStack(alignment: .leading) {
                    Grid(
                        alignment: .leading,
                        horizontalSpacing: gridColumnSpacing,
                        verticalSpacing: 0
                    ) {
                        ForEach(0..<nomCartes.count, id: \.self) { typeElmt in
                            
                            GridRow(alignment: .firstTextBaseline) {
                                Text(titreSection[typeElmt])
                                    .gridCellColumns(grilleUser.count + 1)
                                    //.padding(.leading, 40) // Ajoute un décalage à gauche
                                    .background(.clear)
                                    .foregroundColor(.gray)
                                    .bold()
                                
                                
                            }
                            .padding(1)
                            RoundedRectangle(cornerRadius: 1)
                                            .foregroundColor( Color( UITableView().separatorColor ?? .gray) )
                                            .frame(height: 4)
                                            .gridCellUnsizedAxes(.horizontal)

                                        //Spacer()
                            // puis, on affiche les lignes dans chaque section :
                            ForEach(0..<nomCartes[typeElmt].count, id: \.self) { elmt in
                                GridRow {
                                    
                                    // l'en-tête de ligne est le nom de l'élément :
                                    rowHeader(type: typeElmt, card: elmt)
                                    
                                    
                                    
                                    // puis on affiche en ligne les valeurs pour cet élément pour chacun des joueurs :
                                    ForEach(0..<grilleUser.count, id: \.self) { j in
                                        
                                        CellView(
                                            value: grilleUser[j].cartes[typeElmt][elmt].valeur,
                                            isProblem: isProblemCell(
                                                player: j,
                                                type: typeElmt,
                                                card: elmt
                                            ),
                                            refreshToken: gridRevision,
                                            hypothesisLabels: hypothesisLabels(
                                                player: j,
                                                type: typeElmt,
                                                card: elmt
                                            ),
                                            isHypothesisDraft: hypothesisDraft.contains(
                                                HypothesisCell(
                                                    playerIndex: j,
                                                    typeIndex: typeElmt,
                                                    cardIndex: elmt
                                                )
                                            )
                                        )
                                        .onTapGesture {
                                            handleCellTap(
                                                player: j,
                                                type: typeElmt,
                                                card: elmt
                                            )
                                        }
                                        .onLongPressGesture(minimumDuration: 0.45) {
                                            if let deduction = assistantDeduction(
                                                player: j,
                                                type: typeElmt,
                                                card: elmt
                                            ) {
                                                selectedDeduction = deduction
                                            } else {
                                                beginHypothesis(
                                                    player: j,
                                                    type: typeElmt,
                                                    card: elmt
                                                )
                                            }
                                        }

                                        
                                        
                                        
                                    }
                                    
                                }
                                //.background(skyBlue)
                                
                            }
                        }
                    }
                    //.padding()
                }
            }
        }
        .padding(10)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
        .popover(item: $selectedColumnInfo) { info in
            ColumnInfoPopover(info: info)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $isSheetPresented, onDismiss: {
            commitPendingAction()
            gridRevision += 1
            lastTurnSummary = makeLastTurnSummary()
            scheduleIssueAlertIfNeeded()
        }) {
            AskTurnSheet(isSheetPresented: $isSheetPresented, joueurActifG: $joueurActifG)
        }
        .onAppear {
            initNomCartes()
            if assistanceMode == .assisted {
                grilleUser = verifTousLesJoueurs(grid: grilleUser)
            }
            noteIssues = findNoteIssues()
            lastTurnSummary = makeLastTurnSummary()
            saveCurrentGame(activePlayer: joueurActifG)
        }
        .confirmationDialog(
            "Faire appel à l’assistant ?",
            isPresented: $showAssistantConfirmation,
            titleVisibility: .visible
        ) {
            Button("Appliquer les déductions certaines") {
                performReversibleAction {
                    assistantHelpCount = applyAssistantHelp()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("L’assistant complètera et corrigera uniquement les cases prouvées par les informations enregistrées.")
        }
        .sheet(isPresented: $showNoteIssues) {
            NoteIssuesView(issues: noteIssues)
        }
        .sheet(isPresented: $showTurnHistory) {
            TurnHistoryView(summaries: $turnHistory) { index, correctedTurn in
                performReversibleAction {
                    noteIssues = replaceObservedTurn(at: index, with: correctedTurn)
                }
            }
        }
        .sheet(isPresented: $showHypotheses) {
            HypothesesView(
                hypotheses: gridHypotheses,
                onEdit: editHypothesis,
                onDelete: deleteHypothesis
            )
        }
        .sheet(item: $selectedDeduction) { deduction in
            DeductionExplanationView(deduction: deduction)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            saveCurrentGame(activePlayer: joueurActifG)
        }
        .onDisappear {
            pendingIssueCheck?.cancel()
            saveCurrentGame(activePlayer: joueurActifG)
        }
    }

    private func rowHeader(type: Int, card: Int) -> some View {
        HStack(spacing: 6) {
            Text(nomCartes[type][card].nom)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 2)
            CardMarkerView(marker: CardMarker.marker(type: type, index: card))
        }
            .padding(.horizontal, 8)
            .foregroundColor(.gray)
            .bold()
            .frame(width: rowHeaderWidth, alignment: .trailing)
            .frame(minHeight: 30)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedRow = type
                selectedElement = card
            }
    }

    private func handleCellTap(player: Int, type: Int, card: Int) {
        let cell = HypothesisCell(
            playerIndex: player,
            typeIndex: type,
            cardIndex: card
        )
        if !hypothesisDraft.isEmpty {
            guard hypothesisDraft.first?.playerIndex == player else { return }
            if hypothesisDraft.contains(cell) {
                hypothesisDraft.remove(cell)
            } else {
                guard !isCardFound(type: type, card: card) else { return }
                hypothesisDraft.insert(cell)
            }
            return
        }
        cycleNote(player: player, type: type, card: card)
    }

    private func beginHypothesis(player: Int, type: Int, card: Int) {
        guard !isCardFound(type: type, card: card) else { return }
        hypothesisDraft = [
            HypothesisCell(
                playerIndex: player,
                typeIndex: type,
                cardIndex: card
            )
        ]
        editedHypothesisID = nil
    }

    private func cancelHypothesisDraft() {
        hypothesisDraft.removeAll()
        editedHypothesisID = nil
    }

    private func saveHypothesisDraft() {
        guard hypothesisDraft.count >= 2,
              hypothesisDraft.allSatisfy({
                  !isCardFound(type: $0.typeIndex, card: $0.cardIndex)
              })
        else { return }
        let cells = hypothesisDraft.sorted {
            ($0.typeIndex, $0.cardIndex) < ($1.typeIndex, $1.cardIndex)
        }

        performReversibleAction {
            if let editedHypothesisID,
               let index = gridHypotheses.firstIndex(where: { $0.id == editedHypothesisID }) {
                gridHypotheses[index].cells = cells
            } else {
                gridHypotheses.append(GridHypothesis(cells: cells))
            }
        }

        hypothesisDraft.removeAll()
        editedHypothesisID = nil
    }

    private func isCardFound(type: Int, card: Int) -> Bool {
        grilleUser.contains { player in
            player.cartes.indices.contains(type)
                && player.cartes[type].indices.contains(card)
                && player.cartes[type][card].valeur == "1"
        }
    }

    private func editHypothesis(_ hypothesis: GridHypothesis) {
        hypothesisDraft = Set(hypothesis.cells)
        editedHypothesisID = hypothesis.id
        showHypotheses = false
    }

    private func deleteHypothesis(_ hypothesis: GridHypothesis) {
        performReversibleAction {
            gridHypotheses.removeAll { $0.id == hypothesis.id }
        }
    }

    private func hypothesisLabels(player: Int, type: Int, card: Int) -> [String] {
        let cell = HypothesisCell(
            playerIndex: player,
            typeIndex: type,
            cardIndex: card
        )
        return gridHypotheses.enumerated().compactMap { index, hypothesis in
            hypothesis.cells.contains(cell) ? "H\(index + 1)" : nil
        }
    }

    private func cycleNote(player: Int, type: Int, card: Int) {
        let currentValue = grilleUser[player].cartes[type][card].valeur
        let nextValue: String
        switch currentValue {
        case "0":
            nextValue = "1"
        case "1":
            nextValue = "?"
        default:
            nextValue = "0"
        }

        var currentIssues: [NoteIssue] = []
        performReversibleAction {
            currentIssues = applyUserNote(
                player: player,
                type: type,
                card: card,
                value: nextValue
            )
        }

        if currentIssues.isEmpty {
            pendingIssueCheck?.cancel()
            noteIssues = []
        } else {
            scheduleIssueAlertIfNeeded()
        }
    }

    private func performReversibleAction(_ action: () -> Void) {
        let previousState = captureGameState(activePlayer: joueurActifG)
        action()
        registerAction(previousState)
        refreshAfterStateChange()
    }

    private func commitPendingAction() {
        guard let pendingGameState else { return }
        self.pendingGameState = nil
        registerAction(pendingGameState)
    }

    private func registerAction(_ previousState: ReversibleGameState) {
        let currentState = captureGameState(activePlayer: joueurActifG)
        guard previousState.fingerprint != currentState.fingerprint else { return }

        undoStack.append(previousState)
        if undoStack.count > 50 {
            undoStack.removeFirst(undoStack.count - 50)
        }
        redoStack.removeAll()
    }

    private func undoLastAction() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(captureGameState(activePlayer: joueurActifG))
        joueurActifG = restoreGameState(previousState)
        refreshAfterStateChange()
    }

    private func redoLastAction() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(captureGameState(activePlayer: joueurActifG))
        joueurActifG = restoreGameState(nextState)
        refreshAfterStateChange()
    }

    private func refreshAfterStateChange() {
        gridRevision += 1
        noteIssues = findNoteIssues()
        turnHistory = makeTurnHistory()
        lastTurnSummary = makeLastTurnSummary()
        hypothesisDraft.removeAll()
        editedHypothesisID = nil
        saveCurrentGame(activePlayer: joueurActifG)
    }

    private func scheduleIssueAlertIfNeeded() {
        pendingIssueCheck?.cancel()
        guard assistanceMode == .notebook, alertsOnNoteError else {
            noteIssues = []
            return
        }

        let detectedIssues = findNoteIssues()
        guard !detectedIssues.isEmpty else {
            noteIssues = []
            return
        }

        noteIssues = []
        pendingIssueCheck = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            noteIssues = findNoteIssues()
        }
    }

    private var highlightedCellCount: Int {
        Set(noteIssues.map {
            GridCellCoordinate(
                player: $0.playerIndex,
                type: $0.typeIndex,
                card: $0.cardIndex
            )
        }).count
    }

    private func isProblemCell(player: Int, type: Int, card: Int) -> Bool {
        noteIssues.contains {
            $0.playerIndex == player
                && $0.typeIndex == type
                && $0.cardIndex == card
        }
    }

    private func makeLastTurnSummary() -> RecordedTurnSummary? {
        guard let turn = toursDeLaPartie.last else { return nil }
        return makeTurnSummary(turn, number: toursDeLaPartie.count)
    }

    private func makeTurnHistory() -> [RecordedTurnSummary] {
        toursDeLaPartie.indices.reversed().map { index in
            makeTurnSummary(toursDeLaPartie[index], number: index + 1)
        }
    }

    private func makeTurnSummary(_ turn: Tour, number: Int) -> RecordedTurnSummary {
        let playerName = gridPlayerName(at: turn.joueurDuTour)
        let suspicion = [
            gridCardName(type: 0, card: turn.personnageSuspecte),
            gridCardName(type: 1, card: turn.armeSuspectee),
            gridCardName(type: 2, card: turn.lieuSuspecte)
        ].formatted(
            .list(type: .and)
                .locale(Locale(identifier: "fr_FR"))
        )

        let response: String
        if turn.joueursRepondant.isEmpty {
            response = "Personne n’a répondu."
        } else {
            response = turn.joueursRepondant.map { playerIndex in
                let name = gridPlayerName(at: playerIndex)
                guard let shownCard = turn.shownCards.first(where: {
                    $0.playerIndex == playerIndex
                }) else {
                    return typeJeu == 0
                        ? "\(name) a réfuté."
                        : "\(name) a répondu — carte non précisée"
                }
                let cardName = gridCardName(
                    type: shownCard.typeIndex,
                    card: shownCard.cardIndex
                )
                return "\(name) a montré « \(cardName) »"
            }.formatted(
                .list(type: .and)
                    .locale(Locale(identifier: "fr_FR"))
            )
        }

        return RecordedTurnSummary(
            number: number,
            turn: turn,
            player: playerName,
            suspicion: suspicion,
            response: response
        )
    }

    private func gridPlayerName(at index: Int) -> String {
        grilleUser.indices.contains(index) ? grilleUser[index].nom : "Joueur"
    }

    private func gridCardName(type: Int, card: Int) -> String {
        guard nomCartes.indices.contains(type), nomCartes[type].indices.contains(card) else {
            return "Carte inconnue"
        }
        return nomCartes[type][card].nom
    }
}

private struct GridCellCoordinate: Hashable {
    let player: Int
    let type: Int
    let card: Int
}

private struct DeductionExplanationView: View {
    let deduction: AssistantDeduction
    @Environment(\.dismiss) private var dismiss

    private var playerName: String {
        grilleUser.indices.contains(deduction.playerIndex)
            ? grilleUser[deduction.playerIndex].nom
            : "Joueur"
    }

    private var cardName: String {
        guard nomCartes.indices.contains(deduction.typeIndex),
              nomCartes[deduction.typeIndex].indices.contains(deduction.cardIndex)
        else { return "Carte" }
        return nomCartes[deduction.typeIndex][deduction.cardIndex].nom
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Déduction de l’assistant", systemImage: "sparkles")
                    .font(.title2.bold())
                    .foregroundStyle(.indigo)

                HStack {
                    Text(cardName)
                        .font(.headline)
                    Spacer()
                    Text(deduction.value == "1" ? "Possède" : "Ne possède pas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(deduction.value == "1" ? .green : .red)
                }

                Text(playerName)
                    .foregroundStyle(.secondary)

                Divider()

                Text(deduction.explanation)
                    .fixedSize(horizontal: false, vertical: true)

                if let sourceTurn = deduction.sourceTurn {
                    Label("Déduction obtenue après le tour \(sourceTurn)", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Pourquoi ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct RecordedTurnSummary: Identifiable {
    var id: Int { number }

    let number: Int
    let turn: Tour
    let player: String
    let suspicion: String
    let response: String
}

private struct GridColumnInfo: Identifiable {
    let index: Int
    let abbreviation: String
    let meaning: String
    let discoveredCardCount: Int
    let cardCount: Int

    var id: Int { index }
}

private struct StickyGridHeader: View {
    let columns: [GridColumnInfo]
    let rowHeaderWidth: CGFloat
    let columnSpacing: CGFloat
    let onSelect: (GridColumnInfo) -> Void

    var body: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: columnSpacing,
            verticalSpacing: 2
        ) {
            GridRow {
                Color.clear
                    .frame(width: rowHeaderWidth, height: 1)

                ForEach(columns) { column in
                    Button {
                        onSelect(column)
                    } label: {
                        if column.index == 0 {
                            SpyIcon()
                                .frame(width: 30, height: 28)
                        } else {
                            Text(column.abbreviation)
                                .foregroundStyle(.secondary)
                                .bold()
                                .frame(width: 30)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(column.meaning)
                    .accessibilityHint("Affiche la signification de l’en-tête")
                }
            }

            GridRow(alignment: .center) {
                Color.clear
                    .frame(width: rowHeaderWidth, height: 1)

                ForEach(columns) { column in
                    WStack(0..<column.cardCount, spacing: 1, lineSpacing: 1) { card in
                        Image(systemName: "checkmark.square.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8, height: 8)
                            .foregroundStyle(
                                card < column.discoveredCardCount
                                    ? Color.primary
                                    : Color.gray.opacity(0.5)
                            )
                    }
                    .frame(width: 30)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(column.discoveredCardCount) cartes connues sur \(column.cardCount)"
                    )
                }
            }
        }
        .padding(.bottom, 5)
        .background(.regularMaterial)
        .zIndex(1)
    }
}

private struct SpyIcon: View {
    var body: some View {
        ZStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
            Image(systemName: "eyeglasses")
                .font(.system(size: 10, weight: .bold))
                .offset(y: 1)
            Image(systemName: "hat.widebrim.fill")
                .font(.system(size: 15))
                .offset(y: -10)
        }
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct ColumnInfoPopover: View {
    let info: GridColumnInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.abbreviation)
                .font(.headline)
            Text(info.meaning)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private struct GridIssueBanner: View {
    let count: Int
    let onOpenExplanation: () -> Void

    var body: some View {
        Button(action: onOpenExplanation) {
            HStack(spacing: 10) {
                Label {
                    if count == 1 {
                        Text("1 cellule incohérente surlignée")
                    } else {
                        Text("\(count) cellules incohérentes surlignées")
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Affiche l’explication des incohérences")
    }
}

private struct LastTurnCard: View {
    let summary: RecordedTurnSummary
    let onOpenHistory: () -> Void

    var body: some View {
        Button(action: onOpenHistory) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Dernier tour · \(summary.number)", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Text("\(summary.player) a suspecté : \(summary.suspicion)")
                    Text(summary.response)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Affiche l’historique des tours")
    }
}

private struct HypothesisDraftBar: View {
    let selectedCount: Int
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nouvelle hypothèse")
                    .font(.subheadline.weight(.semibold))
                Text(
                    selectedCount < 2
                        ? "Touchez au moins une autre cellule du même joueur."
                        : "\(selectedCount) possibilités sélectionnées."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Annuler", action: onCancel)
                .buttonStyle(.borderless)

            Button("Enregistrer", action: onSave)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(10)
        .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HypothesesView: View {
    let hypotheses: [GridHypothesis]
    let onEdit: (GridHypothesis) -> Void
    let onDelete: (GridHypothesis) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(hypotheses.enumerated()), id: \.element.id) { index, hypothesis in
                    HypothesisRow(
                        number: index + 1,
                        hypothesis: hypothesis,
                        onEdit: {
                            onEdit(hypothesis)
                            dismiss()
                        },
                        onDelete: {
                            onDelete(hypothesis)
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle("Mes hypothèses")
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

private struct HypothesisRow: View {
    let number: Int
    let hypothesis: GridHypothesis
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var playerName: String {
        guard let playerIndex = hypothesis.cells.first?.playerIndex,
              grilleUser.indices.contains(playerIndex)
        else {
            return "Joueur"
        }
        return grilleUser[playerIndex].nom
    }

    private var cardNames: [String] {
        hypothesis.cells.compactMap { cell in
            guard nomCartes.indices.contains(cell.typeIndex),
                  nomCartes[cell.typeIndex].indices.contains(cell.cardIndex)
            else {
                return nil
            }
            return nomCartes[cell.typeIndex][cell.cardIndex].nom
        }
    }

    private var remainingCells: [HypothesisCell] {
        hypothesis.cells.filter { cell in
            guard grilleUser.indices.contains(cell.playerIndex),
                  grilleUser[cell.playerIndex].cartes.indices.contains(cell.typeIndex),
                  grilleUser[cell.playerIndex].cartes[cell.typeIndex].indices.contains(cell.cardIndex)
            else {
                return false
            }
            return grilleUser[cell.playerIndex].cartes[cell.typeIndex][cell.cardIndex].valeur != "0"
        }
    }

    private var isResolved: Bool {
        hypothesis.cells.contains { cell in
            guard grilleUser.indices.contains(cell.playerIndex),
                  grilleUser[cell.playerIndex].cartes.indices.contains(cell.typeIndex),
                  grilleUser[cell.playerIndex].cartes[cell.typeIndex].indices.contains(cell.cardIndex)
            else {
                return false
            }
            return grilleUser[cell.playerIndex].cartes[cell.typeIndex][cell.cardIndex].valeur == "1"
        }
    }

    private var statusText: String {
        if isResolved {
            return "Hypothèse confirmée"
        }
        if remainingCells.isEmpty {
            return "Hypothèse incohérente"
        }
        if remainingCells.count == 1,
           let cell = remainingCells.first,
           nomCartes.indices.contains(cell.typeIndex),
           nomCartes[cell.typeIndex].indices.contains(cell.cardIndex) {
            return "Conclusion possible : \(nomCartes[cell.typeIndex][cell.cardIndex].nom)"
        }
        return "Au moins une de ces cartes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("H\(number)")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text(playerName)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Modifier", action: onEdit)
                    Button("Supprimer", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            Text(
                cardNames.formatted(
                    .list(type: .and)
                        .locale(Locale(identifier: "fr_FR"))
                )
            )
            Text(statusText)
                .font(.caption)
                .foregroundStyle(
                    remainingCells.isEmpty && !isResolved ? Color.red : Color.secondary
                )

            if let sourceTurn = hypothesis.sourceTurn {
                Text("Créée à partir du tour \(sourceTurn)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TurnHistoryView: View {
    @Binding var summaries: [RecordedTurnSummary]
    let onSave: (Int, Tour) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingSummary: RecordedTurnSummary?

    var body: some View {
        NavigationStack {
            List(summaries) { summary in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tour \(summary.number)")
                            .font(.headline)
                        Text("\(summary.player) a suspecté : \(summary.suspicion)")
                        Text(summary.response)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Modifier") {
                        editingSummary = summary
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Historique des tours")
            .overlay {
                if summaries.isEmpty {
                    ContentUnavailableView(
                        "Aucun tour",
                        systemImage: "clock",
                        description: Text("Les tours enregistrés apparaîtront ici.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingSummary) { summary in
                EditTurnSheet(turnNumber: summary.number, turn: summary.turn) { correctedTurn in
                    onSave(summary.number - 1, correctedTurn)
                    editingSummary = nil
                }
            }
        }
    }
}

private struct EditTurnSheet: View {
    let turnNumber: Int
    let onSave: (Tour) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var playerIndex: Int
    @State private var suspectIndex: Int
    @State private var weaponIndex: Int
    @State private var locationIndex: Int
    @State private var responders: Set<Int>
    @State private var shownCardSelections: [Int: Int]

    init(turnNumber: Int, turn: Tour, onSave: @escaping (Tour) -> Void) {
        self.turnNumber = turnNumber
        self.onSave = onSave
        _playerIndex = State(initialValue: turn.joueurDuTour)
        _suspectIndex = State(initialValue: turn.personnageSuspecte)
        _weaponIndex = State(initialValue: turn.armeSuspectee)
        _locationIndex = State(initialValue: turn.lieuSuspecte)
        _responders = State(initialValue: Set(turn.joueursRepondant))
        _shownCardSelections = State(initialValue: Dictionary(
            uniqueKeysWithValues: turn.shownCards.map {
                ($0.playerIndex, Self.encode(type: $0.typeIndex, card: $0.cardIndex))
            }
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Suggestion") {
                    Picker("Joueur", selection: $playerIndex) {
                        ForEach(grilleUser.indices.dropFirst(), id: \.self) { index in
                            Text(grilleUser[index].nom).tag(index)
                        }
                    }
                    Picker("Suspect", selection: $suspectIndex) {
                        ForEach(nomCartes[0].indices, id: \.self) { index in
                            Text(nomCartes[0][index].nom).tag(index)
                        }
                    }
                    Picker("Arme", selection: $weaponIndex) {
                        ForEach(nomCartes[1].indices, id: \.self) { index in
                            Text(nomCartes[1][index].nom).tag(index)
                        }
                    }
                    Picker("Lieu", selection: $locationIndex) {
                        ForEach(nomCartes[2].indices, id: \.self) { index in
                            Text(nomCartes[2][index].nom).tag(index)
                        }
                    }
                }

                Section("Réponses") {
                    ForEach(grilleUser.indices.dropFirst().filter { $0 != playerIndex }, id: \.self) { index in
                        Button {
                            toggleResponder(index)
                        } label: {
                            HStack {
                                Text(grilleUser[index].nom)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if responders.contains(index) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        if responders.contains(index) {
                            Picker("Carte montrée", selection: $shownCardSelections[index]) {
                                Text("Non précisée").tag(Optional<Int>.none)
                                ForEach(shownCardChoices, id: \.value) { choice in
                                    Text(choice.name).tag(Optional(choice.value))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Modifier le tour \(turnNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(makeCorrectedTurn())
                    }
                }
            }
        }
    }

    private var shownCardChoices: [(name: String, value: Int)] {
        [
            (nomCartes[0][suspectIndex].nom, Self.encode(type: 0, card: suspectIndex)),
            (nomCartes[1][weaponIndex].nom, Self.encode(type: 1, card: weaponIndex)),
            (nomCartes[2][locationIndex].nom, Self.encode(type: 2, card: locationIndex))
        ]
    }

    private func toggleResponder(_ index: Int) {
        shownCardSelections[index] = nil
        if responders.contains(index) {
            responders.remove(index)
        } else if typeJeu == 0 {
            responders = [index]
            shownCardSelections = [:]
        } else if responders.count < 3 {
            responders.insert(index)
        }
    }

    private func makeCorrectedTurn() -> Tour {
        let validChoices = Set(shownCardChoices.map(\.value))
        let sortedResponders = responders.filter { $0 != playerIndex }.sorted()
        let shownCards = sortedResponders.compactMap { responder -> ShownCard? in
            guard let value = shownCardSelections[responder], validChoices.contains(value) else {
                return nil
            }
            return ShownCard(
                playerIndex: responder,
                typeIndex: value / 1_000,
                cardIndex: value % 1_000
            )
        }
        return Tour(
            joueurDuTour: playerIndex,
            personnageSuspecte: suspectIndex,
            armeSuspectee: weaponIndex,
            lieuSuspecte: locationIndex,
            joueursRepondant: sortedResponders,
            shownCards: shownCards
        )
    }

    private static func encode(type: Int, card: Int) -> Int {
        type * 1_000 + card
    }
}

private struct GridHeader: View {
    let mode: GameAssistanceMode
    let assistantHelpCount: Int?
    let onAssistant: () -> Void
    let onAudit: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onNewTurn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Ma grille")
                    .font(.title.bold())
                Spacer()
                GameModeStatus(mode: mode)
            }

            HStack {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!canUndo)
                .accessibilityLabel("Annuler")

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!canRedo)
                .accessibilityLabel("Rétablir")

                Spacer()

                if mode == .notebook {
                    Button(action: onAssistant) {
                        Label("Assistant", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)

                    Button(action: onAudit) {
                        Label("Vérifier", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: onNewTurn) {
                    Label("Tour", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if let assistantHelpCount {
                HStack {
                    Spacer()
                    if assistantHelpCount == 0 {
                        Text("L’assistant n’a aucune nouvelle déduction certaine.")
                    } else if assistantHelpCount == 1 {
                        Text("1 déduction certaine appliquée.")
                    } else {
                        Text("\(assistantHelpCount) déductions certaines appliquées.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}

extension String {
    func foregroundColor(_ color: Color) -> Text {
        return Text(self).foregroundColor(color)
    }
}


struct GrilleView_Previews: PreviewProvider {
    static var previews: some View {
        GrilleView(joueurActifG: .constant(2))
    }
}
