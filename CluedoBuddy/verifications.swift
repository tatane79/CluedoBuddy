import Foundation

func changeValeurCarte(
    grid: [DataJoueur],
    joueur: Int,
    typeElement: Int,
    numElement: Int,
    newValue: String,
    caller: String
) -> (gridchanged: [DataJoueur], caller: String, chgt: Bool) {
    var updatedGrid = grid

    guard ["0", "1", "?"].contains(newValue),
          updatedGrid.indices.contains(joueur),
          updatedGrid[joueur].cartes.indices.contains(typeElement),
          updatedGrid[joueur].cartes[typeElement].indices.contains(numElement)
    else {
        print("\(caller) : coordonnées ou valeur de carte invalides")
        return (updatedGrid, caller, false)
    }

    let oldValue = updatedGrid[joueur].cartes[typeElement][numElement].valeur
    guard oldValue != newValue else {
        return (updatedGrid, caller, false)
    }

    updatedGrid[joueur].cartes[typeElement][numElement].valeur = newValue
    recountPlayer(&updatedGrid[joueur])
    return (updatedGrid, caller, true)
}

func verifTousLesJoueurs(grid: [DataJoueur]) -> [DataJoueur] {
    var updatedGrid = majComptages(gridInput: grid)
    let unknownCount = updatedGrid.reduce(into: 0) { total, player in
        total += player.nb_cartes_inconnues
    }
    let maximumPassCount = unknownCount + 1

    for _ in 0..<maximumPassCount {
        var didChange = false
        didChange = propagateKnownOwners(in: &updatedGrid) || didChange
        didChange = applyCulpritCategoryRules(in: &updatedGrid) || didChange
        didChange = applyPlayerCardCountRules(in: &updatedGrid) || didChange
        didChange = findUniqueOwners(in: &updatedGrid) || didChange
        didChange = evaluateConditionalDeductions(in: &updatedGrid) || didChange

        if !didChange {
            break
        }
    }

    return updatedGrid
}

private func propagateKnownOwners(in grid: inout [DataJoueur]) -> Bool {
    var didChange = false

    for ownerIndex in grid.indices {
        for typeIndex in grid[ownerIndex].cartes.indices {
            for cardIndex in grid[ownerIndex].cartes[typeIndex].indices
            where grid[ownerIndex].cartes[typeIndex][cardIndex].valeur == "1" {
                for otherPlayerIndex in grid.indices where otherPlayerIndex != ownerIndex {
                    guard grid[otherPlayerIndex].cartes.indices.contains(typeIndex),
                          grid[otherPlayerIndex].cartes[typeIndex].indices.contains(cardIndex)
                    else {
                        continue
                    }
                    didChange = assignIfUnknown(
                        "0",
                        player: otherPlayerIndex,
                        type: typeIndex,
                        card: cardIndex,
                        in: &grid
                    ) || didChange
                }
            }
        }
    }

    return didChange
}

private func applyCulpritCategoryRules(in grid: inout [DataJoueur]) -> Bool {
    guard let culpritIndex = grid.indices.first else { return false }

    var didChange = false
    for typeIndex in grid[culpritIndex].cartes.indices {
        let values = grid[culpritIndex].cartes[typeIndex].map(\.valeur)
        let knownCount = values.lazy.filter { $0 == "1" }.count
        let unknownIndices = values.indices.filter { values[$0] == "?" }

        if knownCount == 1 {
            for cardIndex in unknownIndices {
                didChange = assignIfUnknown(
                    "0",
                    player: culpritIndex,
                    type: typeIndex,
                    card: cardIndex,
                    in: &grid
                ) || didChange
            }
        } else if knownCount == 0, unknownIndices.count == 1,
                  let cardIndex = unknownIndices.first {
            didChange = assignIfUnknown(
                "1",
                player: culpritIndex,
                type: typeIndex,
                card: cardIndex,
                in: &grid
            ) || didChange
        }
    }

    return didChange
}

private func applyPlayerCardCountRules(in grid: inout [DataJoueur]) -> Bool {
    var didChange = false

    for playerIndex in grid.indices {
        let player = grid[playerIndex]
        guard player.nb_cartes_1 <= player.nb_cartes else {
            continue
        }

        let valueToAssign: String?
        if player.nb_cartes_1 == player.nb_cartes {
            valueToAssign = "0"
        } else if player.nb_cartes_1 + player.nb_cartes_inconnues == player.nb_cartes {
            valueToAssign = "1"
        } else {
            valueToAssign = nil
        }

        guard let valueToAssign else { continue }

        for typeIndex in grid[playerIndex].cartes.indices {
            for cardIndex in grid[playerIndex].cartes[typeIndex].indices {
                didChange = assignIfUnknown(
                    valueToAssign,
                    player: playerIndex,
                    type: typeIndex,
                    card: cardIndex,
                    in: &grid
                ) || didChange
            }
        }
    }

    return didChange
}

private func findUniqueOwners(in grid: inout [DataJoueur]) -> Bool {
    guard let cardLayout = grid.first?.cartes else { return false }

    var didChange = false
    for typeIndex in cardLayout.indices {
        for cardIndex in cardLayout[typeIndex].indices {
            var hasKnownOwner = false
            var unknownPlayers: [Int] = []

            for playerIndex in grid.indices {
                guard grid[playerIndex].cartes.indices.contains(typeIndex),
                      grid[playerIndex].cartes[typeIndex].indices.contains(cardIndex)
                else {
                    continue
                }

                switch grid[playerIndex].cartes[typeIndex][cardIndex].valeur {
                case "1": hasKnownOwner = true
                case "?": unknownPlayers.append(playerIndex)
                default: break
                }
            }

            if !hasKnownOwner, unknownPlayers.count == 1,
               let playerIndex = unknownPlayers.first {
                didChange = assignIfUnknown(
                    "1",
                    player: playerIndex,
                    type: typeIndex,
                    card: cardIndex,
                    in: &grid
                ) || didChange
            }
        }
    }

    return didChange
}

private func evaluateConditionalDeductions(in grid: inout [DataJoueur]) -> Bool {
    var didChange = false

    for playerIndex in grid.indices {
        for typeIndex in grid[playerIndex].cartes.indices {
            for cardIndex in grid[playerIndex].cartes[typeIndex].indices
            where grid[playerIndex].cartes[typeIndex][cardIndex].valeur == "?" {
                let cell = grid[playerIndex].cartes[typeIndex][cardIndex]
                let zeroValue = evaluate(expression: cell.zeroSi, in: grid)
                let oneValue = evaluate(expression: cell.unSi, in: grid)

                if zeroValue == "1" {
                    didChange = assignIfUnknown(
                        "0",
                        player: playerIndex,
                        type: typeIndex,
                        card: cardIndex,
                        in: &grid
                    ) || didChange
                } else if oneValue == "1" {
                    didChange = assignIfUnknown(
                        "1",
                        player: playerIndex,
                        type: typeIndex,
                        card: cardIndex,
                        in: &grid
                    ) || didChange
                }
            }
        }
    }

    return didChange
}

@discardableResult
private func assignIfUnknown(
    _ value: String,
    player: Int,
    type: Int,
    card: Int,
    in grid: inout [DataJoueur]
) -> Bool {
    guard value == "0" || value == "1",
          grid.indices.contains(player),
          grid[player].cartes.indices.contains(type),
          grid[player].cartes[type].indices.contains(card),
          grid[player].cartes[type][card].valeur == "?"
    else {
        return false
    }

    grid[player].cartes[type][card].valeur = value
    updateCount(from: "?", to: value, for: &grid[player])
    return true
}

private func updateCount(from oldValue: String, to newValue: String, for player: inout DataJoueur) {
    adjustCount(for: oldValue, delta: -1, player: &player)
    adjustCount(for: newValue, delta: 1, player: &player)
}

private func adjustCount(for value: String, delta: Int, player: inout DataJoueur) {
    switch value {
    case "1": player.nb_cartes_1 += delta
    case "0": player.nb_cartes_0 += delta
    case "?": player.nb_cartes_inconnues += delta
    default: break
    }
}

private func recountPlayer(_ player: inout DataJoueur) {
    player.nb_cartes_1 = 0
    player.nb_cartes_0 = 0
    player.nb_cartes_inconnues = 0

    for cards in player.cartes {
        for card in cards {
            adjustCount(for: card.valeur, delta: 1, player: &player)
        }
    }
}

func majComptages(gridInput: [DataJoueur]) -> [DataJoueur] {
    var updatedGrid = gridInput
    for playerIndex in updatedGrid.indices {
        recountPlayer(&updatedGrid[playerIndex])
    }
    return updatedGrid
}

func verifierCoherence(grid: [DataJoueur], grilleSol: [DataJoueur]) {
    guard grid.count == grilleSol.count else {
        print("Erreur de cohérence : les grilles n'ont pas le même nombre de joueurs.")
        return
    }

    var errorCount = 0
    for playerIndex in grid.indices {
        let player = grid[playerIndex]
        let solutionPlayer = grilleSol[playerIndex]

        guard player.cartes.count == solutionPlayer.cartes.count else {
            errorCount += 1
            continue
        }

        for typeIndex in player.cartes.indices {
            guard player.cartes[typeIndex].count == solutionPlayer.cartes[typeIndex].count else {
                errorCount += 1
                continue
            }

            for cardIndex in player.cartes[typeIndex].indices {
                let value = player.cartes[typeIndex][cardIndex].valeur
                let solutionValue = solutionPlayer.cartes[typeIndex][cardIndex].valeur
                if value != "?", value != solutionValue {
                    errorCount += 1
                }
            }
        }

        if player.nb_cartes != solutionPlayer.nb_cartes {
            errorCount += 1
        }
    }

    if errorCount == 0 {
        print("Vérification de cohérence terminée. Aucune incohérence détectée.")
    } else {
        print("\(errorCount) erreur(s) de cohérence trouvées.")
    }
}

func partieResolue(grid: [DataJoueur]) -> Bool {
    guard let culprit = grid.first, culprit.cartes.count == 3 else {
        return false
    }

    return culprit.cartes.allSatisfy { cards in
        cards.lazy.filter { $0.valeur == "1" }.count == 1
    }
}
