//
//  SignupViewModelTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class SignupViewModelTests: XCTestCase {

    private var viewModel: SignupViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SignupViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func fillValidForm() {
        viewModel.userId = "testuser"
        viewModel.email = "test@example.com"
        viewModel.name = "Test User"
        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"
    }

    // MARK: - validate() - Valid Input

    func testValidate_validInput_returnsTrue() {
        fillValidForm()
        XCTAssertTrue(viewModel.validate())
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    func testValidate_validUsername_minLength() {
        fillValidForm()
        viewModel.userId = "abc" // 3 characters - minimum
        XCTAssertTrue(viewModel.validate())
    }

    func testValidate_validUsername_maxLength() {
        fillValidForm()
        viewModel.userId = "abcdefghijklmnopqrst" // 20 characters - maximum
        XCTAssertTrue(viewModel.validate())
    }

    func testValidate_validUsername_alphanumeric() {
        fillValidForm()
        viewModel.userId = "user123"
        XCTAssertTrue(viewModel.validate())
    }

    // MARK: - validate() - Empty Fields

    func testValidate_emptyEmail_returnsFalse() {
        fillValidForm()
        viewModel.email = ""
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emptyPassword_returnsFalse() {
        fillValidForm()
        viewModel.password = ""
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emptyName_returnsFalse() {
        fillValidForm()
        viewModel.name = ""
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emptyUserId_returnsFalse() {
        fillValidForm()
        viewModel.userId = ""
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_whitespaceOnlyName_returnsFalse() {
        fillValidForm()
        viewModel.name = "   "
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Invalid Email

    func testValidate_emailMissingAt_returnsFalse() {
        fillValidForm()
        viewModel.email = "testexample.com"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_emailMissingDot_returnsFalse() {
        fillValidForm()
        viewModel.email = "test@examplecom"
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Password

    func testValidate_passwordTooShort_returnsFalse() {
        fillValidForm()
        viewModel.password = "123456" // exactly 6 characters - must be > 6
        viewModel.confirmPassword = "123456"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_passwordSevenChars_returnsTrue() {
        fillValidForm()
        viewModel.password = "1234567" // 7 characters - passes > 6
        viewModel.confirmPassword = "1234567"
        XCTAssertTrue(viewModel.validate())
    }

    func testValidate_passwordsMismatch_returnsFalse() {
        fillValidForm()
        viewModel.password = "password123"
        viewModel.confirmPassword = "password456"
        XCTAssertFalse(viewModel.validate())
        XCTAssertTrue(viewModel.errorMessage.lowercased().contains("password") ||
                      viewModel.errorMessage.lowercased().contains("match"))
    }

    // MARK: - validate() - Username Format

    func testValidate_usernameTooShort_returnsFalse() {
        fillValidForm()
        viewModel.userId = "ab" // 2 characters - below minimum of 3
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_usernameTooLong_returnsFalse() {
        fillValidForm()
        viewModel.userId = "abcdefghijklmnopqrstu" // 21 characters - above maximum of 20
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_usernameWithSpecialChars_returnsFalse() {
        fillValidForm()
        viewModel.userId = "user_name" // underscore not allowed
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_usernameWithSpaces_returnsFalse() {
        fillValidForm()
        viewModel.userId = "user name"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_usernameWithHyphen_returnsFalse() {
        fillValidForm()
        viewModel.userId = "user-name"
        XCTAssertFalse(viewModel.validate())
    }

    func testValidate_usernameWithEmail_returnsFalse() {
        fillValidForm()
        viewModel.userId = "user@name"
        XCTAssertFalse(viewModel.validate())
    }

    // MARK: - validate() - Error Message Cleared

    func testValidate_clearsErrorMessageOnCall() {
        viewModel.errorMessage = "Previous error"
        fillValidForm()
        _ = viewModel.validate()
        // errorMessage should either be empty (valid) or set to a new error
        XCTAssertNotEqual(viewModel.errorMessage, "Previous error")
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.userId, "")
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.name, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.confirmPassword, "")
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertFalse(viewModel.signupComplete)
    }
}
