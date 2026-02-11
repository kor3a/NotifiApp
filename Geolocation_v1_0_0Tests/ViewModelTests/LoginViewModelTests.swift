//
//  LoginViewModelTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class LoginViewModelTests: XCTestCase {

    private var viewModel: LoginViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LoginViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - validate() - Valid Input

    func testValidate_validInput_returnsTrue() {
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        XCTAssertTrue(viewModel.validate())
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    func testValidate_validInput_minimalEmail_returnsTrue() {
        viewModel.email = "a@b.c"
        viewModel.password = "pass"
        XCTAssertTrue(viewModel.validate())
    }

    // MARK: - validate() - Empty Fields

    func testValidate_emptyEmail_returnsFalse() {
        viewModel.email = ""
        viewModel.password = "password123"
        XCTAssertFalse(viewModel.validate())
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
    }

    func testValidate_emptyPassword_returnsFalse() {
        viewModel.email = "test@example.com"
        viewModel.password = ""
        XCTAssertFalse(viewModel.validate())
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
    }

    func testValidate_bothEmpty_returnsFalse() {
        viewModel.email = ""
        viewModel.password = ""
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_whitespaceOnlyEmail_returnsFalse() {
        viewModel.email = "   "
        viewModel.password = "password123"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_whitespaceOnlyPassword_returnsFalse() {
        viewModel.email = "test@example.com"
        viewModel.password = "   "
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Invalid Email Format

    func testValidate_emailMissingAt_returnsFalse() {
        viewModel.email = "testexample.com"
        viewModel.password = "password123"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emailMissingDot_returnsFalse() {
        viewModel.email = "test@examplecom"
        viewModel.password = "password123"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emailMissingBoth_returnsFalse() {
        viewModel.email = "testexamplecom"
        viewModel.password = "password123"
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Error Messages

    func testValidate_emptyFields_setsAppropriateErrorMessage() {
        viewModel.email = ""
        viewModel.password = ""
        _ = viewModel.validate()
        XCTAssertTrue(viewModel.errorMessage.lowercased().contains("email") ||
                      viewModel.errorMessage.lowercased().contains("password") ||
                      viewModel.errorMessage.lowercased().contains("please"))
    }

    func testValidate_invalidEmail_setsAppropriateErrorMessage() {
        viewModel.email = "notanemail"
        viewModel.password = "password123"
        _ = viewModel.validate()
        XCTAssertTrue(viewModel.errorMessage.lowercased().contains("email") ||
                      viewModel.errorMessage.lowercased().contains("valid"))
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertFalse(viewModel.showEmailNotVerified)
        XCTAssertFalse(viewModel.isResendingVerification)
    }
}
