//
//  impressions.swift
//  CluedoSolver_v2
//
//  Created by Jonathan Lafarge on 12/11/2023.
//

import Foundation

func printTour(tour: Tour) { // imprime les données du tour
    print("J\(tour.joueurDuTour), S\(tour.personnageSuspecte), A\(tour.armeSuspectee), L\(tour.lieuSuspecte), JRépondant : \(tour.joueursRepondant)")
}

func printGrilleCSV(grid: [DataJoueur]) -> String {
    let grilleP = grid
    var result = ""
    //Fonction pour obtenir une ligne horizontale pour séparer les lignes du tableau
    func horizontalLine(_ width: Int) -> String {
        return String(repeating: "-", count: width)
    }
    
    result += horizontalLine(50)
    result += "\n"
    
    // En-têtes de colonnes pour chaque joueur
    result += ";"
    for joueurIndex in 0..<grilleP.count {
        //        result += "J\(joueurIndex): \(grille[joueurIndex].nom)\t"
        result += "J\(joueurIndex);"
    }
    result += "\n"
    
    // Boucle pour les trois types de cartes (suspects, armes, lieux)
    for typeIndex in 0..<vCartes.count {
        let typeName: String
        let typeShortName: String
        
        switch typeIndex {
        case 0:
            typeName = "Suspects"
            typeShortName = "S"
        case 1:
            typeName = "Armes"
            typeShortName = "A"
        case 2:
            typeName = "Lieux"
            typeShortName = "L"
        default:
            typeName = "Inconnu"
            typeShortName = "?"
        }
        
        result += "\(typeName):\n"
        
        // Boucle pour chaque carte de ce type
        for carteIndex in 0..<vCartes[typeIndex].count {
            //let carte = vCartes[typeIndex][carteIndex]
            
            result += "\(typeShortName)\(carteIndex);"
            
            // Boucle pour chaque joueur
            for joueurIndex in 0..<grilleP.count {
                let joueur = grilleP[joueurIndex]
                result += "\(joueur.cartes[typeIndex][carteIndex].valeur);"
            }
            
            result += "\n"
        }
        
    }
    
    // Informations supplémentaires
    result += "crd;"
    for joueurIndex in 0..<grilleP.count {
        result += "\(String(grilleP[joueurIndex].nb_cartes));"
    }
    result += "\n"
    
    result += "#1;"
    for joueurIndex in 0..<grilleP.count {
        result += "\(String(grilleP[joueurIndex].nb_cartes_1));"
    }
    result += "\n"
    
    result += "#0;"
    for joueurIndex in 0..<grilleP.count {
        result += "\(String(grilleP[joueurIndex].nb_cartes_0));"
    }
    result += "\n"
    
    result += "#?;"
    for joueurIndex in 0..<grilleP.count {
        result += "\(String(grilleP[joueurIndex].nb_cartes_inconnues));"
    }
    result += "\n"
    return result
}


func printGrille(grid: [DataJoueur]) -> String {
    let grillep = grid
    var result = ""
    //Fonction pour obtenir une ligne horizontale pour séparer les lignes du tableau
    func horizontalLine(_ width: Int) -> String {
        return String(repeating: "-", count: width)
    }
    
    // Fonction pour obtenir une cellule formatée
    func formattedCell(_ value: String) -> String {
        let paddingCount = 3 - value.count
        let padding = String(repeating: " ", count: max(0, paddingCount))
        return "| \(value + padding) "
    }
    
    result += horizontalLine(50)
    result += "\n"
    
    // En-têtes de colonnes pour chaque joueur
    result += "      |"
    for joueurIndex in 0..<grillep.count {
        //        result += "J\(joueurIndex): \(grille[joueurIndex].nom)\t"
        result += " J\(joueurIndex)  |"
    }
    result += "\n"
    
    // Boucle pour les trois types de cartes (suspects, armes, lieux)
    for typeIndex in 0..<vCartes.count {
        let typeName: String
        let typeShortName: String
        
        switch typeIndex {
        case 0:
            typeName = "Suspects"
            typeShortName = "S"
        case 1:
            typeName = "Armes"
            typeShortName = "A"
        case 2:
            typeName = "Lieux"
            typeShortName = "L"
        default:
            typeName = "Inconnu"
            typeShortName = "?"
        }
        
        result += "\(typeName):\n"
        
        // Boucle pour chaque carte de ce type
        for carteIndex in 0..<vCartes[typeIndex].count {
            //let carte = vCartes[typeIndex][carteIndex]
            
            result += "| \(typeShortName) \(carteIndex) "
            
            // Boucle pour chaque joueur
            for joueurIndex in 0..<grillep.count {
                let joueur = grillep[joueurIndex]
                result += formattedCell(joueur.cartes[typeIndex][carteIndex].valeur)
            }
            
            result += "|\n"
        }
        
    }
    
    // Informations supplémentaires
    result += "Nombre de cartes:\n"
    result += "      "
    for joueurIndex in 0..<grillep.count {
        result += formattedCell(String(grillep[joueurIndex].nb_cartes))
    }
    result += "|\n"
    
    result += "Nombre de cartes détenues:\n"
    result += "      "
    for joueurIndex in 0..<grillep.count {
        result += formattedCell(String(grillep[joueurIndex].nb_cartes_1))
    }
    result += "|\n"
    
    result += "Nombre de cartes non détenues:\n"
    result += "      "
    for joueurIndex in 0..<grillep.count {
        result += formattedCell(String(grillep[joueurIndex].nb_cartes_0))
    }
    result += "|\n"
    
    result += "Nombre de cartes inconnues:\n"
    result += "      "
    for joueurIndex in 0..<grillep.count {
        result += formattedCell(String(grillep[joueurIndex].nb_cartes_inconnues))
    }
    result += "|\n"
    return result
}

func printGrilleToFile(grid: [DataJoueur]) {
    
    let partie = genererPartie(grid: grid)
    
    let grilleCSVStart = printGrilleCSV(grid: grilleUser)
    print("/////    GRILLE DE DEPART    /////")
    print(grilleCSVStart)
    
    var tourResolution = 0
    var t = 0
    for i in 0..<partie.count {
        print("/////   TOUR \(i)   /////")
        gererTour(tour: partie[i])
        // Appeler cette fonction après chaque tour
        verifierCoherence(grid: grilleUser, grilleSol: grilleSolution)
        // let grilleTXT = printGrille(grille: grille)
        let grilleCSV = printGrilleCSV(grid: grilleUser)
        
        //print(grilleTXT)
        print(grilleCSV)
        if partieResolue(grid: grilleUser) && tourResolution == 0 {
           tourResolution = i
        }
        
        //        // Écrivez le contenu dans un fichier texte
        //        do {
        //            try result.write(toFile: "grille_tour_\(i).txt", atomically: true, encoding: .utf8)
        //        } catch {
        //            print("Erreur lors de l'écriture du fichier grille.txt : \(error)")
        //        }
        //        print(result)
        if tourResolution > 0 {
            print("Partie résolue au tour n°\(tourResolution)")
        }
        t += 1
    }
    print("fin de la partie - tour \(t)")
}
