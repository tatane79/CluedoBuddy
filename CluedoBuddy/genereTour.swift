//
//  genereTour.swift
//  CluedoSolver_v2
//
//  Created by Jonathan Lafarge on 12/11/2023.
//

import Foundation


func genererSuspicion(joueurActif: Int) -> (Int, Int, Int) {
    guard joueurActif >= 1, joueurActif < grilleSolution.count else {
        // Vérifier si le joueur actif est valide (doit être entre 1 et le nombre total de joueurs inclus)
        print("Joueur actif invalide.")
        return (-1, -1, -1)
    }

    // Générer aléatoirement des indices pour le personnage, l'arme et le lieu
    let personnageSuspecte = Int.random(in: 0..<nb_suspects)
    let armeSuspectee = Int.random(in: 0..<nb_armes)
    let lieuSuspecte = Int.random(in: 0..<nb_lieux)

    return (personnageSuspecte, armeSuspectee, lieuSuspecte)
}

extension Array {
    func circularShift(amount: Int) -> Array {
        let shiftAmount = amount % count
        return Array(self[shiftAmount..<count] + self[0..<shiftAmount])
    }
}

func joueursRepondant(jActif: Int, suspicion: (Int, Int, Int)) -> [Int] {
    var joueursRepondent: [Int] = []
    
    // Créer l'ordre des joueurs à partir de joueurActif
    // sans le joueur 0 (le coupable) ni le joueurActif
    let ordreJoueurs = Array(grilleSolution.indices)
        .filter { $0 != 0 && $0 != jActif }
        .circularShift(amount: jActif - 1)

//TODO: vérifier que les suspicions sont bien dans le range des numéro d'objets
    
    // on parcourt les joueurs dans l'ordre :
    for joueurIndex in ordreJoueurs {

            // Vérifier si le joueur possède au moins l'une des cartes suspectées
            let possedeCarte = grilleSolution[joueurIndex].cartes[0][suspicion.0].valeur == "1" ||
                               grilleSolution[joueurIndex].cartes[1][suspicion.1].valeur == "1" ||
                               grilleSolution[joueurIndex].cartes[2][suspicion.2].valeur == "1"
            
            if possedeCarte {
                joueursRepondent.append(joueurIndex)
            }
        
    }

    return joueursRepondent
}

//func joueursRepondant(jActif: Int, suspicion: (Int, Int, Int)) -> Int {
//    let joueurActif = jActif
//    var aTrouveJoueurRepondant = false
//    
//    // Recherche des joueurs dans l'ordre à partir du joueur actif, en excluant le joueur 0
//    for offset in 1..<grilleSolution.count {
//        let joueurIndex = (joueurActif + offset) % grilleSolution.count // Calcul de l'index en bouclant dans l'ordre des joueurs
//        
//        if joueurIndex != joueurActif && joueurIndex != 0 && !aTrouveJoueurRepondant {
//            // Vérifier si le joueur possède au moins l'une des cartes suspectées
//            let possedeCarte = grilleSolution[joueurIndex].cartes[0][suspicion.0].valeur == "1" ||
//                               grilleSolution[joueurIndex].cartes[1][suspicion.1].valeur == "1" ||
//                               grilleSolution[joueurIndex].cartes[2][suspicion.2].valeur == "1"
//
//            if possedeCarte {
//                aTrouveJoueurRepondant = true
//                return joueurIndex
//            }
//        }
//    }
//
//    return -1
//}


// la fonction joueursRepondant suivante était la 1ère version, qui ne suit pas les règles officielles : tous les joueurs ayant une carte doivent la montrer
//func joueursRepondant(jActif: Int, suspicion: (Int, Int, Int)) -> [Int] {
//    var joueursRepondent: [Int] = []
//    let joueurActif = jActif
//    for joueurIndex in 1..<grilleSolution.count {
//        if joueurIndex != joueurActif { // il ne faut pas que le joueur actif réponde
//            // Vérifier si le joueur possède au moins l'une des cartes suspectées
//            let possedeCarte = grilleSolution[joueurIndex].cartes[0][suspicion.0].valeur == "1" ||
//            grilleSolution[joueurIndex].cartes[1][suspicion.1].valeur == "1" ||
//            grilleSolution[joueurIndex].cartes[2][suspicion.2].valeur == "1"
//            
//            if possedeCarte {
//                joueursRepondent.append(joueurIndex)
//            }
//        }
//    }
//
//    return joueursRepondent
//}

// Exemple d'utilisation avec une suspicion générée aléatoirement
//let joueurActif = 1
//let suspicion = genererSuspicion(joueurActif: joueurActif)
//let joueursRepondent = joueursRepondant(suspicion: suspicion)
//
//print("Suspicion générée par J\(joueurActif): Personnage \(suspicion.0), Arme \(suspicion.1), Lieu \(suspicion.2)")
//print("Joueurs répondant: \(joueursRepondent)")

func genererPartie(grid: [DataJoueur]) -> [Tour] {
    // Initialisation de la grille
    //initNomCartes()
    //initNomJoueurs()

    // Mélanger et distribuer les cartes
    grilleUser = distribuer(grid: grid)
    print("Grille solution:")
    print(printGrilleCSV(grid: grilleSolution))
    //sauvegarderGrille(grilleToSave: grilleSolution)
    
    // Choix aléatoire du premier joueur actif
    var joueurIndex = Int.random(in: 1..<grilleUser.count)
    print("Le joueur \(grilleUser[joueurIndex].nom) (\(joueurIndex)) commence la partie.")

    // Générer les 20 tours
    var tours: [Tour] = []
    for _ in 1...20 {
        
        //let joueurActif = tours.last?.joueurActif ?? joueurIndex
        let suspicion = genererSuspicion(joueurActif: joueurIndex)
        let joueursRep = joueursRepondant(jActif: joueurIndex, suspicion: suspicion)

        // Ajout du tour à la liste
        tours.append(Tour(joueurDuTour: joueurIndex,
                          personnageSuspecte: suspicion.0,
                          armeSuspectee: suspicion.1,
                          lieuSuspecte: suspicion.2,
                          joueursRepondant: joueursRep))
        
        joueurIndex = joueurIndex == grilleUser.count - 1 ? 1 : joueurIndex + 1
    }
    return tours
}

//// Exemple d'utilisation
//let tours = genererPartie()
//
//// Affichage des tours générés
//for (index, tour) in tours.enumerated() {
//    print("Tour \(index + 1):")
//    printTour(tour: tour)
//    print("--------------------")
//}
