import Testing
@testable import walakage

@MainActor
struct IntegerFieldDraftTests {
    @Test func typingChangesOnlyTheDraftUntilCommit() {
        var draft = IntegerFieldDraft(value: 20)

        draft.edit("75")

        #expect(draft.text == "75")
        #expect(draft.parsedValue == 75)
        #expect(draft.committedValue == 20)
        #expect(draft.isDirty)

        draft.commit(75)

        #expect(draft.committedValue == 75)
        #expect(!draft.isDirty)
    }

    @Test func discardingAQuicklyReplacedDraftRestoresCommittedText() {
        var draft = IntegerFieldDraft(value: 15)
        draft.edit("99")

        draft.discardEdits()

        #expect(draft.text == "15")
        #expect(draft.committedValue == 15)
        #expect(!draft.isDirty)
    }
}
