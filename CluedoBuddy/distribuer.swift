//
//  distribuer.swift
//  CluedoSolver_v2
//
//  Created by Jonathan Lafarge on 12/11/2023.
//

import Foundation


// la fonction 'distribuer()' prépare une nouvelle partie, en mélangeant d'abord les cartes de chaque catégorie, en distribuant une carte de chaque catégorie au Coupable, puis en mélangeant toutes les cartes restantes pour les distribuer aux joueurs. Les nombres de cartes des joueurs sont également mis à jour en conséquence.


func paquet() -> [[(Int, Int)]] {
    var paquet: [[(Int, Int)]] = []
    
    // Pour les suspects
    let suspects = (0..<nb_suspects).map { (0, $0) }
    paquet.append(suspects)
    
    // Pour les armes
    let armes = (0..<nb_armes).map { (1, $0) }
    paquet.append(armes)
    
    // Pour les lieux
    let lieux = (0..<nb_lieux).map { (2, $0) }
    paquet.append(lieux)
    
    return paquet
}


// Fonction pour distribuer les cartes
func distribuer(grid: [DataJoueur]) -> [DataJoueur] {
    // Étape 1: Initialiser la grille
    //initNomCartes()
    //initNomJoueurs()
    var grilleDistrib = grid
    for J in 0..<grilleDistrib.count {
        grilleDistrib[J].nb_cartes = 0
    }
    grilleSolution = grilleDistrib

    // Étape 2: Créer le paquet avec la fonction paquet()
    var paquet = paquet()

    // Étape 3: Distribuer les cartes au Coupable
    for typeIndex in 0..<paquet.count {
        // Choix aléatoire d'une carte pour chaque catégorie
        let randomIndex = Int.random(in: 0..<paquet[typeIndex].count)
        let (element, numero) = paquet[typeIndex][randomIndex]

        // Distribuer la carte au Coupable (joueur 0)
        grilleSolution[0].cartes[element][numero].valeur = "1"
        grilleSolution[0].nb_cartes += 1

        // Retirer la carte du paquet
        paquet[typeIndex].remove(at: randomIndex)
    }

    // Étape 4: Distribuer les cartes restantes aux joueurs
        var joueurIndex = 1
        var cartesRestantes: [(element: Int, numero: Int)] = []
        
        for typeIndex in 0..<paquet.count {
            cartesRestantes += paquet[typeIndex]
        }

        while !cartesRestantes.isEmpty {
            // Choix aléatoire d'une carte parmi les cartes restantes
            let randomIndex = Int.random(in: 0..<cartesRestantes.count)
            let (element, numero) = cartesRestantes[randomIndex]

            // Distribuer la carte au joueur
            grilleSolution[joueurIndex].cartes[element][numero].valeur = "1"
            grilleSolution[joueurIndex].nb_cartes += 1

            // Retirer la carte du paquet
            cartesRestantes.remove(at: randomIndex)

            // Mettre à jour le joueur suivant sans repasser par zéro
            joueurIndex = joueurIndex == grilleDistrib.count - 1 ? 1 : joueurIndex + 1
        }
    // ensuite, le joueur 1 connaît ses cartes. On récupère les infos de la solution pour ce joueur :
    grilleDistrib[1] = grilleSolution[1]
    
    // on récupère aussi le nombre de cartes de chaque joueur dans la grille de jeu :
    for J in 0..<grilleSolution.count {
        grilleDistrib[J].nb_cartes = grilleSolution[J].nb_cartes
    }
    

    grilleDistrib = verifTousLesJoueurs(grid: grilleDistrib)

    grilleSolution = verifTousLesJoueurs(grid: grilleSolution)
//    print("grilleSolution après verif :")
//    print(printGrilleCSV(grid: grilleSolution))
    print("grilleSolution après func distribuer()")
    print(printGrilleCSV(grid: grilleSolution))
    return grilleDistrib
}
