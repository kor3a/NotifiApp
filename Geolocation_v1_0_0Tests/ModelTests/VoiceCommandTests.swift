//
//  VoiceCommandTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class VoiceCommandTests: XCTestCase {

    // MARK: - Fixtures

    private func reminder(
        id: String,
        title: String,
        isDone: Bool = false,
        quantity: Int? = nil,
        isOutOfStock: Bool? = nil
    ) -> Reminder {
        Reminder(
            id: id,
            userStoreId: "us1",
            title: title,
            isDone: isDone,
            createdAt: 1_700_000_000,
            quantity: quantity,
            isOutOfStock: isOutOfStock
        )
    }

    private func decodePlan(_ json: String) throws -> VoiceCommandPlan {
        try JSONDecoder().decode(VoiceCommandPlan.self, from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testDecode_fullPlan() throws {
        let plan = try decodePlan("""
        {
          "confirmation": "I'll add milk and check off bread.",
          "actions": [
            { "type": "add", "title": "Milk", "quantity": 2 },
            { "type": "check", "id": "r1", "title": "Bread" }
          ],
          "notes": ["I couldn't find batteries."]
        }
        """)

        XCTAssertEqual(plan.confirmation, "I'll add milk and check off bread.")
        XCTAssertEqual(plan.actions.count, 2)
        XCTAssertEqual(plan.actions[0].kind, .add)
        XCTAssertEqual(plan.actions[0].title, "Milk")
        XCTAssertEqual(plan.actions[0].quantity, 2)
        XCTAssertEqual(plan.actions[1].kind, .check)
        XCTAssertEqual(plan.actions[1].reminderId, "r1")
        XCTAssertEqual(plan.notes, ["I couldn't find batteries."])
    }

    /// An action type outside the supported set must cost only that action —
    /// the surrounding plan still has to survive.
    func testDecode_skipsUnsupportedActionAndKeepsRest() throws {
        let plan = try decodePlan("""
        {
          "confirmation": "Sure.",
          "actions": [
            { "type": "add", "title": "Milk" },
            { "type": "sendEmail", "to": "someone@example.com" },
            { "type": "delete", "id": "r2", "title": "Soap" }
          ]
        }
        """)

        XCTAssertEqual(plan.actions.count, 2)
        XCTAssertEqual(plan.actions.map(\.kind), [.add, .delete])
    }

    func testDecode_missingOptionalFieldsDefaultsSafely() throws {
        let plan = try decodePlan("""
        { "actions": [ { "type": "add", "title": "Eggs" } ] }
        """)

        XCTAssertEqual(plan.confirmation, "")
        XCTAssertTrue(plan.notes.isEmpty)
        XCTAssertNil(plan.actions[0].quantity)
        XCTAssertNil(plan.actions[0].reminderId)
    }

    func testDecode_quantityAsString() throws {
        let plan = try decodePlan("""
        { "actions": [ { "type": "setQuantity", "id": "r1", "title": "Milk", "quantity": "3" } ] }
        """)

        XCTAssertEqual(plan.actions[0].quantity, 3)
    }

    // MARK: - Normalization

    func testNormalize_stripsPunctuationAndCase() {
        XCTAssertEqual(VoiceCommandPlanner.normalize("  Eggs,  Large! "), "eggs large")
        XCTAssertEqual(VoiceCommandPlanner.normalize("Ben & Jerry's"), "ben jerry s")
    }

    func testSingularized_onlyTrimsSafePlurals() {
        XCTAssertEqual(VoiceCommandPlanner.singularized("eggs"), "egg")
        XCTAssertEqual(VoiceCommandPlanner.singularized("boxes"), "box")
        // Too short to trim safely, and "-ss" words must stay intact.
        XCTAssertEqual(VoiceCommandPlanner.singularized("gas"), "gas")
        XCTAssertEqual(VoiceCommandPlanner.singularized("glass"), "glass")
    }

    // MARK: - Adds

    func testResolve_addKeepsNewItem() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .add, title: "Milk", quantity: 3)
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [])

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].title, "Milk")
        XCTAssertEqual(result.actions[0].quantity, 3)
    }

    /// A quantity of one carries no information and would write a redundant
    /// field, so it's dropped.
    func testResolve_addDropsQuantityOfOne() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .add, title: "Milk", quantity: 1)
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [])

        XCTAssertNil(result.actions[0].quantity)
    }

    func testResolve_addSkipsItemAlreadyOnList() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .add, title: "milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["milk is already on this list."])
    }

    func testResolve_addSkipsDuplicateWithinSameRequest() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .add, title: "Milk"),
            VoiceCommandAction(kind: .add, title: "MILK")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [])

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.notes.count, 1)
    }

    // MARK: - Matching existing items

    func testResolve_matchesById() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .check, title: "the bread", reminderId: "r2")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [
            reminder(id: "r1", title: "Milk"),
            reminder(id: "r2", title: "Sourdough Bread")
        ])

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].reminderId, "r2")
        // The stored title replaces the transcription so the confirmation the
        // user reads matches what's on their list.
        XCTAssertEqual(result.actions[0].title, "Sourdough Bread")
    }

    /// The model can return an ID that doesn't exist; the title has to rescue it.
    func testResolve_fallsBackToTitleWhenIdIsWrong() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .delete, title: "Milk", reminderId: "does-not-exist")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "milk")])

        XCTAssertEqual(result.actions.first?.reminderId, "r1")
    }

    func testResolve_matchesAcrossPlural() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .check, title: "eggs")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Egg")])

        XCTAssertEqual(result.actions.first?.reminderId, "r1")
    }

    /// "milk" against both "Whole Milk" and "Oat Milk" is a coin flip, so it
    /// must become a note rather than a guess.
    func testResolve_ambiguousPartialMatchIsRejected() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .delete, title: "milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [
            reminder(id: "r1", title: "Whole Milk"),
            reminder(id: "r2", title: "Oat Milk")
        ])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["milk isn't on this list."])
    }

    func testResolve_unambiguousPartialMatchIsAccepted() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .delete, title: "milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [
            reminder(id: "r1", title: "Whole Milk"),
            reminder(id: "r2", title: "Bread")
        ])

        XCTAssertEqual(result.actions.first?.reminderId, "r1")
    }

    func testResolve_unmatchedItemBecomesNote() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .check, title: "Batteries")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["Batteries isn't on this list."])
    }

    func testResolve_twoActionsCannotTargetSameReminder() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .check, title: "Milk"),
            VoiceCommandAction(kind: .delete, title: "Milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].kind, .check)
    }

    // MARK: - No-op guards

    /// Toggling is the underlying operation, so re-checking an already-checked
    /// item would actually uncheck it. It has to be dropped, not passed through.
    func testResolve_dropsCheckOnAlreadyCheckedItem() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .check, title: "Milk", reminderId: "r1")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [
            reminder(id: "r1", title: "Milk", isDone: true)
        ])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["Milk is already checked off."])
    }

    func testResolve_dropsUncheckOnUncheckedItem() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .uncheck, title: "Milk", reminderId: "r1")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["Milk isn't checked off."])
    }

    func testResolve_dropsOutOfStockWhenAlreadyMarked() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .outOfStock, title: "Milk", reminderId: "r1")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [
            reminder(id: "r1", title: "Milk", isOutOfStock: true)
        ])

        XCTAssertTrue(result.actions.isEmpty)
    }

    func testResolve_setQuantityRequiresAQuantity() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .setQuantity, title: "Milk", reminderId: "r1")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertEqual(result.notes, ["No quantity was given for Milk."])
    }

    func testResolve_renameRequiresADifferentTitle() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .rename, title: "Milk", reminderId: "r1", newTitle: "milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertTrue(result.actions.isEmpty)
    }

    func testResolve_renameKeepsNewTitle() {
        let plan = VoiceCommandPlan(actions: [
            VoiceCommandAction(kind: .rename, title: "Milk", reminderId: "r1", newTitle: "Oat Milk")
        ])

        let result = VoiceCommandPlanner.resolve(plan, against: [reminder(id: "r1", title: "Milk")])

        XCTAssertEqual(result.actions.first?.newTitle, "Oat Milk")
    }

    // MARK: - Safety cap

    func testResolve_capsRunawayPlans() {
        let actions = (0..<40).map { VoiceCommandAction(kind: .add, title: "Item \($0)") }
        let result = VoiceCommandPlanner.resolve(VoiceCommandPlan(actions: actions), against: [])

        XCTAssertEqual(result.actions.count, VoiceCommandPlanner.maxActions)
        XCTAssertTrue(result.notes.contains { $0.contains("Only the first") })
    }

    // MARK: - Summaries

    func testSummary_readsNaturally() {
        XCTAssertEqual(VoiceCommandAction(kind: .add, title: "Milk").summary, "Add Milk")
        XCTAssertEqual(VoiceCommandAction(kind: .add, title: "Milk", quantity: 3).summary, "Add 3 × Milk")
        XCTAssertEqual(VoiceCommandAction(kind: .check, title: "Bread").summary, "Check off Bread")
        XCTAssertEqual(VoiceCommandAction(kind: .delete, title: "Soap").summary, "Delete Soap")
        XCTAssertEqual(
            VoiceCommandAction(kind: .rename, title: "Milk", newTitle: "Oat Milk").summary,
            "Rename Milk to Oat Milk"
        )
    }

    func testDeleteIsTheOnlyDestructiveAction() {
        for kind in VoiceCommandActionKind.allCases {
            let action = VoiceCommandAction(kind: kind, title: "Item")
            XCTAssertEqual(action.isDestructive, kind == .delete, "\(kind)")
        }
    }
}
