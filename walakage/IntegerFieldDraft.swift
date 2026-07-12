struct IntegerFieldDraft: Equatable {
    private(set) var text: String
    private(set) var committedValue: Int
    private(set) var isDirty = false

    init(value: Int) {
        text = String(value)
        committedValue = value
    }

    var parsedValue: Int? { Int(text) }

    mutating func edit(_ text: String) {
        self.text = text
        isDirty = true
    }

    mutating func commit(_ value: Int) {
        text = String(value)
        committedValue = value
        isDirty = false
    }

    mutating func discardEdits() {
        text = String(committedValue)
        isDirty = false
    }
}
