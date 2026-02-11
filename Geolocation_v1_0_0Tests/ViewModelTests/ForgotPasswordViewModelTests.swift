//
//  ForgotPasswordViewModelTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Geolocation_v1_0_0

final class ForgotPasswordViewModelTests: XCTestCase {

    private var viewModel: ForgotPasswordViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ForgotPasswordViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - validate() - Valid Input

    func testValidate_validEmail_returnsTrue() {
        viewModel.email = "test@example.com"
        XCTAssertTrue(viewModel.validate())
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    func testValidate_minimalEmail_returnsTrue() {
        viewModel.email = "a@b.c"
        XCTAssertTrue(viewModel.validate())
    }

    // MARK: - validate() - Empty Email

    func testValidate_emptyEmail_returnsFalse() {
        viewModel.email = ""
        XCTAssertFalse(viewModel.validate())
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
    }

    func testValidate_whitespaceOnlyEmail_returnsFalse() {
        viewModel.email = "   "
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_tabsAndNewlines_returnsFalse() {
        viewModel.email = "\t\n"
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Invalid Email Format

    func testValidate_emailMissingAt_returnsFalse() {
        viewModel.email = "testexample.com"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emailMissingDot_returnsFalse() {
        viewModel.email = "test@examplecom"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emailMissingBoth_returnsFalse() {
        viewModel.email = "testexamplecom"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_justAtSign_returnsFalse() {
        viewModel.email = "@"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_justDot_returnsFalse() {
        viewModel.email = "."
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - Error Messages

    func testValidate_emptyEmail_errorMentionsEmail() {
        viewModel.email = ""
        _ = viewModel.validate()
        XCTAssertTrue(viewModel.errorMessage.lowercased().contains("email"))
    }

    func testValidate_invalidFormat_errorMentionsValid() {
        viewModel.email = "notanemail"
        _ = viewModel.validate()
        XCTAssertTrue(viewModel.errorMessage.lowercased().contains("email") ||
                      viewModel.errorMessage.lowercased().contains("valid"))
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(viewModel.successMessage, "")
        XCTAssertFalse(viewModel.isLoading)
    }
}
