// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {MockUSDC} from "../../src/MockUSDC.sol";
import {ComplianceRegistry} from "../../src/ComplianceRegistry.sol";
import {TBillToken} from "../../src/TBillToken.sol";
import {TBillVault} from "../../src/TBillVault.sol";
import {MockPriceFeed} from "../../src/exercises/MockPriceFeed.sol";
import {MockTBillCustodian} from "../../src/exercises/MockTBillCustodian.sol";

/// @title Ex2 + Ex4 — planks (b) and (d): the claim is not a dollar, and the guest list
/// @notice Every `assertTrue(false, "TODO ...")` below is a placeholder. Write the real
///         assertion, watch the test go green, and that exercise is done.
///
///         Acceptance: make exercise (it should be red until you are finished)
///         Do not open test/TBill.t.sol — it contains the answers. Write yours first, and
///         only look once you are stuck.
contract AttestationTasksTest is Test {
    MockUSDC internal usdc;
    ComplianceRegistry internal compliance;
    MockPriceFeed internal feed;
    TBillToken internal tBill;
    MockTBillCustodian internal custodian;
    TBillVault internal vault;

    address internal admin = address(this);
    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant PAR = 1e8;
    uint256 internal constant NAV_1_25 = 1.25e8;

    function setUp() public {
        usdc = new MockUSDC();
        compliance = new ComplianceRegistry(admin);
        feed = new MockPriceFeed(int256(PAR));
        tBill = new TBillToken(admin, compliance);
        custodian = new MockTBillCustodian(admin);
        vault = new TBillVault(usdc, tBill, feed, custodian, admin);

        tBill.grantRole(tBill.MINTER_ROLE(), address(vault));
        custodian.grantRole(custodian.CUSTODIAN_ROLE(), address(vault));

        compliance.setWhitelisted(admin, true);
        compliance.setWhitelisted(alice, true);
    }

    /// @dev Given: pay `assets` of USDC and receive shares at today's NAV
    function _subscribe(address user, uint256 assets) internal {
        usdc.faucet(user, assets);
        vm.startPrank(user);
        usdc.approve(address(vault), assets);
        vault.subscribe(assets);
        vm.stopPrank();
    }

    // ==================================================================
    // Ex2 · the claim is not a dollar (plank b)
    // ==================================================================

    /// @dev Subscribe at par, then have the reporter move the NAV up. Assert the two things
    ///      that make this an RWA and not a stablecoin: the share COUNT is unchanged, but the
    ///      VALUE of the position moved. A stablecoin would have kept 1:1.
    ///      Hint: _subscribe(alice, 1_000e6), then vault.attest(int256(NAV_1_25)), then look at
    ///      tBill.balanceOf(alice) and vault.totalClaimValue().
    function test_Ex2_ShareIsNotADollar() public {
        assertTrue(false, "TODO Ex2.1");
    }

    /// @dev Run subscribe with 1000e18 instead of 1000e6, see what happens, then assert what
    ///      you observed. MockUSDC has 6 decimals — 1000e18 is a quadrillion USDC, not a
    ///      thousand. The input is 10^12 too large. There is no expected answer; the point is
    ///      that you run it yourself and read the numbers.
    function test_Ex2_DecimalsTrap() public {
        assertTrue(false, "TODO Ex2.2");
    }

    // ==================================================================
    // Ex4 · the guest list (plank d): where the guard is, who holds the key
    // ==================================================================

    /// @dev An address that never passed KYC cannot receive shares, even by paying for them.
    ///      Hint: faucet the attacker, approve, then vm.expectRevert + abi.encodeWithSelector
    ///      to pin down TBillToken.NotWhitelisted(attacker).
    function test_Ex4_NonWhitelisted_CannotSubscribe() public {
        assertTrue(false, "TODO Ex4.1");
    }

    /// @dev A whitelisted holder still cannot SEND shares to a non-whitelisted address —
    ///      _update checks both endpoints, not just the sender.
    function test_Ex4_NonWhitelisted_CannotReceive() public {
        assertTrue(false, "TODO Ex4.2");
    }

    /// @dev Removing an address from the list freezes that individual holder: they can no
    ///      longer move their shares. This is the compliance power a regulated fund needs —
    ///      and also a censorship tool.
    function test_Ex4_Unwhitelisted_HolderIsFrozen() public {
        assertTrue(false, "TODO Ex4.3");
    }

    /// @dev ...and a holder of MINTER_ROLE can burn anyone's balance outright. This test
    ///      proves the backdoor exists; it does not justify it. Which addresses hold
    ///      MINTER_ROLE in this system?
    function test_Ex4_IssuerCanBurnAnyBalance() public {
        assertTrue(false, "TODO Ex4.4");
    }

    /// @dev pause() goes through _update, so it freezes transfers, minting and redemption
    ///      together. Why is that bad news in a real crisis?
    ///      (This is STUDENT-QUESTIONS.md C2.)
    function test_Ex4_Pause_BlocksEverything() public {
        assertTrue(false, "TODO Ex4.5");
    }
}
