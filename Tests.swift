//
//  Tests.swift
//  CluedoBuddy
//
//  Created by Jonathan Lafarge on 28/11/2023.
//

import SwiftUI
import WStack

////struct Grid_Previews: PreviewProvider {
//static var previews: some View {
//    Grid44(rows: ["L1", "L2", "L3", "L4"],
//         columns: ["C1", "C2", "C3", "C4"],
//         selectedColumn: .constant(nil),
//         selectedRow: .constant(nil),
//         selectedCell: .constant(nil))
//        .previewLayout(.sizeThatFits)
//}
//}
struct NewGameView2: View {
    @State private var typeJeuL = 0 // variable locale typeJeuL (locale)
    @State private var grilleJeu = initialiserGrille(noms: ["", "", "", "", "", ""])
    @State private var grilleJeu2 = [DataJoueur]()
    @State private var isNavigationActive = false
    @Binding var joueurActifG: Int
    @State private var isInfoReglesPresented = false
    
    @State private var myNumber: Int?
    
    
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.zeroSymbol  = ""
        return formatter
    }()
    
    let promptJoueurs = ["Votre nom", "Joueur à gauche", "Joueur 3", "Joueur 4", "Joueur 5", "Joueur 6"]
    
    var isNextButtonEnabled: Bool {
        let grilleJeuSansCoupable = grilleJeu.dropFirst()
        let filledPlayersCount = grilleJeuSansCoupable.filter { !$0.nom.isEmpty && $0.nb_cartes > 0 }.count
        let totalCardsCount = grilleJeuSansCoupable.reduce(0) { $0 + $1.nb_cartes }
        
        return filledPlayersCount >= 3 && totalCardsCount == nb_suspects + nb_armes + nb_lieux - 3
    }
    
    var body: some View {
        VStack {
            Text("Choisissez la règle à utiliser :")
            ToggleButtons(selectedIndex: $typeJeuL, buttons: ["Règle\nStandard", "Règle Accéléré"])
                .padding()
            
            HStack {
                Spacer()
                
                Button(action: {
                    // Action à effectuer lors du clic sur le bouton d'information
                    self.isInfoReglesPresented.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 20)
                .sheet(isPresented: $isInfoReglesPresented) {
                    // Contenu de la fenêtre d'information
                    InfoRegles(isSheetPresented: $isInfoReglesPresented)
                }
            }
            Spacer()
            Text("Saisissez le nom des joueurs et leur nombre de cartes en commençant par vous, puis chaque joueur dans le sens horaire : (3 joueurs min)")
            
            List {
                ForEach(grilleJeu.indices.dropFirst(), id: \.self) { joueurIndex in
                    HStack {
                        // TODO: n'afficher qu'une seule ligne de saisie pour ajouter un joueur de plus
                        // TODO: ajouter une croix pour supprimer un joueur
                        TextField("", text: $grilleJeu[joueurIndex].nom, prompt: Text(prompt(for: joueurIndex)))
                            .modifier(TextFieldClearButton(text: $grilleJeu[joueurIndex].nom))
                            .multilineTextAlignment(.leading)
                        //.textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("", value: $grilleJeu[joueurIndex].nb_cartes, formatter: numberFormatter, prompt: Text("nb cartes"))
                        //.textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .modifier(IntTextFieldClearButton(value: $grilleJeu[joueurIndex].nb_cartes))
                            .frame(maxWidth: 100)
                        
                    }
                    
                }
            }
            
            
            //            NavigationLink{
            //                MyCardsView(joueurActifG: $joueurActifG)
            //            } label: {
            //                Text("Resume Game")
            //            }
            //            .buttonStyle(MainNavigationLinkStyle())
            //            .hidden()
            
            NavigationLink(destination: MyCardsView(joueurActifG: $joueurActifG), isActive: $isNavigationActive) {
                EmptyView()
            }
            .hidden()
            
            // proposition de Chat GPT pour lever l'alerte ci-dessus :
            //            NavigationLink(
            //                destination: MyCardsView(),
            //                tag: true, // Utilisez une valeur booléenne qui détermine si la navigation doit être active
            //                selection: $isNavigationActive
            //            ) {
            //                EmptyView()
            //            }
            //            .hidden()
            
            
            
            Button {
                // Mettre à jour la grille avec les joueurs saisis
                let grilleJeuSansCoupable = grilleJeu.dropFirst()
                grilleJeu2 = grilleJeuSansCoupable.filter { !$0.nom.isEmpty && $0.nb_cartes > 0 }
                grilleJeu2 = creerNomCourt(grid: grilleJeu2)
                nb_joueurs = grilleJeu2.count
                typeJeu = typeJeuL // on récupère le choix de règle du joueur dans la variable globale typeJeu
                
                // On réinitialise grilleUser (si jamais l'utilisateur a fait "back" sur cet écran) :
                //grilleUser = initialiserGrille(noms: [])
                // ça n'a pas l'air de fonctionner
                
                // Ajoute les joueurs de grilleJeu à grilleUser
                grilleUser.append(contentsOf: grilleJeu2)
                
                // Afficher la grille dans le terminal
                //grilleUser = distribuer(grid: grilleUser)
                print(printGrilleCSV(grid: grilleUser))
                print("Le type de jeu est : \(typeJeu)")
                // initialiseNomsJoueurs(grid: grilleUser)
                
                // Activer la navigation
                isNavigationActive = true
            }
        label: {
            // Utilisation d'une Text conditionnelle pour définir le label du bouton
            if isNextButtonEnabled {
                Text("Suivant")
            } else
            {
                let grilleJeuSansCoupableL = grilleJeu.dropFirst()
                let filledPlayersCountL = grilleJeuSansCoupableL.filter { !$0.nom.isEmpty && $0.nb_cartes > 0 }.count
                let totalCardsCountL = grilleJeuSansCoupableL.reduce(0) { $0 + $1.nb_cartes }
                let deltaCard = totalCardsCountL - (nb_suspects + nb_armes + nb_lieux - 3)
                
                if deltaCard > 0 {
                    Text("\(deltaCard) cartes en trop")
                } else if deltaCard < 0 {
                    Text("\(-deltaCard) cartes manquantes")
                }
            }
            
        }
            
        .padding()
        .disabled(!isNextButtonEnabled)
            //.buttonStyle(MainNavigationLinkStyle())
            //.foregroundColor(isNextButtonEnabled ? .primary : .gray) // Appliquer une couleur différente lorsque désactivé
            
        }
        .padding()
    }
    private func prompt(for joueurIndex: Int) -> String {
        return promptJoueurs[joueurIndex - 1 % promptJoueurs.count]
    }
    
}
struct testW: View {
    let fruits = [
        "🍎 Red Apple",
        "🍐 Pear",
        "🍊 Tangerine",
        "🍋 Lemon",
        "🍌 Banana",
        "🍉 Watermelon",
        "🍇 Grapes",
        "🍓 Strawberry",
        "🫐 Blueberries",
        "🍈 Melon",
        "🍒 Cherries",
        "🍑 Peach",
        "🥭 Mango",
        "🍍 Pineapple",
        "🥥 Coconut",
        "🥝 Kiwi",
        "🍅 Tomato",
        "🍆 Eggplant",
        "🥑 Avocado",
        "🫛 Pea Pod",
        "🥦 Broccoli",
        "🥬 Leafy Greens",
        "🥒 Cucumber",
        "🌶️ Hot Pepper",
        "🫑 Bell Pepper",
        "🌽 Ear of Corn",
        "🥕 Carrot",
        "🫒 Olive",
        "🧄 Garlic",
        "🧅 Onion",
        "🥔 Potato",
        "🍠 Roasted Sweet Potato"
    ]

    var body: some View {
        ScrollView {
            HStack(alignment: .center) {
                /*@START_MENU_TOKEN@*/Text("Placeholder")/*@END_MENU_TOKEN@*/
            }
            VStack(alignment: .leading) {
                
                let listElmt: [String] = ["un", "deux", "trois"]
                WStack(listElmt, spacing: 10, lineSpacing: 10) { elmt in
                        Image(systemName:"checkmark.square.fill")
                }
                .padding(.horizontal)
                
            }
            .padding()
        }
    }
}

struct Grid44: View {
    let rows: [String]
    let columns: [String]
    @Binding var selectedColumn: Int?
    @Binding var selectedRow: Int?
    @Binding var selectedCell: (Int, Int)

    var body: some View {
        VStack {
            HStack {
                // Empty corner cell
                Text(" ")
                    .frame(width: 50, height: 30)

                // Column headers
                ForEach(columns.indices, id: \.self) { column in
                    Text(columns[column])
                        .frame(width: 50, height: 30)
                        .background(column == selectedColumn ? Color.yellow.opacity(0.5) : Color.clear)
                        .onTapGesture {
                            selectedColumn = column
                            selectedRow = nil
                            selectedCell = (-1,-1)
                        }
                }
            }

            // Grid content
            ForEach(rows.indices, id: \.self) { row in
                HStack {
                    // Row header
                    Text(rows[row])
                        .frame(width: 50, height: 30)
                        .background(row == selectedRow ? Color.yellow.opacity(0.5) : Color.clear)
                        .onTapGesture {
                            selectedRow = row
                            selectedColumn = nil
                            selectedCell = (-1,-1)
                        }

                    // Cells
                    ForEach(columns.indices, id: \.self) { column in
                        Text("Cell \(row + 1),\(column + 1)")
                            .frame(width: 50, height: 30)
                            .background((row, column) == selectedCell ? Color.yellow.opacity(0.5) : Color.clear)
                            .onTapGesture {
                                selectedCell = (row, column)
                                selectedRow = nil
                                selectedColumn = nil
                            }
                    }
                }
            }
        }
    }
}

struct testW_Previews: PreviewProvider {
    static var previews: some View {
        testW()
    }
}
