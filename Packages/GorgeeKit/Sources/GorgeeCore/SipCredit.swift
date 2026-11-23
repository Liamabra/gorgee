/// Combien crédite une gorgée vérifiée, d'après les niveaux du récipient avant et après.
public enum SipCredit {
    /// Contenance × baisse du niveau en quarts. Si aucune baisse n'est visible (lecture imprécise),
    /// le geste vérifié vaut tout de même un quart de verre.
    public static func milliliters(capacity: Int, beforeQuarters: Int, afterQuarters: Int) -> Int {
        let before = min(4, max(0, beforeQuarters))
        let after = min(4, max(0, afterQuarters))
        let drop = before - after
        let quarters = drop > 0 ? drop : 1
        return Int((Double(capacity) * Double(quarters) / 4).rounded())
    }
}
