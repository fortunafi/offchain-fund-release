// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Data is referenced in the two sheets in `data/OffchainFundFlowTest.xlsx`
contract OffchainFundFlowTest is Test {
    event Refill(address indexed, uint256 indexed, uint256);

    event Drain(address indexed, uint256 indexed, uint256, uint256);

    event Update(address indexed, uint256 indexed, uint256, uint256);

    address immutable eoa1 = vm.addr(1);
    address immutable eoa2 = vm.addr(2);
    address immutable eoa3 = vm.addr(3);
    address immutable eoa4 = vm.addr(4);
    address immutable eoa5 = vm.addr(5);
    address immutable eoa6 = vm.addr(6);

    IERC20 usdc;

    ERC20DecimalsMock token;
    OffchainFund offchainFund;

    uint256 MAX_EQUAL_DELTA_PERCENTAGE = 0.001e18; // 0.1% Max Delta

    function setUp() public {
        token = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc = IERC20(address(token));
        offchainFund = new OffchainFund(
            address(this),
            address(usdc),
            "Fund Test",
            "OCF"
        );

        vm.prank(eoa1);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(offchainFund), type(uint256).max);

        usdc.approve(address(offchainFund), type(uint256).max);

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);
        offchainFund.addToWhitelist(eoa3);
        offchainFund.addToWhitelist(eoa4);
        offchainFund.addToWhitelist(eoa5);
        offchainFund.addToWhitelist(eoa6);

        offchainFund.adjustCap(type(uint256).max);
    }

    function testFundFlowScenario1() external {
        token.mint(eoa1, 1_000_000e6);
        token.mint(eoa2, 1_000_000e6);
        token.mint(eoa3, 1_000_000e6);
        token.mint(eoa4, 1_000_000e6);

        // * DAY 0

        assertEq(offchainFund.tempMint(), 0); // D7

        assertEq(offchainFund.nav(), 0); // E7
        assertEq(offchainFund.currentPrice(), 1e8); // F7

        assertEq(offchainFund.totalShares(), 0); // G7
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // H7

        // -

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6); // I7

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6); // I7

        // NO Redemptions

        // -

        assertEq(offchainFund.nav(), 0); // K7
        assertEq(offchainFund.currentPrice(), 1e8); // L7

        assertEq(offchainFund.totalShares(), 0); // M7
        assertEq(usdc.balanceOf(address(offchainFund)), 200_000e6); // N7

        // -

        // NO Process Deposits

        // NO Process Redemptions

        // -

        offchainFund.drain(); // P7

        assertEq(offchainFund.nav(), 0); // Q7
        assertEq(offchainFund.currentPrice(), 1e8); // R7

        assertEq(offchainFund.totalShares(), 0); // S7
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // T7

        // -

        // NO Deposits

        // NO Redemptions

        // -

        assertEq(offchainFund.nav(), 0); // Z7
        assertEq(offchainFund.currentPrice(), 1e8); // AA7

        assertEq(offchainFund.totalShares(), 0); // AB7
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AC7

        offchainFund.refill(0); // AD7

        assertEq(offchainFund.nav(), 0); // AE7
        assertEq(offchainFund.currentPrice(), 1e8); // AF7

        assertEq(offchainFund.totalShares(), 0); // AG7
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AH7

        // -

        // NO Deposits

        // NO Redemptions

        // -

        // * DAY 1

        offchainFund.update(1.0000e8); // C8

        assertEq(offchainFund.tempMint(), 200_000e18); // D8

        assertEq(offchainFund.nav(), 200_000e18); // E8
        assertEq(offchainFund.currentPrice(), 1e8); // F8

        assertEq(offchainFund.totalShares(), 200_000e18); // G8
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // H8

        // -

        vm.prank(eoa3);
        offchainFund.deposit(50_000e6); // I8

        // NO Redemptions

        // -

        assertEq(offchainFund.nav(), 200_000e18); // K8
        assertEq(offchainFund.currentPrice(), 1e8); // L8

        assertEq(offchainFund.totalShares(), 200_000e18); // M8
        assertEq(usdc.balanceOf(address(offchainFund)), 50_000e6); // N8

        // -

        offchainFund.processDeposit(eoa1); // O8
        offchainFund.processDeposit(eoa2); // O8

        // NO Process Redemptions

        // -

        offchainFund.drain(); // P8

        assertEq(offchainFund.nav(), 200_000e18); // Q8
        assertEq(offchainFund.currentPrice(), 1e8); // R8

        assertEq(offchainFund.totalShares(), 200_000e18); // S8
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // T8

        // -

        // NO Deposits

        // NO Redemptions

        // -

        assertEq(offchainFund.nav(), 200_000e18); // Z8
        assertEq(offchainFund.currentPrice(), 1e8); // AA8

        assertEq(offchainFund.totalShares(), 200_000e18); // AB8
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AC8

        offchainFund.refill(0); // AD8

        assertEq(offchainFund.nav(), 200_000e18); // AE8
        assertEq(offchainFund.currentPrice(), 1e8); // AF8

        assertEq(offchainFund.totalShares(), 200_000e18); // AG8
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AH8

        // -

        // NO Deposits

        // NO Redemptions

        // -

        // * DAY 2

        offchainFund.update(0.5000e8); // C9

        assertEq(offchainFund.tempMint(), 100_000e18); // D9

        assertEq(offchainFund.nav(), 150_000e18); // E9
        assertEq(offchainFund.currentPrice(), 0.5000e8); // F9

        assertEq(offchainFund.totalShares(), 300_000e18); // G9
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // H9

        // -

        // NO Deposits

        vm.prank(eoa2);
        offchainFund.redeem(10_000e18); // J9

        // -

        assertEq(offchainFund.nav(), 150_000e18); // K9
        assertEq(offchainFund.currentPrice(), 0.5000e8); // L9

        assertEq(offchainFund.totalShares(), 300_000e18); // M9
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // N9

        // -

        offchainFund.processDeposit(eoa3); // O9

        // NO Process Redemptions

        // -

        offchainFund.drain(); // P9

        assertEq(offchainFund.nav(), 150_000e18); // Q9
        assertEq(offchainFund.currentPrice(), 0.5000e8); // R9

        assertEq(offchainFund.totalShares(), 300_000e18); // S9
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // T9

        // -

        // NO Deposits

        // NO Redemptions

        // -

        assertEq(offchainFund.nav(), 150_000e18); // Z9
        assertEq(offchainFund.currentPrice(), 0.5000e8); // AA9

        assertEq(offchainFund.totalShares(), 300_000e18); // AB9
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AC9

        offchainFund.refill(15_000e6); // AD9

        assertEq(offchainFund.nav(), 150_000e18); // AE9
        assertEq(offchainFund.currentPrice(), 0.5000e8); // AF9

        assertEq(offchainFund.totalShares(), 300_000e18); // AG9
        assertEq(usdc.balanceOf(address(offchainFund)), 15_000e6); // AH9

        // * DAY 3

        offchainFund.update(1.5000e8); // C10

        assertEq(offchainFund.tempMint(), 0); // D10

        assertEq(offchainFund.nav(), 435_000e18); // E10
        assertEq(offchainFund.currentPrice(), 1.5000e8); // F10

        assertEq(offchainFund.totalShares(), 290_000e18); // G10
        assertEq(usdc.balanceOf(address(offchainFund)), 15_000e6); // H10

        // -

        vm.prank(eoa4);
        offchainFund.deposit(15_000e6); // I10

        vm.prank(eoa1);
        offchainFund.redeem(25_000e18); // J10

        // -

        assertEq(offchainFund.nav(), 435_000e18); // K10
        assertEq(offchainFund.currentPrice(), 1.5000e8); // L10

        assertEq(offchainFund.totalShares(), 290_000e18); // M10
        assertEq(usdc.balanceOf(address(offchainFund)), 30_000e6); // N10

        // -

        // NO Process Deposits

        offchainFund.processRedeem(eoa2); // O10

        // -

        offchainFund.drain(); // P10

        assertEq(offchainFund.nav(), 435_000e18); // Q10
        assertEq(offchainFund.currentPrice(), 1.5000e8); // R10

        assertEq(offchainFund.totalShares(), 290_000e18); // S10
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // T10

        // -

        vm.prank(eoa3);
        offchainFund.deposit(20_000e6); // X10

        vm.prank(eoa2);
        offchainFund.redeem(10_000e18); // Y10

        // -

        assertEq(offchainFund.nav(), 435_000e18); // Z10
        assertEq(offchainFund.currentPrice(), 1.5000e8); // AA10

        assertEq(offchainFund.totalShares(), 290_000e18); // AB10
        assertEq(usdc.balanceOf(address(offchainFund)), 20_000e6); // AC10

        offchainFund.refill(25_000e6); // AD10

        assertEq(offchainFund.nav(), 435_000e18); // AE10
        assertEq(offchainFund.currentPrice(), 1.5000e8); // AF10

        assertEq(offchainFund.totalShares(), 290_000e18); // AG10
        assertEq(usdc.balanceOf(address(offchainFund)), 45_000e6); // AH10

        // -

        vm.prank(eoa1);
        offchainFund.deposit(30_000e6); // AI10

        vm.prank(eoa3);
        offchainFund.redeem(20_000e18); // AJ10

        // -

        // * DAY 4

        offchainFund.update(1.0000e8); // C11

        assertEq(offchainFund.tempMint(), 15_000e18); // D11

        assertEq(offchainFund.nav(), 280_000e18); // E11
        assertEq(offchainFund.currentPrice(), 1e8); // F11

        assertEq(offchainFund.totalShares(), 280_000e18); // G11
        assertEq(usdc.balanceOf(address(offchainFund)), 75_000e6); // H11

        // -

        // NO Process Deposits

        // NO Process Redemptions

        // -

        assertEq(offchainFund.nav(), 280_000e18); // K11
        assertEq(offchainFund.currentPrice(), 1e8); // L11

        assertEq(offchainFund.totalShares(), 280_000e18); // M11
        assertEq(usdc.balanceOf(address(offchainFund)), 75_000e6); // N11

        // -

        offchainFund.processDeposit(eoa4); // O11

        offchainFund.processRedeem(eoa1); // O11

        // -

        offchainFund.drain(); // P11

        assertEq(offchainFund.nav(), 280_000e18); // Q11
        assertEq(offchainFund.currentPrice(), 1e8); // R11

        assertEq(offchainFund.totalShares(), 280_000e18); // S11
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // T11

        // -

        // NO Process Deposits

        // NO Process Redemptions

        // -

        assertEq(offchainFund.nav(), 280_000e18); // Z11
        assertEq(offchainFund.currentPrice(), 1e8); // AA11

        assertEq(offchainFund.totalShares(), 280_000e18); // AB11
        assertEq(usdc.balanceOf(address(offchainFund)), 0); // AC11

        offchainFund.refill(30_000e6); // AD11

        assertEq(offchainFund.nav(), 280_000e18); // AE11
        assertEq(offchainFund.currentPrice(), 1e8); // AF11

        assertEq(offchainFund.totalShares(), 280_000e18); // AG11
        assertEq(usdc.balanceOf(address(offchainFund)), 30_000e6); // AH11

        // -

        // NO Deposits

        // NO Redemptions

        // -

        // * DAY 5
    }

    // Sheet: Version 3 - Test Scenarios
    function testFundFlowScenario2() external {
        token.mint(eoa1, 1_000_000e6);
        token.mint(eoa2, 1_000_000e6);
        token.mint(eoa3, 1_000_000e6);
        token.mint(eoa4, 1_000_000e6);

        //! DAY 0 (Deposit Order before cutoff)
        vm.prank(eoa1);
        offchainFund.deposit(200_000e6); //? I9
        // NO Redeems //? J9
        assertEq(offchainFund.nav(), 0); //? K9
        assertEq(usdc.balanceOf(address(offchainFund)), 200_000e6); //? N9
        // Deposit Will be Processed in Next Epoch //? O9
        // NO Process Redeems //? O9
        offchainFund.drain(); //? P9
        _performStateChecks(0, 1e8, 0, 0); //? Q9 R9 S9 T9
        // NO Deposits/Redeems //? X9 Y9
        _performStateChecks(0, 1e8, 0, 0); //? Z9 AA9 AB9 AC9
        offchainFund.refill(0); //? AD9
        _performStateChecks(0, 1e8, 0, 0); //? AE9 AF9 AG9 AH9
        // NO Deposits/Redeems //? AI9 AJ9

        //! DAY 1 (Processing Deposit from Day 0)
        offchainFund.update(1.0000e8); //? C10
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            200_000e18
        ); //? D10
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? E10 F10 G10 H10
        // NO Deposits/Redeems //? I10 J19
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? K10 L10 M10 N10
        offchainFund.processDeposit(eoa1); //? O10
        // NO Redeem Orders to Process //? O10
        offchainFund.drain(); //? P10
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Q10 R10 S10 T10
        // NO Deposits/Redeems //? X10 Y10
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Z10 AA10 AB10 AC10
        offchainFund.refill(0); //? AD10
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? AE10 AF10 AG10 AH10
        // NO Deposits/Redeems //? AI10 AJ10

        //! DAY 2
        offchainFund.update(1.0000e8); //? C11
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D11
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? E11 F11 G11 H11
        // NO Deposits/Redeems //? I11 J11
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? K11 L11 M11 N11
        // NO Deposit/Redeem Orders to Process //? O11
        offchainFund.drain(); //? P11
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Q11 R11 S11 T11
        // NO Deposits/Redeems //? X11 Y11
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Z11 AA11 AB11 AC11
        offchainFund.refill(0); //? AD11
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? AE11 AF11 AG11 AH11
        // NO Deposits/Redeems //? AI11 AJ11

        //! DAY 3 (Deposit Order before cutoff)
        offchainFund.update(1.0000e8); //? C12
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D12
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? E12 F12 G12 H12
        vm.prank(eoa1);
        offchainFund.deposit(300_000e6); //? I12
        // NO Redeems //? J12
        _performStateChecks(200_000e18, 1e8, 200_000e18, 300_000e6); //? K12 L12 M12 N12
        // Deposit Will be Processed in Next Epoch //? O12
        // NO Redeem Orders to Process //? O12
        offchainFund.drain(); //? P12
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Q12 R12 S12 T12
        // NO Deposits/Redeems //? X12 Y12
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? Z12 AA12 AB12 AC12
        offchainFund.refill(0); //? AD12
        _performStateChecks(200_000e18, 1e8, 200_000e18, 0); //? AE12 AF12 AG12 AH12
        // NO Deposits/Redeems //? AI12 AJ12

        //! DAY 4 (Processing Deposit from Day 3)
        offchainFund.update(1.0000e8); //? C13
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            300_000e18
        ); //? D13
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? E13 F13 G13 H13
        // NO Deposits/Redeems //? I13 J13
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? K13 L13 M13 N13
        offchainFund.processDeposit(eoa1); //? O13
        // NO Redeem Orders to Process //? O13
        offchainFund.drain(); //? P13
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Q13 R13 S13 T13
        // NO Deposits/Redeems //? X13 Y13
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Z13 AA13 AB13 AC13
        offchainFund.refill(0); //? AD13
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? AE13 AF13 AG13 AH13
        // NO Deposits/Redeems //? AI13 AJ13

        //! DAY 5
        offchainFund.update(1.0000e8); //? C14
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D14
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? E14 F14 G14 H14
        // NO Deposits/Redeems //? I14 J14
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? K14 L14 M14 N14
        // NO Deposit/Redeem Orders to Process //? O14
        offchainFund.drain(); //? P14
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Q14 R14 S14 T14
        // NO Deposits/Redeems //? X14 Y14
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Z14 AA14 AB14 AC14
        offchainFund.refill(0); //? AD14
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? AE14 AF14 AG14 AH14
        // NO Deposits/Redeems //? AI14 AJ14

        //! DAY 6 (Offchain Ops happening)
        offchainFund.update(1.0000e8); //? C15
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D15
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? E15 F15 G15 H15
        // NO Deposits/Redeems //? I15 J15
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? K15 L15 M15 N15
        // NO Deposit/Redeem Orders to Process //? O15
        offchainFund.drain(); //? P15
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Q15 R15 S15 T15
        // NO Deposits/Redeems //? X15 Y15
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Z15 AA15 AB15 AC15
        offchainFund.refill(0); //? AD15
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? AE15 AF15 AG15 AH15
        // NO Deposits/Redeems //? AI15 AJ15

        //! DAY 7 (Price Change)
        offchainFund.update(1.1000e8); //? C16
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D16
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? E16 F16 G16 H16
        // NO Deposits/Redeems //? I16 J16
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? K16 L16 M16 N16
        // NO Deposit/Redeem Orders to Process //? O16
        offchainFund.drain(); //? P16
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? Q16 R16 S16 T16
        // NO Deposits/Redeems //? X16 Y16
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? Z16 AA16 AB16 AC16
        offchainFund.refill(0); //? AD16
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? AE16 AF16 AG16 AH16
        // NO Deposits/Redeems //? AI16 AJ16

        //! DAY 8 (Offchain Ops happening)
        offchainFund.update(1.1000e8); //? C17
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D17
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? E17 F17 G17 H17
        // NO Deposits/Redeems //? I17 J17
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? K17 L17 M17 N17
        // NO Deposit/Redeem Orders to Process //? O17
        offchainFund.drain(); //? P17
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? Q17 R17 S17 T17
        // NO Deposits/Redeems //? X17 Y17
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? Z17 AA17 AB17 AC17
        offchainFund.refill(0); //? AD17
        _performStateChecks(550_000e18, 1.1e8, 500_000e18, 0); //? AE17 AF17 AG17 AH17
        // NO Deposits/Redeems //? AI17 AJ17

        //! DAY 9 (Price Change)
        offchainFund.update(1.0000e8); //? C18
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D18
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? E18 F18 G18 H18
        // NO Deposits/Redeems //? I18 J18
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? K18 L18 M18 N18
        // NO Deposit/Redeem Orders to Process //? O18
        offchainFund.drain(); //? P18
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Q18 R18 S18 T18
        // NO Deposits/Redeems //? X18 Y18
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Z18 AA18 AB18 AC18
        offchainFund.refill(0); //? AD18
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? AE18 AF18 AG18 AH18
        // NO Deposits/Redeems //? AI18 AJ18

        //! DAY 10 (Redeem Order before cutoff)
        offchainFund.update(1.0000e8); //? C19
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D19
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? E19 F19 G19 H19
        // NO Deposits //? J19
        vm.prank(eoa1);
        offchainFund.redeem(50_000e18); //? J19
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? K19 L19 M19 N19
        // NO Deposit/Redeem Orders to Process (Redeem Order to be processed in next Epoch) //? O19
        offchainFund.drain(); //? P19
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Q19 R19 S19 T19
        // NO Deposits/Redeems //? X19 Y19
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? Z19 AA19 AB19 AC19
        offchainFund.refill(0); //? AD19
        _performStateChecks(500_000e18, 1e8, 500_000e18, 0); //? AE19 AF19 AG19 AH19
        // NO Deposits/Redeems //? AI19 AJ19

        //! DAY 11 (Processing Redeem from Day 9)
        offchainFund.update(1.0000e8); //? C20
        assertEq(
            offchainFund.currentRedemptions() - offchainFund.tempMint(),
            50_000e18
        ); //? D20
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? E20 (Wrong in sheet) F20 G20 H20
        // NO Deposits/Redeems //? J20
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? K20 L20 M20 N20
        // NO Deposit Orders to Process //? O20
        token.mint(address(offchainFund), 50_000e6); // Exact amount needed to give back to user who redeems
        offchainFund.processRedeem(eoa1); //? O20
        offchainFund.drain(); //? P20
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Q20 R20 S20 T20
        // NO Deposits/Redeems //? X20 Y20
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Z20 AA20 AB20 AC20
        offchainFund.refill(0); //? AD20
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? AE20 AF20 AG20 AH20
        // NO Deposits/Redeems //? AI20 AJ20

        //! DAY 12
        offchainFund.update(1.0000e8); //? C21
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D21
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? E21 F21 G21 H21
        // NO Deposits/Redeems //? J21
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? K21 L21 M21 N21
        // NO Deposit/Redeem Orders to Process //? O21
        offchainFund.drain(); //? P21
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Q21 R21 S21 T21
        // NO Deposits/Redeems //? X21 Y21
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Z21 AA21 AB21 AC21
        offchainFund.refill(0); //? AD21
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? AE21 AF21 AG21 AH21
        // NO Deposits/Redeems //? AI21 AJ21

        //! DAY 13 (Multiple Deposits from different EOAs after cutoff and after refill)
        offchainFund.update(1.0000e8); //? C22
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? E22 F22 G22 H22
        // NO Deposits/Redeems //? J22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? K22 L22 M22 N22
        // NO Deposit/Redeem Orders to Process //? O22
        offchainFund.drain(); //? P22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Q22 R22 S22 T22
        vm.prank(eoa1);
        offchainFund.deposit(250_000e6); //? X22
        // NO Redeems //? Y22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 250_000e6); //? Z22 AA22 AB22 AC22
        offchainFund.refill(0); //? AD22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 250_000e6); //? AE22 AF22 AG22 AH22
        vm.prank(eoa2);
        offchainFund.deposit(300_000e6); //? AI22
        // NO Redeems //? AJ22

        //! DAY 14
        offchainFund.update(1.0000e8); //? C23
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D23
        _performStateChecks(450_000e18, 1e8, 450_000e18, 550_000e6); //? E23 F23 G23 H23
        // NO Deposits/Redeems //? J23
        _performStateChecks(450_000e18, 1e8, 450_000e18, 550_000e6); //? K23 L23 M23 N23
        // NO Deposit/Redeem Orders to Process (Deposit Orders to be processed in next Epoch) //? O23
        offchainFund.drain(); //? P23
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Q23 R23 S23 T23
        // NO Deposots/Redeems //? X23 Y23
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? Z23 AA23 AB23 AC23
        offchainFund.refill(0); //? AD22
        _performStateChecks(450_000e18, 1e8, 450_000e18, 0); //? AE23 AF23 AG23 AH23
        // NO Deposits/Redeems //? AI23 AJ23

        //! DAY 15 (Processing multiple deposits from Day 13)
        offchainFund.update(1.0000e8); //? C24
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            550_000e18
        ); //? D24
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? E24 F24 G24 H24
        // NO Deposits/Redeems //? J24
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? K24 L24 M24 N24
        offchainFund.processDeposit(eoa1); //? O24
        offchainFund.processDeposit(eoa2); //? O24
        offchainFund.drain(); //? P24
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Q24 R24 S24 T24
        // NO Deposots/Redeems //? X24 Y24
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Z24 AA24 AB24 AC24
        offchainFund.refill(0); //? AD24
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? AE24 AF24 AG24 AH24
        // NO Deposits/Redeems //? AI24 AJ24

        //! DAY 16
        offchainFund.update(1.0000e8); //? C25
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D25
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? E25 F25 G25 H25
        // NO Deposits/Redeems //? J25
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? K25 L25 M25 N25
        // NO Deposit/Redeem Orders to Process //? O25
        offchainFund.drain(); //? P25
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Q25 R25 S25 T25
        // NO Deposots/Redeems //? X25 Y25
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Z25 AA25 AB25 AC25
        offchainFund.refill(0); //? AD25
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? AE25 AF25 AG25 AH25
        // NO Deposits/Redeems //? AI25 AJ25

        //! DAY 17 (Multiple Redeems after cutoff and after refill)
        offchainFund.update(1.0000e8); //? C26
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D26
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? E26 F26 G26 H26
        // NO Deposits/Redeems //? J26
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? K26 L26 M26 N26
        // NO Deposit/Redeem Orders to Process //? O26
        offchainFund.drain(); //? P26
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Q26 R26 S26 T26
        // NO Deposits //? X26
        vm.prank(eoa1);
        offchainFund.redeem(100_000e18); //? Y26
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Z26 AA26 AB26 AC26
        offchainFund.refill(0); //? AD26
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? AE26 AF26 AG26 AH26
        // NO Deposits //? AI26
        vm.prank(eoa1);
        offchainFund.redeem(100_000e18); //? AJ26

        //! DAY 18
        offchainFund.update(1.0000e8); //? C27
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D27
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? E27 F27 G27 H27
        // NO Deposits/Redeems //? J27
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? K27 L27 M27 N27
        // NO Deposit/Redeem Orders to Process (Redeem Orders to be processed in next Epoch) //? O27
        offchainFund.drain(); //? P27
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Q27 R27 S27 T27
        // NO Deposits/Redeems //? X27 Y27
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? Z27 AA27 AB27 AC27
        offchainFund.refill(0); //? AD27
        _performStateChecks(1_000_000e18, 1e8, 1_000_000e18, 0); //? AE27 AF27 AG27 AH27
        // NO Deposits/Redeems //? AI27 AJ27

        //! DAY 19 (Processing multiple redeems from Day 17)
        offchainFund.update(1.0000e8); //? C28
        assertEq(
            offchainFund.currentRedemptions() - offchainFund.tempMint(),
            200_000e18
        ); //? D28
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? E28 (Mistake in Sheets) F28 G28 H28
        // NO Deposits/Redeems //? I28 J28
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? K28 L28 M28 N28
        // NO Deposit Orders to Process  //? O28
        token.mint(address(offchainFund), 200_000e6); // Exact amount needed to give back to user who redeems
        offchainFund.processRedeem(eoa1); //? O28
        offchainFund.drain(); //? P28
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Q28 R28 S28 T28
        // NO Deposits/Redeems //? X28 Y28
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Z28 AA28 AB28 AC28
        offchainFund.refill(0); //? AD28
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? AE28 AF28 AG28 AH28
        // NO Deposits/Redeems //? AI28 AJ28

        //! DAY 20
        offchainFund.update(1.0000e8); //? C29
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? E29 F29 G29 H29
        // NO Deposits/Redeems //? I29 J29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? K29 L29 M29 N29
        // NO Deposit/Redeem Orders to Process  //? O29
        offchainFund.drain(); //? P29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Q29 R29 S29 T29
        // NO Deposits/Redeems //? X29 Y29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Z29 AA29 AB29 AC29
        offchainFund.refill(0); //? AD29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? AE29 AF29 AG29 AH29
        // NO Deposits/Redeems //? AI29 AJ29

        //! DAY 21 (Deposit order before cutoff, Offchain Ops happening)
        offchainFund.update(1.0000e8); //? C30
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D30
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? E30 F30 G30 H30
        vm.prank(eoa1);
        offchainFund.deposit(500_000e6); //? I30
        // NO Redeems //? J30
        _performStateChecks(800_000e18, 1e8, 800_000e18, 500_000e6); //? K30 L30 M30 N30
        // Deposit Will be Processed in Next Epoch //? O30
        // NO Redeem Orders to Process //? O30
        offchainFund.drain(); //? P30
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Q30 R30 S30 T30
        // NO Deposits/Redeems //? X29 Y29
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? Z30 AA30 AB30 AC30
        offchainFund.refill(0); //? AD30
        _performStateChecks(800_000e18, 1e8, 800_000e18, 0); //? AE30 AF30 AG30 AH30
        // NO Deposits/Redeems //? AI30 AJ30

        //! DAY 22 (Process Deposit order from Day 21, Price Change, Offchain Ops happening)
        offchainFund.update(1.0313e8); //? C31
        assertApproxEqRel(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            484_848e18,
            MAX_EQUAL_DELTA_PERCENTAGE
        ); //? D31
        _performStateChecksApprox(1_325_000e18, 1.0313e8, 1_284_848e18, 0); //? E31 F31 G31 H31
        // NO Deposits/Redeems //? JI31 31
        _performStateChecksApprox(1_325_000e18, 1.0313e8, 1_284_848e18, 0); //? K31 L31 M31 N31
        offchainFund.processDeposit(eoa1); //? O31
        // NO Redeem Orders to Process //? O31
        offchainFund.drain(); //? P31
        _performStateChecksApprox(1_325_000e18, 1.0313e8, 1_284_848e18, 0); //? Q31 R31 S31 T31
        // NO Deposits/Redeems //? X31 Y31
        _performStateChecksApprox(1_325_000e18, 1.0313e8, 1_284_848e18, 0); //? Z31 AA31 AB31 AC31
        offchainFund.refill(0); //? AD31
        _performStateChecksApprox(1_325_000e18, 1.0313e8, 1_284_848e18, 0); //? AE31 AF31 AG31 AH31
        // NO Deposits/Redeems //? AI31 AJ31

        //! DAY 23 (Price Change)
        offchainFund.update(1.0507e8); //? C32
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D32
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? E32 F32 G32 H32
        // NO Deposits/Redeems //? I32 J32
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? K32 L32 M32 N32
        // NO Deposit/Redeem Orders to Process //? O32
        offchainFund.drain(); //? P32
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? Q32 R32 S32 T32
        // NO Deposits/Redeems //? X32 Y32
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? Z32 AA32 AB32 AC32
        offchainFund.refill(0); //? AD32
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? AE32 AF32 AG32 AH32
        // NO Deposits/Redeems //? AI32 AJ32

        //! DAY 24 (Redeem Order before cutoff, Offchain Ops happening)
        offchainFund.update(1.0507e8); //? C33
        assertEq(
            offchainFund.tempMint() - offchainFund.currentRedemptions(),
            0
        ); //? D33
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? E33 F33 G33 H33
        // NO Deposits //? I33
        vm.prank(eoa1);
        offchainFund.redeem(200_000e18); //? J33
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? K33 L33 M33 N33
        // NO Deposit/Redeem Orders to Process (Redeem Order to be processed in next Epoch) //? O33
        offchainFund.drain(); //? P33
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? Q33 R33 S33 T33
        // NO Deposits/Redeems //? X33 Y33
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? Z33 AA33 AB33 AC33
        offchainFund.refill(0); //? AD33
        _performStateChecksApprox(1_350_000e18, 1.0507e8, 1_284_848e18, 0); //? AE33 AF33 AG33 AH33
        // NO Deposits/Redeems //? AI33 AJ33
    }

    function _performStateChecks(
        uint256 nav,
        uint256 price,
        uint256 shares,
        uint256 balance
    ) internal {
        assertEq(offchainFund.nav(), nav);
        assertEq(offchainFund.currentPrice(), price);
        assertEq(offchainFund.totalShares(), shares);
        assertEq(usdc.balanceOf(address(offchainFund)), balance);
    }

    function _performStateChecksApprox(
        uint256 nav,
        uint256 price,
        uint256 shares,
        uint256 balance
    ) internal {
        assertApproxEqRel(offchainFund.nav(), nav, MAX_EQUAL_DELTA_PERCENTAGE);
        assertEq(offchainFund.currentPrice(), price);
        assertApproxEqRel(
            offchainFund.totalShares(),
            shares,
            MAX_EQUAL_DELTA_PERCENTAGE
        );
        assertEq(usdc.balanceOf(address(offchainFund)), balance);
    }

    function _checkState(
        uint256 nav,
        uint256 price,
        uint256 shares,
        uint256 balance
    ) private view returns (bool) {
        return
            nav == offchainFund.nav() &&
            price == offchainFund.currentPrice() &&
            shares == offchainFund.totalShares() &&
            usdc.balanceOf(address(offchainFund)) == balance;
    }
}
