import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import * as XLSX from "xlsx";
import * as path from "path";
import { expect } from "chai";

const MAX_UINT = ethers.parseUnits("1000000000", 18);
const MAX_APPROX_EQUAL_DELTA = 0.01; // 1%

describe("OffchainFund", function () {
  it("OffchainFundFlowTest", async function () {
    const workbook = XLSX.readFile(path.join(__dirname, "data/OffchainFundFlowTest.xlsx"));
    const sheetNames = workbook.SheetNames;

    const scenario1: any = XLSX.utils.sheet_to_json(workbook.Sheets[sheetNames[0]]);
    const scenario2: any = XLSX.utils.sheet_to_json(workbook.Sheets[sheetNames[1]]);

    await runScenarioTests(scenario1, scenario1.length);
    await runScenarioTests(scenario2, scenario2.length);
  });
});

const runScenarioTests = async (scenario: any, upTo: number) => {
  const { usdc, offchainFund, owner, acc1, acc2, offchainFundAddress } = await loadFixture(deployOffchainFundFixture);

  const epochsWithOrderProcesses: Record<number, { deposits: string[]; redeems: string[] }> = {};
  // Just setting it up so we dont have to check if epoch exists in the object
  for (let i = 0; i < 10000; i++) {
    epochsWithOrderProcesses[i] = { deposits: [], redeems: [] };
  }

  for (let i = 0; i < upTo; i++) {
    console.log(`\n====== DAY ${scenario[i]["Day"]} ======= ${scenario[i]["Action"]} ======`);
    const keys = Object.keys(scenario[i]);

    if (i) await tx(() => offchainFund.update(ethers.parseUnits(String(scenario[i]["update() / settlement (nav/share)"]), 8)));

    const epoch = Number(await offchainFund.epoch());

    console.log(`====== EPOCH ${epoch} ======\n`);

    for (let j = 0; j < keys.length; j++) {
      const key = keys[j];
      const value = scenario[i][key];

      switch (key) {
        case "Action":
        case "Day":
        case "update() / settlement (nav/share)":
          break;

        case "Change in Shares":
          const tempMint = Number(ethers.formatUnits(String(await offchainFund.tempMint()), 18));
          const currentRedemptions = Number(ethers.formatUnits(String(await offchainFund.currentRedemptions()), 18));
          console.log(`\n--SHARES DELTA | Expected: ${value}, Actual: ${tempMint - currentRedemptions}`);
          expect(tempMint - currentRedemptions).to.be.closeTo(value, MAX_APPROX_EQUAL_DELTA * Math.abs(value));
          break;

        case "nav":
        case "nav_1":
        case "nav_2":
        case "nav_3":
        case "nav_4":
          console.log(`\n-----------NAV | Expected: ${value}, Actual: ${await offchainFund.nav()}`);
          const actualNav = Number(ethers.formatUnits(await offchainFund.nav(), 18));
          expect(actualNav).to.be.closeTo(value, MAX_APPROX_EQUAL_DELTA * Math.abs(value));
          break;

        case "nav/share":
        case "nav/share_1":
        case "nav/share_2":
        case "nav/share_3":
        case "nav/share_4":
          console.log(`---------PRICE | Expected: ${value}, Actual: ${await offchainFund.currentPrice()}`);
          expect(await offchainFund.currentPrice()).to.eq(ethers.parseUnits(String(value), 8));
          break;

        case "shares #":
        case "shares #_1":
        case "shares #_2":
        case "shares #_3":
        case "shares #_4":
          console.log(`--TOTAL SHARES | Expected: ${value}, Actual: ${await offchainFund.totalShares()}`);
          const actualSharesNum = Number(ethers.formatUnits(await offchainFund.totalShares(), 18));
          expect(actualSharesNum).to.be.closeTo(value, MAX_APPROX_EQUAL_DELTA * Math.abs(value));
          break;

        case "usdc in contract":
        case "usdc in contract_1":
        case "usdc in contract_2":
        case "usdc in contract_3":
        case "usdc in contract_4":
          console.log(`-----FUND USDC | Expected: ${value}, Actual: ${await usdc.balanceOf(offchainFundAddress)}\n`);
          expect(await usdc.balanceOf(offchainFundAddress)).to.eq(ethers.parseUnits(String(value), 6));
          break;

        case "New deposits before cutoff ($)":
          if (value) {
            if (!epochsWithOrderProcesses[epoch]?.deposits.includes(acc1.address)) {
              await tx(() => offchainFund.connect(acc1).deposit(ethers.parseUnits(String(value), 6)));
              epochsWithOrderProcesses[epoch + 1].deposits.push(acc1.address);
              console.log(`Deposit as ACC1 before drain: ${value}`);
            } else {
              await tx(() => offchainFund.connect(acc2).deposit(ethers.parseUnits(String(value), 6)));
              epochsWithOrderProcesses[epoch + 1].deposits.push(acc2.address);
              console.log(`Deposit as ACC2 before drain: ${value}`);
            }
          } else {
            console.log(`Deposit NO`);
          }
          break;

        case "New redeem before cutoof (shares)":
          if (value) {
            if (!epochsWithOrderProcesses[epoch]?.redeems.includes(acc1.address)) {
              await tx(() => offchainFund.connect(acc1).redeem(ethers.parseUnits(String(value), 18)));
              epochsWithOrderProcesses[epoch + 1].redeems.push(acc1.address);
              console.log(`Redeem as ACC1 before drain: ${value}`);
            } else {
              await tx(() => offchainFund.connect(acc2).redeem(ethers.parseUnits(String(value), 18)));
              epochsWithOrderProcesses[epoch + 1].redeems.push(acc2.address);
              console.log(`Redeem as ACC2 before drain: ${value}`);
            }
          } else {
            console.log(`Redeem NO`);
          }
          break;

        case "Process Deposits and  redeem on-chain":
          // Make sure we dont have duplicates
          epochsWithOrderProcesses[epoch] = {
            deposits: Array.from(new Set(epochsWithOrderProcesses[epoch].deposits)),
            redeems: Array.from(new Set(epochsWithOrderProcesses[epoch].redeems)),
          };

          await tx(() => offchainFund.batchProcessDeposit(epochsWithOrderProcesses[epoch].deposits));
          await tx(() => offchainFund.batchProcessRedeem(epochsWithOrderProcesses[epoch].redeems));
          epochsWithOrderProcesses[epoch] = { deposits: [], redeems: [] };
          break;

        case "drain() / cutoff":
          console.log("Drain the Funds");
          await tx(() => offchainFund.drain());
          break;

        case "refill()":
          console.log(`Refill: ${value}`);
          await tx(() => offchainFund.refill(ethers.parseUnits(String(value), 6)));
          break;

        case "New deposits after cutoff":
        case "New deposits after refill":
          if (value) {
            if (!epochsWithOrderProcesses[epoch + 1]?.deposits.includes(acc2.address)) {
              await tx(() => offchainFund.connect(acc2).deposit(ethers.parseUnits(String(value), 6)));
              epochsWithOrderProcesses[epoch + 2].deposits.push(acc2.address);
              console.log(`Deposit as ACC2 after drain/refill: ${value}`);
            } else {
              await tx(() => offchainFund.connect(acc1).deposit(ethers.parseUnits(String(value), 6)));
              epochsWithOrderProcesses[epoch + 2].deposits.push(acc1.address);
              console.log(`Deposit as ACC1 after drain/refill: ${value}`);
            }
          } else {
            console.log(`Deposit NO`);
          }
          break;

        case "New redeem after cutoff":
        case "New redeem":
          if (value) {
            if (!epochsWithOrderProcesses[epoch + 1]?.redeems.includes(acc2.address)) {
              await tx(() => offchainFund.connect(acc2).redeem(ethers.parseUnits(String(value), 18)));
              epochsWithOrderProcesses[epoch + 2].redeems.push(acc2.address);
              console.log(`Redeem as ACC2 after drain/refill: ${value}`);
            } else {
              await tx(() => offchainFund.connect(acc1).redeem(ethers.parseUnits(String(value), 18)));
              epochsWithOrderProcesses[epoch + 2].redeems.push(acc1.address);
              console.log(`Redeem as ACC1 after drain/refill: ${value}`);
            }
          } else {
            console.log(`Redeem NO`);
          }
          break;

        default:
          break;
      }
    }
  }
};

const deployOffchainFundFixture = async () => {
  const [owner, acc1, acc2, acc3] = await ethers.getSigners();

  const UsdcFactory = await ethers.getContractFactory("ERC20DecimalsMock");
  const usdc = await UsdcFactory.deploy("USD Coin Mock", "USDC", 6);

  const OffchainFundFactory = await ethers.getContractFactory("OffchainFund");
  const offchainFund = await OffchainFundFactory.deploy(owner.address, await usdc.getAddress(), "Fund Test", "OCF");

  const offchainFundAddress = await offchainFund.getAddress();

  await tx(() => offchainFund.addToWhitelist(acc1.address));
  await tx(() => offchainFund.addToWhitelist(acc2.address));
  await tx(() => offchainFund.addToWhitelist(acc3.address));

  await tx(() => offchainFund.adjustCap(MAX_UINT));

  await tx(() => usdc.mint(owner.address, MAX_UINT));
  await tx(() => usdc.mint(acc1.address, MAX_UINT));
  await tx(() => usdc.mint(acc2.address, MAX_UINT));
  await tx(() => usdc.mint(acc3.address, MAX_UINT));

  await tx(() => usdc.approve(offchainFundAddress, MAX_UINT));
  await tx(() => usdc.connect(acc1).approve(offchainFundAddress, MAX_UINT));
  await tx(() => usdc.connect(acc2).approve(offchainFundAddress, MAX_UINT));
  await tx(() => usdc.connect(acc3).approve(offchainFundAddress, MAX_UINT));

  await tx(() => offchainFund.connect(acc1).approve(offchainFundAddress, MAX_UINT));
  await tx(() => offchainFund.connect(acc2).approve(offchainFundAddress, MAX_UINT));
  await tx(() => offchainFund.connect(acc3).approve(offchainFundAddress, MAX_UINT));

  return { usdc, offchainFund, owner, acc1, acc2, acc3, offchainFundAddress };
};

const tx = async (callback: any) => {
  const tx = await callback();
  await tx.wait();
};
