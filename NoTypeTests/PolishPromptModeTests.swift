import Foundation
import Testing
@testable import NoType

@Suite("PolishPromptModes")
struct PolishPromptModeTests {

    @Test func modeInstructionBecomesSystemMessage() {
        let messages = PolishPrompt.messages(for: "hello",
                                             dictionaryHint: "",
                                             systemInstruction: "Translate to English.",
                                             outputLanguage: nil)
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[0]["content"] == "Translate to English.")
        #expect(messages[1]["role"] == "user")
        #expect(messages[1]["content"] == "hello")
    }

    @Test func outputLanguageIsFoldedIntoSystemMessage() {
        let messages = PolishPrompt.messages(for: "你好",
                                             dictionaryHint: "",
                                             systemInstruction: "Translate.",
                                             outputLanguage: "English")
        #expect(messages[0]["content"] == "Translate.\nOutput language: English")
    }

    @Test func dictionaryHintAppendedToSystemMessage() {
        let messages = PolishPrompt.messages(for: "hi",
                                             dictionaryHint: "Preferred terms:\n- \"foo\"",
                                             systemInstruction: "Polish.",
                                             outputLanguage: nil)
        #expect(messages[0]["content"] == "Polish.\n\nPreferred terms:\n- \"foo\"")
    }

    @Test func emptyInstructionProducesUserOnlyMessage() {
        let messages = PolishPrompt.messages(for: "raw text",
                                             dictionaryHint: "hint",
                                             systemInstruction: "   ",
                                             outputLanguage: "English")
        // No system message at all — caller skips the LLM.
        #expect(messages.count == 1)
        #expect(messages[0]["role"] == "user")
    }

    @Test func everydayInstructionEqualsV2SystemPrompt() {
        // Guarantees SC-005: the built-in everyday mode reproduces V2 exactly.
        #expect(PolishPrompt.systemPrompt == PolishingMode.everydayInstruction)
        #expect(PolishPrompt.systemPrompt.contains("filler words"))
    }

    @Test func defaultEverydayMessagesMatchV2Shape() {
        let v2 = PolishPrompt.messages(for: "hello", dictionaryHint: "")
        let mode = PolishPrompt.messages(for: "hello",
                                         dictionaryHint: "",
                                         systemInstruction: PolishingMode.everydayInstruction,
                                         outputLanguage: nil)
        #expect(v2 == mode)
    }

    @Test func composeSystemMessageTrimsAndCombines() {
        let content = PolishPrompt.composeSystemMessage(instruction: "  Be brief.  ",
                                                        outputLanguage: "French",
                                                        dictionaryHint: "hint")
        #expect(content == "Be brief.\nOutput language: French\n\nhint")
    }

    @Test func composeSystemMessageEmptyForBlankInstruction() {
        #expect(PolishPrompt.composeSystemMessage(instruction: "  ",
                                                  outputLanguage: "English",
                                                  dictionaryHint: "hint").isEmpty)
    }
}
