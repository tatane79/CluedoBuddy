//
//  CluedoGrid.swift
//  CluedoSolver
//
//  Created by Jonathan Lafarge on 04/11/2023.
//

import Foundation
import SwiftUI


// on définit la dimension de la grille pour le Cluedo Standard
// TODO: rendre ces nombres dépendant du type de Cluedo choisi (Super Cluedo, etc.)

var nb_suspects = 6
var nb_armes = 6
var nb_lieux = 9


// on définit le type de jeu
var typeJeu = 1
// 0: jeu standard : seul le 1er joueur qui possède une carte demandée en partant de la gauche la montre
// 1: jeu "Accéléré" : tous les joueurs qui possèdent une carte demandée doivent la montrer (une seule carte montrée par joueur)



// Définissez une structure pour stocker les données de chaque cellule
struct CellData: Codable {
    var nom: String = ""
    var valeur: String = "?" // "?" si inconnu (par défaut), 1 si le joueur l'a, 0 s'il ne l'a pas
    var zeroSi = BooleanExpression.operand("0") // contiendra une expression booléenne permettant de déterminer que la cellule vaut zéro si cette expression est vraie
    var unSi = BooleanExpression.operand("0") // contiendra une expression booléenne permettant de déterminer que la cellule vaut un si cette expression est vraie
    var isSelected: Bool = false // indique si la cellule est sélectionnée sur la grille
    
    // Ajoutez la conformité à Decodable pour chaque type utilisé à l'intérieur de CellData
    private enum CodingKeys: String, CodingKey {
        case nom
        case valeur
        case zeroSi
        case unSi
    }
}

let nb_elements = [nb_suspects,nb_armes,nb_lieux]

// on crée un modèle de vecteur de suspects
var vSuspects = Array(repeating: CellData(valeur: "?"), count: nb_suspects)

// on crée un modèle de vecteur d'armes
var vArmes = Array(repeating: CellData(valeur: "?"), count: nb_armes)

// on crée un modèle de vecteur de lieux
var vLieux = Array(repeating: CellData(valeur: "?"), count: nb_lieux)

// on crée un modèle de vecteur de cartes d'un joueur
var vCartes = [vSuspects,vArmes,vLieux]

struct DataJoueur: Codable, Identifiable {
    // on crée un modèle de vecteur de joueur, composé des trois vecteurs de suspects, d'armes et de lieux
    var id = UUID()
    var cartes: [[CellData]]
    var nb_cartes: Int // nombre de cartes que possède le joueur
    var nb_cartes_1: Int // contiendra le comptage du nombre de cartes à "1" pour ce joueur
    var nb_cartes_0: Int // contiendra le comptage du nombre de cartes à "0" pour ce joueur
    var nb_cartes_inconnues: Int // contiendra le comptage du nombre de cartes à "?" pour ce joueur
    var nom: String // nom du joueur
    var nom_court: String? // nom du joueur sur 2 ou 3 lettres (facultatif)
    
    mutating func initCartes() {
            let nb_elements = [nb_suspects, nb_armes, nb_lieux]

            for i in 0..<nb_elements.count {
                var elementCartes = [CellData]()
                for _ in 0..<nb_elements[i] {
                    var nouvelleCarte = CellData()
                    nouvelleCarte.valeur = "?"
                    elementCartes.append(nouvelleCarte)
                }
                cartes.append(elementCartes)
            }
        }
    
    // Ajouter la conformité à Encodable pour chaque type utilisé à l'intérieur de DataJoueur
    private enum CodingKeys: String, CodingKey {
        case cartes
        case nb_cartes
        case nb_cartes_1
        case nb_cartes_0
        case nb_cartes_inconnues
        case nom
        case nom_court
    }
}

func creerNomCourt(grid: [DataJoueur]) -> [DataJoueur] {
    var grilleL = grid
    for j in 0..<grid.count {
        var nomCourt: String
        if grid[j].nom.count >= 2 {
            nomCourt = String(grid[j].nom.prefix(2))
        } else {
            nomCourt = "J\(j + 1)"
        }
        grilleL[j].nom_court = nomCourt
    }
    return grilleL
}

func initialiserGrille(noms: [String]) -> [DataJoueur] {
    initNomCartes()
    var grille = [DataJoueur]()
    //var evenCards = 0
    
//    if noms.count == 6 {
//        evenCards = 3
//    }
    
    // on crée le coupable à l'index zéro de la grille :
    var coupable = DataJoueur(
        cartes: [], // Initialisez-le en fonction de vos besoins
        nb_cartes: 3, // le coupable a toujours 3 cartes, quelle que soit la version du jeu de Cluedo : 1 carte de chaque type d'élément suspect, arme, lieu.
        nb_cartes_1: 0,
        nb_cartes_0: 0,
        nb_cartes_inconnues: 0,
        nom: "Coupable",
        nom_court: "Cp" // Vous pouvez initialiser cela en fonction de vos besoins
    )
    coupable.initCartes()
    grille.append(coupable)
    
    
    for (index, nomJoueur) in noms.enumerated() {
            var nomCourt: String
            if nomJoueur.count >= 2 {
                nomCourt = String(nomJoueur.prefix(2))
            } else {
                nomCourt = "J\(index + 1)"
            }
        
            var nouveauJoueur = DataJoueur(
                cartes: [], // Initialisez-le en fonction de vos besoins
                nb_cartes: 0,
                nb_cartes_1: 0,
                nb_cartes_0: 0,
                nb_cartes_inconnues: 0,
                nom: nomJoueur,
                nom_court: nomCourt
            )
            nouveauJoueur.initCartes()

            grille.append(nouveauJoueur)
        }
        return grille
}

//---------------------------------------------------------------------------------------------------------------
// on crée la grille du jeu pour le joueur 1, avec autant de colonnes que de joueurs + 1 colonne pour le coupable (qu'on va considérer en index 0)

var grilleUser = initialiserGrille(noms: [])

// grille pour le prévisualiseur XCode :
// var grilleUser = distribuer(grid: initialiserGrille(noms: ["Jonathan","Adeline","Clovis","Garance"]))


// exemple d'affectation : je déclare que le lieu (index 2) numéro 4 (index 3) du joueur 1 (index 1 puisque l'index 0 des joueurs est réservé au coupable) vaut "1"
// grille[1].cartes[2][3].valeur = "1"

//---------------------------------------------------------------------------------------------------------------


// on crée la grille de jeu complétée (la solution) :
var grilleSolution = [DataJoueur]()

// on définit les éléments
var nomCartes = vCartes

// on définit une instance de Tour
struct ShownCard: Codable, Equatable {
    let playerIndex: Int
    let typeIndex: Int
    let cardIndex: Int
}

struct Tour: Codable {
    var joueurDuTour: Int
    var personnageSuspecte: Int
    var armeSuspectee: Int
    var lieuSuspecte: Int
    var joueursRepondant: [Int]
    var shownCards: [ShownCard]

    init(
        joueurDuTour: Int,
        personnageSuspecte: Int,
        armeSuspectee: Int,
        lieuSuspecte: Int,
        joueursRepondant: [Int],
        shownCards: [ShownCard] = []
    ) {
        self.joueurDuTour = joueurDuTour
        self.personnageSuspecte = personnageSuspecte
        self.armeSuspectee = armeSuspectee
        self.lieuSuspecte = lieuSuspecte
        self.joueursRepondant = joueursRepondant
        self.shownCards = shownCards
    }

    private enum CodingKeys: String, CodingKey {
        case joueurDuTour
        case personnageSuspecte
        case armeSuspectee
        case lieuSuspecte
        case joueursRepondant
        case shownCards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        joueurDuTour = try container.decode(Int.self, forKey: .joueurDuTour)
        personnageSuspecte = try container.decode(Int.self, forKey: .personnageSuspecte)
        armeSuspectee = try container.decode(Int.self, forKey: .armeSuspectee)
        lieuSuspecte = try container.decode(Int.self, forKey: .lieuSuspecte)
        joueursRepondant = try container.decode([Int].self, forKey: .joueursRepondant)
        shownCards = try container.decodeIfPresent([ShownCard].self, forKey: .shownCards) ?? []
    }
}

// on définit la variable globale qui va contenir le numéro du joueur Actif :
var joueurActif = 1 // par défaut, c'est l'utilisateur qui sera le joueur actif au départ

// on définit la variable globale qui va contenir l'historique des tours de la partie en cours :
var toursDeLaPartie = [Tour]()

// on définit la variable globale qui contiendra le numéro du tour résolu
var tourResolution = -1

// on définit la variable globale qui va contenir l'index du joueur
func initNomCartes() {
    //définition des noms de suspects
    nomCartes[0][0].nom = "Olive"
    nomCartes[0][1].nom = "Moutarde"
    nomCartes[0][2].nom = "Pervenche"
    nomCartes[0][3].nom = "Violet"
    nomCartes[0][4].nom = "Rose"
    nomCartes[0][5].nom = "Leblanc"
    // on récupère le nombre de suspects :
    nb_suspects = nomCartes[0].count
    
    //définition des noms d'armes
    nomCartes[1][0].nom = "Chandelier"
    nomCartes[1][1].nom = "Poignard"
    nomCartes[1][2].nom = "Barre de fer"
    nomCartes[1][3].nom = "Révolver"
    nomCartes[1][4].nom = "Corde"
    nomCartes[1][5].nom = "Clé anglaise"
    // on récupère le nombre d'armes :
    nb_armes = nomCartes[1].count
    
    //définition des noms de lieux
    nomCartes[2][0].nom = "S. de réception"
    nomCartes[2][1].nom = "S. de billard"
    nomCartes[2][2].nom = "Jardin d'hiver"
    nomCartes[2][3].nom = "S. à manger"
    nomCartes[2][4].nom = "Entrée"
    nomCartes[2][5].nom = "Cuisine"
    nomCartes[2][6].nom = "Bibliothèque"
    nomCartes[2][7].nom = "Salon"
    nomCartes[2][8].nom = "Bureau"
    //on récupère le nombre de lieux :
    nb_lieux = nomCartes[2].count
}


func gererTour(tour: Tour) {
    let requestedCards = [
        (type: 0, card: tour.personnageSuspecte),
        (type: 1, card: tour.armeSuspectee),
        (type: 2, card: tour.lieuSuspecte)
    ]
    guard grilleUser.indices.contains(tour.joueurDuTour),
          requestedCards.allSatisfy({ type, card in
              nomCartes.indices.contains(type) && nomCartes[type].indices.contains(card)
          })
    else {
        return
    }

    let responders = Set(tour.joueursRepondant.filter {
        grilleUser.indices.contains($0) && $0 != 0 && $0 != tour.joueurDuTour
    })

    let playersKnownNotToHaveRequestedCards: Set<Int>
    if typeJeu == 0 {
        let orderedPlayers = clockwisePlayers(after: tour.joueurDuTour, in: grilleUser)
        if let firstResponder = orderedPlayers.first(where: { responders.contains($0) }) {
            playersKnownNotToHaveRequestedCards = Set(
                orderedPlayers.prefix { $0 != firstResponder }
            )
            addRefutationConstraint(
                player: firstResponder,
                requestedCards: requestedCards,
                in: &grilleUser
            )
        } else {
            playersKnownNotToHaveRequestedCards = Set(orderedPlayers)
        }
    } else {
        playersKnownNotToHaveRequestedCards = Set(
            grilleUser.indices.filter {
                $0 != 0 && $0 != tour.joueurDuTour && !responders.contains($0)
            }
        )
        for responder in responders {
            addRefutationConstraint(
                player: responder,
                requestedCards: requestedCards,
                in: &grilleUser
            )
        }
    }

    for player in playersKnownNotToHaveRequestedCards {
        for requestedCard in requestedCards {
            guard grilleUser[player].cartes[requestedCard.type][requestedCard.card].valeur != "1"
            else { continue }
            grilleUser[player].cartes[requestedCard.type][requestedCard.card].valeur = "0"
        }
    }

    grilleUser = verifTousLesJoueurs(grid: grilleUser)
    if partieResolue(grid: grilleUser), tourResolution < 0 {
        tourResolution = toursDeLaPartie.count
    }
}

private func clockwisePlayers(after activePlayer: Int, in grid: [DataJoueur]) -> [Int] {
    let playerCount = max(grid.count - 1, 0)
    guard playerCount > 1 else { return [] }
    return (1..<playerCount).map { offset in
        ((activePlayer - 1 + offset) % playerCount) + 1
    }
}

private func addRefutationConstraint(
    player: Int,
    requestedCards: [(type: Int, card: Int)],
    in grid: inout [DataJoueur]
) {
    guard grid.indices.contains(player), requestedCards.count == 3 else { return }

    for (index, requestedCard) in requestedCards.enumerated() {
        guard grid[player].cartes[requestedCard.type][requestedCard.card].valeur == "?" else {
            continue
        }
        let otherCards = requestedCards.enumerated().compactMap { otherIndex, card in
            otherIndex == index
                ? nil
                : BooleanExpression.notExpression(
                    .pointeur(player, card.type, card.card)
                )
        }
        guard otherCards.count == 2 else { continue }
        let inferredOwner = BooleanExpression.expression(otherCards[0], .and, otherCards[1])
        let existingRule = grid[player].cartes[requestedCard.type][requestedCard.card].unSi
        grid[player].cartes[requestedCard.type][requestedCard.card].unSi = .expression(
            inferredOwner,
            .or,
            existingRule
        )
    }
}

// Conservée temporairement comme référence de migration ; le moteur actif ci-dessus
// traite désormais un nombre quelconque de joueurs répondants.
private func legacyGererTour(tour: Tour){
    printTour(tour: tour)
    switch typeJeu {
    case 0: // partie standard
        
        // On liste les joueurs qui n'ont pas de carte (ils précèdent le joueur qui a répondu)
        var joueursSansCarte: [Int] = []
        // Créer l'ordre des joueurs à partir de joueurDuTour (sans le joueur 0)
        let ordreJoueurs = Array(grilleUser.indices)
            .filter { $0 != 0 && $0 != tour.joueurDuTour }
            .circularShift(amount: tour.joueurDuTour - 1)
        
        
        
        // Ajouter les joueurs après le joueur actif jusqu'au joueur répondant
        for joueurIndex in ordreJoueurs {
            // Assurez-vous d'exclure le joueur 0
            if tour.joueursRepondant.isEmpty || joueurIndex == tour.joueursRepondant[0] {
                break
            } else {
                joueursSansCarte.append(joueurIndex)
            }
        }
        
        // Ajouter les joueurs depuis le début jusqu'au joueur répondant (excluant le joueur actif)
        // je pense qu'il faut désactiver ce code ci=dessous
        //        for joueurIndex in 1..<tour.joueurDuTour {
        //            joueursSansCarte.append(joueurIndex)
        //        }
        
        switch tour.joueursRepondant.count {
        case 0:
            // Aucune carte n'a été montrée
            // Pour chaque élément suspecté, mettre la valeur à zéro pour tous les joueurs sauf le joueurDuTour
            for i in 1..<nb_joueurs + 1 { // pour chacun des joueurs (autre que le coupable à l'index 0)
                if i != tour.joueurDuTour {
                    // on ne peut rien savoir des cartes du joueur actif
                    // pour les autres joueurs, ils n'ont aucune de ces 3 cartes
                    grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    grilleUser[i].cartes[1][tour.armeSuspectee].valeur = "0"
                    grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                }
            }
            break
        default:
            // Une carte a été montrée
            // pour chaque objet suspecté, mettre la valeur à zéro pour tous les joueurs entre le joueurDuTour (exclu) et le joueurRepondant (exclu)
            // TODO: vérifier qu'on n'a pas écrasé des 1 déjà connus. Si c'est le cas, quelqu'un a menti !
            
            for i in 1..<nb_joueurs + 1 { // pour chacun des joueurs (autre que le coupable à l'index 0)
                let boolExpA = BooleanExpression.pointeur(i, 0, tour.personnageSuspecte)
                let boolExpB = BooleanExpression.pointeur(i, 1, tour.armeSuspectee)
                let boolExpC = BooleanExpression.pointeur(i, 2, tour.lieuSuspecte)
                let nonA = BooleanExpression.notExpression(boolExpA)
                let nonB = BooleanExpression.notExpression(boolExpB)
                let nonC = BooleanExpression.notExpression(boolExpC)
                let boolExpAfaux = BooleanExpression.expression(boolExpB, .and, boolExpC)
                switch i {
                case _ where joueursSansCarte.contains(i):
                    // le joueur i est dans joueursSansCarte
                    // Mettez à zéro les cartes suspectées
                    grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    grilleUser[i].cartes[1][tour.armeSuspectee].valeur = "0"
                    grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                case tour.joueurDuTour:
                    // pour le joueur actif, on en déduit qu'il n'a pas une des trois cartes, donc si l'on sait qu'il a les deux autres, il ne peut pas avoir celle-ci.
                    
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi = BooleanExpression.expression(boolExpAfaux, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi))")
                        
                    }
                    let boolExpBfaux = BooleanExpression.expression(boolExpA, .and, boolExpC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi = BooleanExpression.expression(boolExpBfaux, .or, grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi))")
                        
                    }
                    let boolExpCfaux = BooleanExpression.expression(boolExpA, .and, boolExpB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi = BooleanExpression.expression(boolExpCfaux, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi))")
                        
                    }
                case tour.joueursRepondant[0]:
                    // pour ce joueur qui a montré sa carte, relier les 3 éléments suspectés : A+B+C=1 (en booléen)
                    // i.e. : A=1 si B=0 et C=0
                    
                    let boolExpAvrai = BooleanExpression.expression(nonB, .and, nonC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].unSi = BooleanExpression.expression(boolExpAvrai, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].unSi))")
                        
                    }
                    let boolExpBvrai = BooleanExpression.expression(nonA, .and, nonC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].unSi = BooleanExpression.expression(boolExpBvrai, .or, grilleUser[i].cartes[1][tour.armeSuspectee].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].unSi))")
                        
                    }
                    let boolExpCvrai = BooleanExpression.expression(nonA, .and, nonB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].unSi = BooleanExpression.expression(boolExpCvrai, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].unSi))")
                        
                    }
                    
                    
                default:
                    // on est dans le cas de joueurs qui n'ont pas eu à répondre, car situé après le joueur qui a répondu (dans le cas d'un typeJeu - 1 (règles standards du Cluedo)
                    // on ne peut rien conclure.
                    break
                    
                }
                
            }
        }
        
    case 1: // partie "Accéléré" : tous les joueurs qui en possède doivent montrer une carte
        switch tour.joueursRepondant.count {
        case 0:
            // Aucune carte n'a été montrée
            // Pour chaque élément suspecté, mettre la valeur à zéro pour tous les joueurs entre le joueurDuTour (exclu) et le joueurRepondant (exclu)
            for i in 1..<nb_joueurs + 1 { // pour chacun des joueurs (autre que le coupable à l'index 0)
                if i != tour.joueurDuTour {
                    // on ne peut rien savoir des cartes du joueur actif
                    // pour les autres joueurs, ils n'ont aucune de ces 3 cartes
                    
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[0][tour.personnageSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[1][tour.armeSuspectee].valeur)")
                    }
                    
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[2][tour.lieuSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                    }
                }
            }
            break
        case 1:
            // Une carte a été montrée
            // pour chaque objet suspecté, metttre les joueurs autres que le joueur actif et le joueur montrant sa carte à zéro
            // TODO: vérifier qu'on n'a pas écrasé des 1 déjà connus. Si c'est le cas, quelqu'un a menti !
            for i in 1..<nb_joueurs + 1 { // pour chacun des joueurs (autre que le coupable à l'index 0)
                let boolExpA = BooleanExpression.pointeur(i, 0, tour.personnageSuspecte)
                let boolExpB = BooleanExpression.pointeur(i, 1, tour.armeSuspectee)
                let boolExpC = BooleanExpression.pointeur(i, 2, tour.lieuSuspecte)
                let nonA = BooleanExpression.notExpression(boolExpA)
                let nonB = BooleanExpression.notExpression(boolExpB)
                let nonC = BooleanExpression.notExpression(boolExpC)
                switch i {
                case tour.joueurDuTour:
                    // pour le joueur actif, on en déduit qu'il n'a pas une des trois cartes, donc si l'on sait qu'il a les deux autres, il ne peut pas avoir celle-ci.
                    let boolExpAfaux = BooleanExpression.expression(boolExpB, .and, boolExpC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi = BooleanExpression.expression(boolExpAfaux, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi))")
                        
                    }
                    let boolExpBfaux = BooleanExpression.expression(boolExpA, .and, boolExpC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi = BooleanExpression.expression(boolExpBfaux, .or, grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi))")
                        
                    }
                    let boolExpCfaux = BooleanExpression.expression(boolExpA, .and, boolExpB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi = BooleanExpression.expression(boolExpCfaux, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi))")
                        
                    }
                case tour.joueursRepondant[0]:
                    // pour ce joueur qui a montré sa carte, relier les 3 éléments suspectés : A+B+C=1 (en booléen)
                    // i.e. : A=1 si B=0 et C=0
                    
                    let boolExpAvrai = BooleanExpression.expression(nonB, .and, nonC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].unSi = BooleanExpression.expression(boolExpAvrai, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].unSi))")
                        
                    }
                    let boolExpBvrai = BooleanExpression.expression(nonA, .and, nonC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].unSi = BooleanExpression.expression(boolExpBvrai, .or, grilleUser[i].cartes[1][tour.armeSuspectee].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].unSi))")
                        
                    }
                    let boolExpCvrai = BooleanExpression.expression(nonA, .and, nonB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].unSi = BooleanExpression.expression(boolExpCvrai, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].unSi))")
                        
                    }
                    
                    
                default:
                    // pour les autres joueurs, ils n'ont aucune de ces 3 cartes
                    
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[0][tour.personnageSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[1][tour.armeSuspectee].valeur)")
                    } else {
                        grilleUser[i].cartes[1][tour.armeSuspectee].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 1 (une carte montrée : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[2][tour.lieuSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                    }
                    
                    
                    
                }
            }
            break
        case 2:
            // Deux cartes ont été montrées
            // pour chaque objet suspecté, metttre les joueurs autres que le joueur actif et les 2 joueurs montrant leur carte à zéro
            // TODO: vérifier qu'on n'a pas écrasé des 1 déjà connus. Si c'est le cas, quelqu'un a menti !
            for i in 1..<nb_joueurs + 1 { // pour chacun des joueurs (autre que le coupable à l'index 0)
                let boolExpA = BooleanExpression.pointeur(i, 0, tour.personnageSuspecte)
                let boolExpB = BooleanExpression.pointeur(i, 1, tour.armeSuspectee)
                let boolExpC = BooleanExpression.pointeur(i, 2, tour.lieuSuspecte)
                let nonA = BooleanExpression.notExpression(boolExpA)
                let nonB = BooleanExpression.notExpression(boolExpB)
                let nonC = BooleanExpression.notExpression(boolExpC)
                switch i {
                case tour.joueurDuTour:
                    // pour le joueur actif : il n'a au plus qu'une des trois cartes demandées. Donc par couple de deux de ces cartes, il y a forcément une carte absente :
                    let boolExpAfaux = BooleanExpression.expression(boolExpB, .or, boolExpC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi = BooleanExpression.expression(boolExpAfaux, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi))")
                        
                    }
                    let boolExpBfaux = BooleanExpression.expression(boolExpA, .or, boolExpC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi = BooleanExpression.expression(boolExpBfaux, .or, grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi))")
                        
                    }
                    let boolExpCfaux = BooleanExpression.expression(boolExpA, .or, boolExpB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi = BooleanExpression.expression(boolExpCfaux, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi))")
                        
                    }
                case tour.joueursRepondant[0], tour.joueursRepondant[1]:
                    // pour les joueurs qui ont montré leur carte, relier les 3 éléments suspectés : A+B+C=1
                    //i.e. : A vaut 1 si B et C valent 0
                    let boolExpAvrai = BooleanExpression.expression(nonB, .and, nonC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].unSi = BooleanExpression.expression(boolExpAvrai, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].unSi))")
                        
                    }
                    let boolExpBvrai = BooleanExpression.expression(nonA, .and, nonC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].unSi = BooleanExpression.expression(boolExpBvrai, .or, grilleUser[i].cartes[1][tour.armeSuspectee].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].unSi))")
                        
                    }
                    let boolExpCvrai = BooleanExpression.expression(nonA, .and, nonB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].unSi = BooleanExpression.expression(boolExpCvrai, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].unSi))")
                    }
                default:
                    // pour les autres joueurs, ils n'ont aucune de ces 3 cartes
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 2 (deux cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[0][tour.personnageSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 2 (deux cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[1][tour.armeSuspectee].valeur)")
                    } else {
                        grilleUser[i].cartes[1][tour.armeSuspectee].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 2 (deux cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[2][tour.lieuSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                    }
                }
            }
            break
        case 3:
            // Trois cartes ont été montrées
            // pour chaque objet suspecté, mettre les autres joueurs que les 3 joueurs montrant leur carte à zéro
            // TODO: vérifier qu'on n'a pas écrasé des 1 déjà connus. Si c'est le cas, quelqu'un a menti !
            for i in 0..<nb_joueurs + 1 { // pour chacun des joueurs (y compris le coupable à l'index 0)
                let boolExpA = BooleanExpression.pointeur(i, 0, tour.personnageSuspecte)
                let boolExpB = BooleanExpression.pointeur(i, 1, tour.armeSuspectee)
                let boolExpC = BooleanExpression.pointeur(i, 2, tour.lieuSuspecte)
                let nonA = BooleanExpression.notExpression(boolExpA)
                let nonB = BooleanExpression.notExpression(boolExpB)
                let nonC = BooleanExpression.notExpression(boolExpC)
                switch i {
                case tour.joueursRepondant[0], tour.joueursRepondant[1], tour.joueursRepondant[2]:
                    // pour les joueurs qui ont montré leur carte, on peut tirer deux relations :
                    
                    // Première relation : A2=0 si B2=1 ou C2=1
                    
                    let boolExpAfaux = BooleanExpression.expression(boolExpB, .or, boolExpC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi = BooleanExpression.expression(boolExpAfaux, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].zeroSi))")
                    }
                    let boolExpBfaux = BooleanExpression.expression(boolExpA, .or, boolExpC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi = BooleanExpression.expression(boolExpBfaux, .or, grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].zeroSi))")
                    }
                    let boolExpCfaux = BooleanExpression.expression(boolExpA, .or, boolExpB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi = BooleanExpression.expression(boolExpCfaux, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).zeroSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].zeroSi))")
                    }
                    
                    // Deuxième relation : A1=1 si A2=0 et A3=0
                    let index = tour.joueursRepondant.firstIndex(of: i) ?? -1
                    let JR2 = (index + 1) % 3 //donne le 2e joueur ayant montré sa carte autre que i
                    let JR3 = (index + 2) % 3 //donne le 3e joueur ayant montré sa carte autre que i
                    
                    let boolExpA2 = BooleanExpression.pointeur(tour.joueursRepondant[JR2], 0, tour.personnageSuspecte)
                    let boolExpA3 = BooleanExpression.pointeur(tour.joueursRepondant[JR3], 0, tour.personnageSuspecte)
                    let boolExpB2 = BooleanExpression.pointeur(tour.joueursRepondant[JR2], 1, tour.armeSuspectee)
                    let boolExpB3 = BooleanExpression.pointeur(tour.joueursRepondant[JR3], 1, tour.armeSuspectee)
                    let boolExpC2 = BooleanExpression.pointeur(tour.joueursRepondant[JR2], 2, tour.lieuSuspecte)
                    let boolExpC3 = BooleanExpression.pointeur(tour.joueursRepondant[JR3], 2, tour.lieuSuspecte)
                    let nonA2 = BooleanExpression.notExpression(boolExpA2)
                    let nonA3 = BooleanExpression.notExpression(boolExpA3)
                    let nonB2 = BooleanExpression.notExpression(boolExpB2)
                    let nonB3 = BooleanExpression.notExpression(boolExpB3)
                    let nonC2 = BooleanExpression.notExpression(boolExpC2)
                    let nonC3 = BooleanExpression.notExpression(boolExpC3)
                    
                    let boolExpAvrai = BooleanExpression.expression(nonA2, .and, nonA3)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].unSi = BooleanExpression.expression(boolExpAvrai, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].unSi))")
                        
                        
                    }
                    let boolExpBvrai = BooleanExpression.expression(nonB2, .and, nonB3)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].unSi = BooleanExpression.expression(boolExpBvrai, .or, grilleUser[i].cartes[1][tour.armeSuspectee].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].unSi))")
                        
                    }
                    let boolExpCvrai = BooleanExpression.expression(nonC2, .and, nonC3)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].unSi = BooleanExpression.expression(boolExpCvrai, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].unSi))")
                    }
                    
                case tour.joueursRepondant[0]:
                    // pour ce joueur qui a montré sa carte, relier les 3 éléments suspectés : A+B+C=1 (en booléen)
                    // i.e. : A=1 si B=0 et C=0
                    
                    let boolExpAvrai = BooleanExpression.expression(nonB, .and, nonC)
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[0][tour.personnageSuspecte].unSi = BooleanExpression.expression(boolExpAvrai, .or, grilleUser[i].cartes[0][tour.personnageSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).S\(tour.personnageSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[0][tour.personnageSuspecte].unSi))")
                        
                    }
                    let boolExpBvrai = BooleanExpression.expression(nonA, .and, nonC)
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[1][tour.armeSuspectee].unSi = BooleanExpression.expression(boolExpBvrai, .or, grilleUser[i].cartes[1][tour.armeSuspectee].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).A\(tour.armeSuspectee).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[1][tour.armeSuspectee].unSi))")
                        
                    }
                    let boolExpCvrai = BooleanExpression.expression(nonA, .and, nonB)
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "?"{ //on vérifie d'abord qu'on ne connait pas déjà la valeur de la carte, pour ne pas l'écraser
                        // on ajoute une condition de mise à zéro de la carte du joueur :
                        grilleUser[i].cartes[2][tour.lieuSuspecte].unSi = BooleanExpression.expression(boolExpCvrai, .or, grilleUser[i].cartes[2][tour.lieuSuspecte].unSi)
                        // Affichage de l'expression booléenne
                        let qui = "J\(i).L\(tour.lieuSuspecte).unSi"
                        print("\(qui) = \(printBoolExp(expression: grilleUser[i].cartes[2][tour.lieuSuspecte].unSi))")
                        
                    }
                    
                    break
                default:
                    // pour les autres joueurs (y compris le joueur actif), ils n'ont aucune de ces 3 cartes
                    if grilleUser[i].cartes[0][tour.personnageSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 3 (trois cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[0][tour.personnageSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[0][tour.personnageSuspecte].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[1][tour.armeSuspectee].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 3 (trois cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[1][tour.armeSuspectee].valeur)")
                    } else {
                        grilleUser[i].cartes[1][tour.armeSuspectee].valeur = "0"
                    }
                    
                    if grilleUser[i].cartes[2][tour.lieuSuspecte].valeur == "1" {
                        print("ERREUR dans gererTour, case 2 (partie Accéléré), case 3 (trois cartes montrées : J\(i).S\(tour.personnageSuspecte) valait \(grilleUser[i].cartes[2][tour.lieuSuspecte].valeur)")
                    } else {
                        grilleUser[i].cartes[2][tour.lieuSuspecte].valeur = "0"
                    }
                }
            }
            break
        default:
            // Le nombre d'éléments dans la table "joueurs" n'est pas dans les cas spécifiés.
            // C'est une erreur impossible en principe
            print("la fonction gereTour a reçu en argument une table joueurs[] avec plus de 3 arguments, ce qui n'est pas possible (pas plus de 3 cartes montrées par suspicion)")
            break
        }
    default:
        print("ERREUR : type de jeu 'typeJeu' inconnu !")
    }
    // puis on recalcule les cartes impactées
    // Appel de la fonction verifier pour chaque joueur
    grilleUser = verifTousLesJoueurs(grid: grilleUser)

    print(printGrilleCSV(grid: grilleUser))
    if partieResolue(grid: grilleUser) && tourResolution < 0 {
        tourResolution = toursDeLaPartie.count
    }

    if tourResolution > 0 {
        print("Partie résolue au tour n°\(tourResolution)")
    }
}
