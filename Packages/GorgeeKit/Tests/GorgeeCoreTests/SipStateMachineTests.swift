import Testing
@testable import GorgeeCore

@Suite("Preuve de gorgée")
struct SipStateMachineTests {
    /// Fait défiler des images à 10 par seconde, de `from` à `to` exclus.
    static func frames(_ machine: inout SipStateMachine, from: Double, to: Double, drinking: Bool) {
        var time = from
        while time < to - 1e-9 {
            machine.observe(SipFrame(time: time, drinkingPose: drinking))
            time += 0.1
        }
    }

    /// Une machine déjà passée à l'étape « bois » à t = 1 s.
    static func drinking() -> SipStateMachine {
        var machine = SipStateMachine(startedAt: 0)
        machine.judge(.clearLiquid(fillQuarters: 4), at: 1)
        return machine
    }

    @Test("On commence par montrer son verre")
    func startsByShowingTheContainer() {
        let machine = SipStateMachine(startedAt: 0)
        #expect(machine.step == .showContainer)
        #expect(machine.wantsJudgement)
    }

    @Test("Un liquide transparent fait passer à l'étape « bois »")
    func clearLiquidAdvances() {
        let machine = Self.drinking()
        #expect(machine.step == .drink)
        #expect(!machine.wantsJudgement)
    }

    @Test("Un liquide ou un récipient refusé arrête la preuve", arguments: [
        (ContainerVerdict.coloredLiquid, SipRefusal.coloredLiquid),
        (.opaqueLiquid, .opaqueLiquid),
        (.emptyContainer, .emptyContainer),
        (.opaqueContainer, .opaqueContainer),
    ])
    func rejectedContainerRefuses(verdict: ContainerVerdict, refusal: SipRefusal) {
        var machine = SipStateMachine(startedAt: 0)
        machine.judge(verdict, at: 2)
        #expect(machine.step == .refused(refusal))
    }

    @Test("Sans récipient visible, on attend, puis on refuse après 20 s")
    func noContainerTimesOut() {
        var machine = SipStateMachine(startedAt: 0)
        machine.judge(.noContainer, at: 5)
        #expect(machine.step == .showContainer)
        machine.judge(.noContainer, at: 19.9)
        #expect(machine.step == .showContainer)
        machine.judge(.noContainer, at: 20.1)
        #expect(machine.step == .refused(.noContainer))
    }

    @Test("Verre à la bouche, tête inclinée, pendant 1,5 s : la gorgée est vue")
    func holdingAtMouthCompletesDrink() {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 3.4, drinking: true)
        #expect(machine.step == .drink)
        #expect(machine.drinkProgress > 0.85)
        Self.frames(&machine, from: 3.4, to: 3.7, drinking: true)
        #expect(machine.step == .lower)
    }

    @Test("Un trou bref dans la détection n'annule pas la gorgée")
    func shortGapIsTolerated() {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 2.8, drinking: true)
        Self.frames(&machine, from: 2.8, to: 3.0, drinking: false)
        Self.frames(&machine, from: 3.0, to: 3.8, drinking: true)
        #expect(machine.step == .lower)
    }

    @Test("Une vraie interruption remet le compteur à zéro")
    func longGapResets() {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 3.2, drinking: true)
        Self.frames(&machine, from: 3.2, to: 4.0, drinking: false)
        Self.frames(&machine, from: 4.0, to: 5.0, drinking: true)
        #expect(machine.step == .drink)
        #expect(machine.drinkProgress < 0.7)
    }

    @Test("Pas de gorgée en 30 s : refus")
    func noDrinkTimesOut() {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 31.2, drinking: false)
        #expect(machine.step == .refused(.noDrinkSeen))
    }

    @Test("Verre reposé : on demande de le remontrer")
    func loweringAsksToShowAgain() {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 3.7, drinking: true)
        Self.frames(&machine, from: 3.7, to: 4.3, drinking: false)
        #expect(machine.step == .showContainerAgain)
        #expect(machine.wantsJudgement)
    }

    static func showingAgain() -> SipStateMachine {
        var machine = Self.drinking()
        Self.frames(&machine, from: 2, to: 3.7, drinking: true)
        Self.frames(&machine, from: 3.7, to: 4.3, drinking: false)
        return machine
    }

    @Test("Le verre remontré valide la gorgée avec les niveaux avant et après")
    func showingAgainVerifies() {
        var machine = Self.showingAgain()
        machine.judge(.clearLiquid(fillQuarters: 2), at: 5)
        #expect(machine.step == .verified(beforeQuarters: 4, afterQuarters: 2))
        #expect(machine.isFinished)
    }

    @Test("Un verre vidé d'un trait est une gorgée valide")
    func emptiedGlassVerifies() {
        var machine = Self.showingAgain()
        machine.judge(.emptyContainer, at: 5)
        #expect(machine.step == .verified(beforeQuarters: 4, afterQuarters: 0))
    }

    @Test("Un verre échangé contre un soda est refusé")
    func swappedDrinkRefuses() {
        var machine = Self.showingAgain()
        machine.judge(.coloredLiquid, at: 5)
        #expect(machine.step == .refused(.coloredLiquid))
    }

    @Test("Un verre qui ne réapparaît pas en 15 s est refusé")
    func lostContainerRefuses() {
        var machine = Self.showingAgain()
        machine.judge(.noContainer, at: 10)
        #expect(machine.step == .showContainerAgain)
        machine.judge(.noContainer, at: 19.5)
        #expect(machine.step == .refused(.containerLost))
    }

    @Test("Une fois terminée, la preuve ne bouge plus")
    func finishedIgnoresEvents() {
        var machine = SipStateMachine(startedAt: 0)
        machine.judge(.coloredLiquid, at: 1)
        machine.judge(.clearLiquid(fillQuarters: 4), at: 2)
        Self.frames(&machine, from: 2, to: 5, drinking: true)
        #expect(machine.step == .refused(.coloredLiquid))
    }
}
