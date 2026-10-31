import SwiftUI

enum Operator: String, Codable {
    case and
    case or

    static func fromString(_ string: String) -> Operator? {
        return Operator(rawValue: string)
    }

    func toString() -> String {
        return self.rawValue
    }
}

indirect enum BooleanExpression: Codable {
    case operand(String)
    case pointeur(Int, Int, Int)
    case expression(BooleanExpression, Operator, BooleanExpression)
    case notExpression(BooleanExpression)

    private enum CodingKeys: String, CodingKey {
        case operand
        case pointeur
        case expression
        case notExpression
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(String.self, forKey: .operand) {
            self = .operand(value)
            return
        }

        if let indices = try container.decodeIfPresent([Int].self, forKey: .pointeur),
           indices.count == 3 {
            self = .pointeur(indices[0], indices[1], indices[2])
            return
        }

        if let values = try container.decodeIfPresent(
            [BooleanExpression].self,
            forKey: .expression
        ),
           values.count == 3,
           case .operand(let operatorName) = values[1],
           let boolOperator = Operator(rawValue: operatorName) {
            self = .expression(values[0], boolOperator, values[2])
            return
        }

        if let value = try container.decodeIfPresent(
            BooleanExpression.self,
            forKey: .notExpression
        ) {
            self = .notExpression(value)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expression booléenne inconnue."
            )
        )
    }
}

extension BooleanExpression {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .operand(let operandValue):
            try container.encode(operandValue, forKey: .operand)

        case .pointeur(let i, let j, let k):
            try container.encode([i, j, k], forKey: .pointeur)

        case .expression(let exp1, let op, let exp2):
            try container.encode([exp1, .operand(op.toString()), exp2], forKey: .expression)

        case .notExpression(let notExp):
            try container.encode(notExp, forKey: .notExpression)
        }
    }
}

func printBoolExp(expression: BooleanExpression) -> String {
    switch expression {
    case .pointeur(let joueur, let element, let carte):
        let value = grilleUser[joueur].cartes[element][carte].valeur
        //let typeName: String
        let typeShortName: String
        switch element {
        case 0:
//            typeName = "Suspects"
            typeShortName = "S"
        case 1:
//            typeName = "Armes"
            typeShortName = "A"
        case 2:
//            typeName = "Lieux"
            typeShortName = "L"
        default:
//            typeName = "Inconnu"
            typeShortName = "?"
        }
        return "J\(joueur).\(typeShortName)\(carte)[\(value)]"

    case .operand(let value):
        return value
    case .expression(let left, let op, let right):
        let leftStr = printBoolExp(expression: left)
        let rightStr = printBoolExp(expression: right)

        // Convertir l'opérateur en chaîne
        let opStr: String
        switch op {
        case .and:
            opStr = "*"
        case .or:
            opStr = "+"
        }

        return "(\(leftStr) \(opStr) \(rightStr))"
    case .notExpression(let subExpression):
        let subExpStr = printBoolExp(expression: subExpression)
        return "!\(subExpStr)"
    }
}

// Exemple d'utilisation
//let exampleExp: BooleanExpression = .expression(.pointeur(joueur: 1, element: 0, carte: 3, value: "?"), .and, .pointeur(joueur: 3, element: 1, carte: 4, value: "0"))
//print(printBoolExp(expression: exampleExp))


func evaluate(expression: BooleanExpression, in grid: [DataJoueur]) -> String {
    switch expression {
    case .pointeur(let joueur, let element, let carte):
        guard grid.indices.contains(joueur),
              grid[joueur].cartes.indices.contains(element),
              grid[joueur].cartes[element].indices.contains(carte)
        else {
            return "?"
        }
        return grid[joueur].cartes[element][carte].valeur

    case .operand(let value):
        return value

    case .expression(let left, let op, let right):
        let leftValue = evaluate(expression: left, in: grid)
        let rightValue = evaluate(expression: right, in: grid)

        switch op {
        case .and:
            if leftValue == "0" || rightValue == "0" {
                return "0"
            }
            return leftValue == "?" || rightValue == "?" ? "?" : "1"

        case .or:
            if leftValue == "1" || rightValue == "1" {
                return "1"
            }
            return leftValue == "?" || rightValue == "?" ? "?" : "0"
        }

    case .notExpression(let subExpression):
        switch evaluate(expression: subExpression, in: grid) {
        case "0": return "1"
        case "1": return "0"
        default: return "?"
        }
    }
}

func evaluate(expression: BooleanExpression) -> String {
    evaluate(expression: expression, in: grilleUser)
}
